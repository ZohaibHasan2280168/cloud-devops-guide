#!/usr/bin/env bash
# ==============================================================================
# Cloud Infrastructure Tools Installer: AWS CLI v2 & Terraform
# Author: Zohaib Hassan (Cloud & DevOps Engineer)
# ==============================================================================

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo: sudo ./install-cloud.sh"
    exit 1
fi

echo ">>> [1/2] Installing AWS CLI v2..."
apt-get update -y && apt-get install -y curl unzip
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update >/dev/null 2>&1
rm -rf aws awscliv2.zip

echo ">>> [2/2] Installing HashiCorp Terraform..."
apt-get install -y gnupg software-properties-common lsb-release
wget -O- https://apt.releases.hashicorp.com/gpg 2>/dev/null | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
apt-get update -y
apt-get install -y terraform

echo "=========================================="
echo " Cloud Tools installation completed!"
aws --version
terraform -version
echo "Configure AWS credentials with: aws configure"
echo "=========================================="
