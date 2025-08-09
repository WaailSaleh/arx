#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Installing..."
  bash "$REPO_ROOT/scripts/install_docker.sh"
fi

cd "$REPO_ROOT"

echo "Bringing up Palworld server and uploader..."
sudo docker compose up -d --build

echo "Done."
echo "- Palworld UDP port: 8211 (and 27015)"
echo "- RCON: 25575 (if enabled)"
echo "- Uploader: http://<server-ip>:8080/"