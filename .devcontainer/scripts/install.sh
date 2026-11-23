#!/bin/bash

echo "================================================"
echo "  Installing K3d Kubernetes Learning Environment"
echo "================================================"

# ── k3d ──────────────────────────────────────────────────────────────────────
if command -v k3d &>/dev/null; then
  echo "▶ k3d already installed ($(k3d version | head -1 | awk '{print $3}')) — skipping"
else
  echo ""
  echo "▶ Installing k3d..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  echo "  ✅ k3d $(k3d version | head -1 | awk '{print $3}') installed"
fi

# ── ensure .kube dir exists ───────────────────────────────────────────────────
mkdir -p ~/.kube

echo ""
echo "================================================"
echo "  ✅ Installation complete!"
echo "================================================"