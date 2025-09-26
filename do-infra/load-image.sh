#!/usr/bin/env bash
set -euo pipefail

# Build the some-service image and load it into kind
CLUSTER_NAME=${CLUSTER_NAME:-do-demo}
IMAGE_NAME=${IMAGE_NAME:-some-service:latest}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/platform/apps/some-service"

# Build image
( cd "$APP_DIR" && docker build -t "$IMAGE_NAME" . )

# Load into kind cluster
kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"

echo "Loaded image $IMAGE_NAME into kind cluster $CLUSTER_NAME"
