#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-do-demo}

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster ${CLUSTER_NAME} not found"
  exit 0
fi

kind delete cluster --name "$CLUSTER_NAME"
echo "Cluster ${CLUSTER_NAME} deleted"
