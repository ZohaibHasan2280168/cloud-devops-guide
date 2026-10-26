#!/usr/bin/env bash
# ==============================================================================
# Master DevOps Tooling Installer
# Supports: Ubuntu 20.04 / 22.04 / 24.04 LTS & Debian
# Author: Zohaib Hassan (Cloud & DevOps Engineer)
# Repository: https://github.com/ZohaibHasan2280168/cloud-devops-guide
# ==============================================================================

set -eo pipefail

# ANSI Color Codes for Professional Console Output
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Root / Sudo Check
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo or as root: sudo ./install-all.sh"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
log_info "Configuring DevOps tools for primary user: ${ACTUAL_USER}"

# 2. System Update & Foundational Utilities
log_info "Step 1/7: Updating APT package repositories..."
apt-get update -y
apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    jq \
    unzip \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    software-properties-common

log_success "System utilities installed."

# 3. Docker Engine & Docker Compose
log_info "Step 2/7: Installing Docker Engine & Docker Compose (Official Repo)..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker "${ACTUAL_USER}"
log_success "Docker Engine & Docker Compose installed and service enabled."

# 4. Kubectl CLI
log_info "Step 3/7: Installing Kubernetes CLI (kubectl)..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
log_success "kubectl ${KUBECTL_VERSION} installed to /usr/local/bin/kubectl."

# 5. Minikube Local Kubernetes
log_info "Step 4/7: Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64
log_success "Minikube installed to /usr/local/bin/minikube."

# 6. Helm 3 Package Manager
log_info "Step 5/7: Installing Helm 3..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh >/dev/null 2>&1
rm -f get_helm.sh
log_success "Helm 3 installed successfully."

# 7. AWS CLI v2
log_info "Step 6/7: Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update >/dev/null 2>&1
rm -rf aws awscliv2.zip
log_success "AWS CLI v2 installed successfully."

# 8. HashiCorp Terraform
log_info "Step 7/7: Installing HashiCorp Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg 2>/dev/null | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
apt-get update -y
apt-get install -y terraform
log_success "Terraform installed successfully."

# 9. Trivy Vulnerability Scanner
log_info "Bonus: Installing Trivy DevSecOps scanner..."
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list > /dev/null
apt-get update -y
apt-get install -y trivy >/dev/null 2>&1 || log_warn "Trivy optional installation skipped."

# 10. Verification & Diagnostics Dashboard
echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}🎉 DevOps Tooling Installation Complete! Diagnostic Summary:  ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -n "Docker Engine:    "; docker --version 2>/dev/null || echo "NOT DETECTED"
echo -n "Docker Compose:   "; docker compose version 2>/dev/null || echo "NOT DETECTED"
echo -n "Kubernetes CLI:   "; kubectl version --client 2>/dev/null | head -n1 || echo "NOT DETECTED"
echo -n "Minikube:         "; minikube version 2>/dev/null | head -n1 || echo "NOT DETECTED"
echo -n "Helm 3:           "; helm version --short 2>/dev/null || echo "NOT DETECTED"
echo -n "AWS CLI v2:       "; aws --version 2>/dev/null || echo "NOT DETECTED"
echo -n "Terraform:        "; terraform -version 2>/dev/null | head -n1 || echo "NOT DETECTED"
echo -n "Trivy Scanner:    "; trivy --version 2>/dev/null | head -n1 || echo "NOT DETECTED"
echo -e "${GREEN}================================================================${NC}"
echo -e "${YELLOW}NOTE:${NC} To run Docker without 'sudo', please logout and log back in, or run:"
echo -e "      ${BLUE}newgrp docker${NC}"
echo ""
