#!/usr/bin/env bash
# ==============================================================================
# Kubernetes Suite Installer: Kubectl, Minikube, Helm 3
# Author: Zohaib Hassan (Cloud & DevOps Engineer)
# ==============================================================================

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo: sudo ./install-k8s.sh"
    exit 1
fi

echo ">>> [1/3] Installing latest stable kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo ">>> [2/3] Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

echo ">>> [3/3] Installing Helm 3..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh >/dev/null 2>&1
rm -f get_helm.sh

echo "=========================================="
echo " Kubernetes Suite installation completed!"
kubectl version --client
minikube version
helm version --short
echo "Start Minikube anytime with: minikube start --driver=docker"
echo "=========================================="
