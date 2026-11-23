#!/bin/bash

if command -v k3d &>/dev/null; then
  echo "▶ k3d already installed ($(k3d version | head -1 | awk '{print $3}')) — skipping"
else
  echo ""
  echo "▶ Installing k3d..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  echo "  ✅ k3d $(k3d version | head -1 | awk '{print $3}') installed"
fi

k3d cluster create default