#!/usr/bin/env bash
set -euo pipefail

# Simple on-demand sync without Argo CD (optional helper)
# Requires: kubectl, helm

CHART_DIR="$(cd "$(dirname "$0")" && pwd)/helm"
NAMESPACE=${1:-some-service}

kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

# Render and apply chart with default values
helm template some-service "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  | kubectl -n "$NAMESPACE" apply -f -

echo "Synced chart to namespace $NAMESPACE"
