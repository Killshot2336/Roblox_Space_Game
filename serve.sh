#!/usr/bin/env bash
# Voidline: Deep Space — start Rojo serve (Linux/macOS)
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v rojo >/dev/null 2>&1; then
  echo "Rojo CLI not found. Install from https://github.com/rojo-rbx/rojo/releases"
  exit 1
fi
echo "Rojo $(rojo --version)"
echo "Serving Voidline: Deep Space — connect Studio Rojo plugin, then press F5 / Play"
exec rojo serve default.project.json
