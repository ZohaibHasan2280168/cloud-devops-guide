#!/usr/bin/env bash
# ==============================================================================
# Docker Engine & Docker Compose (Official Distribution) Installer
# Author: Zohaib Hassan (Cloud & DevOps Engineer)
# ==============================================================================

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo: sudo ./install-docker.sh"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"

echo ">>> [1/4] Installing dependencies..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

echo ">>> [2/4] Adding Docker official GPG key & APT repo..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>> [3/4] Installing Docker CE, CLI, and Compose Plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo ">>> [4/4] Enabling systemd service and configuring non-root user..."
systemctl enable --now docker
usermod -aG docker "${ACTUAL_USER}"

echo "=========================================="
echo " Docker installation successfully completed!"
docker --version
docker compose version
echo "Run 'newgrp docker' to use docker without sudo."
echo "=========================================="
