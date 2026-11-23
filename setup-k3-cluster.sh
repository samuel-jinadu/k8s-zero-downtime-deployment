#!/bin/bash

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
  SERVERS_RUNNING=$(k3d cluster list | grep "^${CLUSTER_NAME}" | awk '{print $2}')
  echo "▶ Cluster '${CLUSTER_NAME}' exists (servers: ${SERVERS_RUNNING})"

  if echo "${SERVERS_RUNNING}" | grep -q "^0/"; then
    echo "  Restarting stopped cluster..."
    k3d cluster start ${CLUSTER_NAME}
  else
    echo "  Cluster is already running ✅"
  fi
else
  echo "▶ Creating new cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}" --wait
fi