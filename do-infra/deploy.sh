#!/usr/bin/env bash
set -euo pipefail

# Unified deploy script: create kind cluster, install Argo CD, build+load image, and apply Terraform
# Usage (minimum):
#   ./deploy.sh
# Optional env vars:
#   REPO_URL=https://github.com/your-org/do-deploy-example.git
#                                  # The repo containing the configuration
#   CLUSTER_NAME=do-demo           # kind cluster name (default: do-demo)
#   KIND_CONFIG=./kind-config.yaml # path to kind config (default: do-infra/kind-config.yaml)
#   IMAGE_NAME=some-service:local  # image:tag to build and load into kind (default: some-service:local)
#   SKIP_IMAGE=1                   # set to skip building/loading the image
#   TF_VAR_kubeconfig=~/.kube/config # kubeconfig for terraform providers (default set by this script)
#   TF_VALUES_OVERRIDES_FILE=path  # optional path to a YAML file for Helm values overrides passed to Argo CD Application
#   APP_NAMESPACE=some-service     # destination namespace for the app (default in TF is some-service)
#   ARGO_NAMESPACE=argocd          # Argo CD namespace (default in TF is argocd)
#   AUTH_TYPE=https_basic          # or ssh
#   USERNAME=                      # for https_basic
#   PASSWORD=                      # for https_basic (prefer to input interactively)
#   SSH_PRIVATE_KEY_PATH=          # for ssh, path to private key; will be read securely

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TF_DIR="$SCRIPT_DIR/terraform"

CLUSTER_NAME=${CLUSTER_NAME:-do-demo}
KIND_CONFIG=${KIND_CONFIG:-"$SCRIPT_DIR/kind-config.yaml"}
REPO_URL=${REPO_URL:-https://github.com/zicornell-do/do-deploy-example.git}
IMAGE_NAME=${IMAGE_NAME:-some-service:local}
SKIP_IMAGE=${SKIP_IMAGE:-0}
APP_NAMESPACE=${APP_NAMESPACE:-some-service}
ARGO_NAMESPACE=${ARGO_NAMESPACE:-argocd}
AUTH_TYPE=${AUTH_TYPE:-https_basic}

# Ensure kubeconfig is available for Terraform providers
export TF_VAR_kubeconfig="${TF_VAR_kubeconfig:-$HOME/.kube/config}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required command '$1' not found in PATH" >&2
    exit 1
  }
}

# Check prerequisites
need_cmd docker
need_cmd kind
need_cmd kubectl
need_cmd terraform

# 1) Create kind cluster if not exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "👉 [1] Cluster ${CLUSTER_NAME} already exists"
else
  echo "👉 [1] Creating kind cluster ${CLUSTER_NAME}..."
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

# 2) Install/ensure Argo CD is present
# Create namespace if missing
kubectl get ns "$ARGO_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$ARGO_NAMESPACE"
# Apply upstream manifest (idempotent)
kubectl -n "$ARGO_NAMESPACE" apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for CRDs to be established before Terraform applies the Application
# Poll for the Application CRD up to ~60s
echo "👉 [2] Waiting for Argo CD CRDs to be established..."
for i in {1..30}; do
  if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Wait briefly for the server to roll out (don't fail the whole script if it times out)
echo "👉 [2] Waiting for Argo CD server rollout (up to 180s)..."
kubectl -n "$ARGO_NAMESPACE" rollout status deploy/argocd-server --timeout=180s || true

# 3) Inject repository credentials for Argo CD
echo "👉 [3] Inject repository credentials for Argo CD..."
SECRET_NAME=argocd-git-creds

case "$AUTH_TYPE" in
  https_basic)
    USERNAME=${USERNAME:-}
    PASSWORD=${PASSWORD:-}
    if [[ -z "${USERNAME}" ]]; then
      read -rp "Git username [default: YOUR_USERNAME]: " USERNAME
      USERNAME=${USERNAME:-YOUR_USERNAME}
    fi
    if [[ -z "${PASSWORD}" ]]; then
      read -srp "Git password or token: " PASSWORD
      echo
    fi

    echo "👉 [3] Applying Secret '${SECRET_NAME}' with HTTPS basic auth..."
    kubectl -n "${ARGO_NAMESPACE}" create secret generic "${SECRET_NAME}" \
      --from-literal=url="${REPO_URL}" \
      --from-literal=username="${USERNAME}" \
      --from-literal=password="${PASSWORD}" \
      --dry-run=client -o yaml | kubectl -n "${ARGO_NAMESPACE}" apply -f -
    kubectl -n "${ARGO_NAMESPACE}" label secret "${SECRET_NAME}" \
      argocd.argoproj.io/secret-type=repository
    ;;
  ssh)
    SSH_PRIVATE_KEY_PATH=${SSH_PRIVATE_KEY_PATH:-}
    if [[ -z "${SSH_PRIVATE_KEY_PATH}" ]]; then
      read -rp "Path to SSH private key [default: ~/.ssh/id_rsa]: " SSH_PRIVATE_KEY_PATH
      SSH_PRIVATE_KEY_PATH=${SSH_PRIVATE_KEY_PATH:-~/.ssh/id_rsa}
    fi
    if [[ ! -f "${SSH_PRIVATE_KEY_PATH}" ]]; then
      echo "ERROR: SSH private key not found at ${SSH_PRIVATE_KEY_PATH}" >&2
      exit 1
    fi

    echo "👉 [3] Applying Secret '${SECRET_NAME}' with SSH private key..."
    kubectl -n "${ARGO_NAMESPACE}" create secret generic "${SECRET_NAME}" \
      --from-literal=url="${REPO_URL}" \
      --from-literal=username="${USERNAME}" \
      --from-file=sshPrivateKey="${SSH_PRIVATE_KEY_PATH}" \
      --dry-run=client -o yaml | kubectl -n "${ARGO_NAMESPACE}" apply -f -
    kubectl -n "${ARGO_NAMESPACE}" label secret "${SECRET_NAME}" \
      argocd.argoproj.io/secret-type=repository
    ;;
  *)
    echo "ERROR: Unsupported AUTH_TYPE='${AUTH_TYPE}'. Use 'https_basic' or 'ssh'." >&2
    exit 1
    ;;
esac

# 3) Build and load local image into kind (optional)
if [[ "$SKIP_IMAGE" != "1" ]]; then
  echo "👉 [4] Building image ${IMAGE_NAME} and loading into kind cluster ${CLUSTER_NAME}..."
  ( cd "$ROOT_DIR/platform/apps/some-service" && docker build -t "$IMAGE_NAME" . )
  kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"
else
  echo "👉 [4] Skipping image build/load as requested (SKIP_IMAGE=1)"
fi

# 4) Terraform: create Argo CD Application (Argo CD is already installed upstream)
# Prepare optional Helm values overrides provided via file
echo "👉 [5] Apply Terraform for the Application"
VALUES_ARG=""
if [[ -n "${TF_VALUES_OVERRIDES_FILE:-}" ]]; then
  if [[ -f "$TF_VALUES_OVERRIDES_FILE" ]]; then
    # Escape as a single string for -var values_overrides
    VALUES_CONTENT=$(cat "$TF_VALUES_OVERRIDES_FILE")
    VALUES_ARG="-var=values_overrides=${VALUES_CONTENT//$'\n'/\\n}"
    echo "Using Helm values overrides from $TF_VALUES_OVERRIDES_FILE"
  else
    echo "WARNING: TF_VALUES_OVERRIDES_FILE set but file not found: $TF_VALUES_OVERRIDES_FILE"
  fi
fi

pushd "$TF_DIR" >/dev/null
terraform init -input=false
terraform apply -input=false -auto-approve \
  -var="repo_url=${REPO_URL}" \
  -var="repo_path=platform/apps/some-service/deploy/helm" \
  -var="namespace=${APP_NAMESPACE}" \
  -var="argo_namespace=${ARGO_NAMESPACE}" ${VALUES_ARG}
popd >/dev/null

echo "👉 [6] Deployment requested. Argo CD will sync the Application."

echo
echo "- Default Argo CD username / password:"
echo "    admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"
echo
echo "Next steps:"
echo "- Check Argo CD Application:"
echo "    kubectl -n ${ARGO_NAMESPACE} get applications.argoproj.io"
echo "- Check workload: "
echo "    kubectl -n ${APP_NAMESPACE} get pods,svc"
echo "- Port-forward to access http://localhost:3000/:"
echo "    kubectl -n ${APP_NAMESPACE} port-forward svc/some-service 3000:3000"
