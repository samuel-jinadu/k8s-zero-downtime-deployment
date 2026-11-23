#!/bin/bash
# This script is destructive - BE WARNED

CLUSTER_NAME=default

if command -v k3d &>/dev/null; then
  echo "▶ k3d already installed ($(k3d version | head -1 | awk '{print $3}')) — skipping"
else
  echo ""
  echo "▶ Installing k3d..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  echo "  ✅ k3d $(k3d version | head -1 | awk '{print $3}') installed"
fi


if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
  echo "▶ Deleting existing cluster '${CLUSTER_NAME}' to recreate with port 8080 binding..."
  k3d cluster delete "${CLUSTER_NAME}"
fi

echo "▶ Creating new cluster '${CLUSTER_NAME}'..."
k3d cluster create "${CLUSTER_NAME}" --port "8080:8080@loadbalancer" --wait
