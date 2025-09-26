do-infra: Local Kubernetes infra with kind, Argo CD, and some-service

This directory contains simple scripts and Terraform to set up a local Kubernetes cluster using kind, install Argo CD, 
and deploy the some-service Helm chart from this repository.

Prerequisites:
- Docker
- kind
- kubectl
- Terraform (>= 1.4)
- Helm (for troubleshooting; not strictly required)

Quick start (one command):
- From the repo root:
  REPO_URL=https://github.com/your-org/do-deploy-example.git ./do-infra/deploy.sh

This will:
- Create a kind cluster (if it doesn't exist),
- Install/ensure Argo CD is running,
- Build and load a local image into kind (override with IMAGE_NAME or set SKIP_IMAGE=1),
- Run Terraform to create the Argo CD Application pointing to the Helm chart (Argo CD itself is installed via upstream manifest).

Verify the service:
- kubectl -n some-service get pods,svc
- kubectl -n some-service port-forward svc/some-service 3000:3000
- Open http://localhost:3000/

Advanced options (env vars):
- CLUSTER_NAME: kind cluster name (default: do-demo)
- IMAGE_NAME: image tag built/loaded into kind (default: some-service:local)
- SKIP_IMAGE=1: skip building/loading image
- TF_VALUES_OVERRIDES_FILE=path/to/values.yaml: additional Helm values for Argo CD
- APP_NAMESPACE (default: some-service), ARGO_NAMESPACE (default: argocd)

Git credentials for private repos (Argo CD v2.1+):
- After ./deploy.sh, run:
  ./set-argocd-git-credentials.sh
  This creates/updates a Secret in the argocd namespace with your Git creds (no secrets in Terraform state).
  Defaults for prompts are magic placeholders like "YOUR_USERNAME" if you press Enter.
  Supported AUTH_TYPE values: https_basic (username/password or PAT) and ssh.
  For older Argo CD versions (<2.1), you can set CREATE_REPOSITORY_CR=1 to also create a Repository CR that references the Secret.

Teardown:
- Destroy Argo CD app via Terraform:
  cd terraform && terraform destroy -auto-approve
- Delete the cluster:
  ../destroy-cluster.sh

Notes:
- The Argo CD admin initial password (if using upstream install) is the name of the argocd-server pod:
  kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-server -o name | sed 's|.*/||'
- The cluster is local-only and intended for development.
