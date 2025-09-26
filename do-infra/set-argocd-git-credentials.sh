#!/usr/bin/env bash
set -euo pipefail

# Set Git credentials for Argo CD to access a private repository
# Argo CD v2.1+ favors using credential Secrets instead of Repository CR secrets.
# This script creates/updates a Secret the Argo CD repo-server can use.
# - For HTTPS: kind=Opaque with username/password data
# - For SSH: kind=Opaque with sshPrivateKey data
# Optionally, for Argo CD <2.1 you can still create a Repository CR by setting CREATE_REPOSITORY_CR=1.
#
# Usage:
#   ./set-argocd-git-credentials.sh
# Environment (optional):
#   ARGO_NAMESPACE=argocd     # namespace where Argo CD is installed
#   AUTH_TYPE=https_basic     # or ssh
#   REPO_URL=                 # e.g., https://github.com/your-org/your-repo.git or git@github.com:your-org/your-repo.git
#   USERNAME=                 # for https_basic
#   PASSWORD=                 # for https_basic (prefer to input interactively)
#   SSH_PRIVATE_KEY_PATH=     # for ssh, path to private key; will be read securely
#   CREATE_REPOSITORY_CR=0    # set to 1 to also create a Repository CR (for older Argo CD)
#
# Notes:
# - This script avoids storing secrets in Terraform state. It applies them directly via kubectl.
# - It is idempotent; running it again updates existing resources.

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: Required command '$1' not found in PATH" >&2; exit 1; }
}

need_cmd kubectl

ARGO_NAMESPACE=${ARGO_NAMESPACE:-argocd}
AUTH_TYPE=${AUTH_TYPE:-https_basic}
REPO_URL=${REPO_URL:-https://github.com/zicornell-do/do-deploy-example.git}
CREATE_REPOSITORY_CR=${CREATE_REPOSITORY_CR:-0}

kubectl get ns "${ARGO_NAMESPACE}" >/dev/null 2>&1 || {
  echo "ERROR: Argo CD namespace '${ARGO_NAMESPACE}' not found. Run do-infra/deploy.sh first." >&2
  exit 1
}

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

    echo "Applying Secret '${SECRET_NAME}' with HTTPS basic auth..."
    kubectl -n "${ARGO_NAMESPACE}" create secret generic "${SECRET_NAME}" \
      --from-literal=username="${USERNAME}" \
      --from-literal=password="${PASSWORD}" \
      --dry-run=client -o yaml | kubectl -n "${ARGO_NAMESPACE}" apply -f -

    if [[ "$CREATE_REPOSITORY_CR" == "1" ]]; then
      echo "Applying Argo CD Repository CR (legacy mode)..."
      cat <<YAML | kubectl -n "${ARGO_NAMESPACE}" apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Repository
metadata:
  name: repo-$(echo -n "$REPO_URL" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
spec:
  url: ${REPO_URL}
  type: git
  usernameSecret:
    name: ${SECRET_NAME}
    key: username
  passwordSecret:
    name: ${SECRET_NAME}
    key: password
YAML
    else
      echo "Skipping Repository CR creation (Argo CD v2.1+ uses credential Secrets)."
    fi
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

    echo "Applying Secret '${SECRET_NAME}' with SSH private key..."
    kubectl -n "${ARGO_NAMESPACE}" create secret generic "${SECRET_NAME}" \
      --from-file=sshPrivateKey="${SSH_PRIVATE_KEY_PATH}" \
      --dry-run=client -o yaml | kubectl -n "${ARGO_NAMESPACE}" apply -f -

    if [[ "$CREATE_REPOSITORY_CR" == "1" ]]; then
      echo "Applying Argo CD Repository CR..."
      cat <<YAML | kubectl -n "${ARGO_NAMESPACE}" apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Repository
metadata:
  name: repo-$(echo -n "$REPO_URL" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
spec:
  url: ${REPO_URL}
  type: git
  sshPrivateKeySecret:
    name: ${SECRET_NAME}
    key: sshPrivateKey
YAML
    else
      echo "Skipping Repository CR creation (Argo CD v2.1+ uses credential Secrets)."
    fi
    ;;
  *)
    echo "ERROR: Unsupported AUTH_TYPE='${AUTH_TYPE}'. Use 'https_basic' or 'ssh'." >&2
    exit 1
    ;;
esac

echo "Done. Argo CD should now be able to access ${REPO_URL}."
