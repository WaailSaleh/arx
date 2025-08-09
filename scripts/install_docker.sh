#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates gnupg lsb-release
fi

# Remove old docker if present
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
CODENAME=$(lsb_release -cs)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start
sudo systemctl enable --now docker

# Add current user to docker group (requires re-login)
if id -nG "$USER" | grep -qw docker; then
  echo "User already in docker group"
else
  sudo usermod -aG docker "$USER" || true
  echo "Added $USER to docker group. Re-login for it to take effect."
fi

echo "Docker installation complete. Version:"
docker --version || true