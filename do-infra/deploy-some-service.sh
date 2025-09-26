#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper to apply Terraform for Argo CD + some-service Application
# Usage: REPO_URL=https://github.com/your-org/do-deploy-example.git ./deploy-some-service.sh

REPO_URL=${REPO_URL:-https://github.com/zicornell-do/do-deploy-example.git}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TF_DIR="$SCRIPT_DIR/terraform"
export TF_VAR_kubeconfig="${TF_VAR_kubeconfig:-$HOME/.kube/config}"

pushd "$TF_DIR" >/dev/null
terraform init
terraform apply -auto-approve \
  -var="repo_url=${REPO_URL}" \
  -var="repo_path=platform/apps/some-service/deploy/helm"
popd >/dev/null

echo "Requested Argo CD to deploy some-service from ${REPO_URL}."