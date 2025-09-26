#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-do-demo}
KIND_CONFIG=${KIND_CONFIG:-$(dirname "$0")/kind-config.yaml}

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster ${CLUSTER_NAME} already exists"
  exit 0
fi

kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"

echo "Cluster ${CLUSTER_NAME} created. Current contexts:"
kubectl config get-contexts
