#!/usr/bin/env bash
set -euo pipefail

# Install Argo CD (upstream) into argocd namespace
# Ref: https://argo-cd.readthedocs.io/en/stable/getting_started/

kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd

# Apply the stable install manifest
kubectl -n argocd apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s || true

# Print initial admin password hint
POD=$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-server -o name 2>/dev/null | head -n1 | sed 's|.*/||' || true)
if [[ -n "${POD:-}" ]]; then
  echo "Argo CD installed. Initial admin password (pod name): ${POD}"
else
  echo "Argo CD installed. Use 'kubectl -n argocd get pods' to find the argocd-server pod name for the initial admin password."
fi
