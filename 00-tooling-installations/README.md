# 00 — DevOps Engineering Tooling & Installations Playbook

> A production-grade installation guide, cheatsheet, and automated provisioning toolkit for Linux (Ubuntu/Debian) workstations, cloud servers (AWS EC2), and local development environments.

---

## 📌 Table of Tools Covered

| Tool | Category | Primary Production Use-Case | Verification Command |
| :--- | :--- | :--- | :--- |
| **Docker Engine & Compose** | Containerization | Build, package, run isolated microservices | `docker --version && docker compose version` |
| **Kubectl** | Orchestration | CLI control plane for Kubernetes & EKS clusters | `kubectl version --client` |
| **Minikube** | Local Kubernetes | Local single-node K8s cluster for testing manifests | `minikube status` |
| **Helm** | K8s Package Manager | Deploy complex charts (Prometheus, Ingress, Cert-Manager) | `helm version --short` |
| **AWS CLI v2** | Cloud Management | S3, ECR login, EKS kubeconfig, IAM & EC2 administration | `aws --version` |
| **Terraform** | Infrastructure as Code | Declarative cloud provisioning (VPC, EKS, RDS) | `terraform -version` |
| **Trivy** | DevSecOps Security | Vulnerability scanning for container images & code | `trivy --version` |
| **Essential Utilities** | System Administration | `curl`, `wget`, `git`, `jq`, `unzip`, `htop`, `net-tools` | `jq --version && git --version` |

---

## 🚀 1-Click Automated Setup

If you want to configure an entire fresh Ubuntu machine in under 2 minutes:

```bash
# Clone the repository
git clone https://github.com/ZohaibHasan2280168/cloud-devops-guide.git
cd cloud-devops-guide/00-tooling-installations/scripts

# Make scripts executable and run master installer
chmod +x *.sh
sudo ./install-all.sh
```

---

## 📖 Step-by-Step Manual Installation Guide

### 1. Essential System Prerequisites

Always update your package index and install foundational networking and decompression tools:

```bash
# ☁️ [Ubuntu / Debian Terminal]
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git jq unzip htop net-tools ca-certificates gnupg lsb-release build-essential
```

---

### 2. Docker Engine & Docker Compose (Official Repository)

Do NOT use `apt install docker.io` as it delivers an outdated distribution. Always use Docker's official GPG signed apt repository:

```bash
# 1. Set up Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 2. Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Install Docker packages
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Enable Docker service on boot
sudo systemctl enable --now docker

# 5. Run Docker without sudo (CRITICAL for DevOps!)
sudo usermod -aG docker $USER
newgrp docker

# 6. Verify installation
docker run --rm hello-world
```

---

### 3. Kubernetes CLI (`kubectl`)

`kubectl` communicates with the Kubernetes API server (local Minikube or cloud AWS EKS):

```bash
# 1. Download official v1.32+ binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# 2. Install kubectl to system binary path
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 3. Enable bash autocompletion (Optional Productivity Boost)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc

# 4. Verify
kubectl version --client
```

---

### 4. Minikube (Local Kubernetes Cluster)

Minikube runs a single-node Kubernetes cluster inside a local Docker container:

```bash
# 1. Download latest Minikube Linux binary
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# 2. Install to system path
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# 3. Start Minikube with the Docker driver
minikube start --driver=docker

# 4. Verify cluster health
minikube status
kubectl get nodes
```

---

### 5. Helm 3 (Kubernetes Package Manager)

Helm manages complex Kubernetes applications via standardized versioned Charts:

```bash
# 1. Official Helm 3 install script
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# 2. Verify
helm version
```

---

### 6. AWS CLI v2 (Official AWS Bundle)

The official AWS Command Line Interface for automating cloud infrastructure:

```bash
# 1. Download official AWS CLI v2 bundle
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# 2. Unzip and execute installer
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 3. Verify
aws --version

# 4. Configure credentials
aws configure
# Prompts for: AWS Access Key ID, Secret Access Key, Region (e.g. us-east-1), Output (json)
```

---

### 7. HashiCorp Terraform

Declarative Infrastructure as Code (IaC) tool:

```bash
# 1. Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 2. Add HashiCorp official repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 3. Install Terraform
sudo apt update && sudo apt install -y terraform

# 4. Verify
terraform -version
```

---

### 8. Trivy (DevSecOps Container & Security Scanner)

Trivy scans Docker images, Git repos, and Kubernetes configurations for CVE vulnerabilities:

```bash
# 1. Install Trivy via official repository
sudo apt install -y wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update && sudo apt install -y trivy

# 2. Scan an image (Example):
trivy image nginx:alpine
```

---

## 🛠️ Verification & Diagnostic Health Dashboard

Run this quick command block to inspect all installed tools simultaneously:

```bash
echo "=== DevOps Health Check ==="
echo -n "Docker:     "; docker --version 2>/dev/null || echo "NOT INSTALLED"
echo -n "Compose:    "; docker compose version 2>/dev/null || echo "NOT INSTALLED"
echo -n "Kubectl:    "; kubectl version --client 2>/dev/null || echo "NOT INSTALLED"
echo -n "Minikube:   "; minikube version 2>/dev/null || echo "NOT INSTALLED"
echo -n "Helm:       "; helm version --short 2>/dev/null || echo "NOT INSTALLED"
echo -n "AWS CLI:    "; aws --version 2>/dev/null || echo "NOT INSTALLED"
echo -n "Terraform:  "; terraform -version 2>/dev/null | head -n1 || echo "NOT INSTALLED"
echo -n "Trivy:      "; trivy --version 2>/dev/null | head -n1 || echo "NOT INSTALLED"
echo "==========================="
```

---

## 🧹 Tool Uninstallation & Cleanup (When Needed)

If an interviewer asks *"How do you cleanly remove a corrupted Docker or K8s installation?"*:

```bash
# Remove Docker completely
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker

# Remove Kubectl & Minikube binaries
sudo rm -f /usr/local/bin/kubectl /usr/local/bin/minikube /usr/local/bin/helm
minikube delete --all --purge 2>/dev/null || true
rm -rf ~/.minikube ~/.kube

# Remove AWS CLI
sudo rm -rf /usr/local/aws-cli /usr/local/bin/aws
```

---

## ⚡ Execution Guide: Running Scripts & YAML Files

Here is how you can execute these tools in any scenario (both with git clone and directly without cloning):

### 🅰️ Method A: Direct Execution via Git (No Clone / 1-Liner)
Ideal for fast provisioning of fresh cloud VMs (AWS EC2, DigitalOcean, local machines) without cloning the repository.

#### 1. Bash Automation (Direct 1-Liner):
```bash
# 🚀 1-Liner: Install ALL DevOps Tools in one go (Recommended)
curl -fsSL https://raw.githubusercontent.com/ZohaibHasan2280168/cloud-devops-guide/main/00-tooling-installations/scripts/install-all.sh | sudo bash

# 🐳 1-Liner: Install Docker & Docker Compose only
curl -fsSL https://raw.githubusercontent.com/ZohaibHasan2280168/cloud-devops-guide/main/00-tooling-installations/scripts/install-docker.sh | sudo bash

# ☸️ 1-Liner: Install Kubernetes Suite (kubectl + minikube + helm) only
curl -fsSL https://raw.githubusercontent.com/ZohaibHasan2280168/cloud-devops-guide/main/00-tooling-installations/scripts/install-k8s.sh | sudo bash

# ☁️ 1-Liner: Install Cloud Tools (AWS CLI v2 + Terraform) only
curl -fsSL https://raw.githubusercontent.com/ZohaibHasan2280168/cloud-devops-guide/main/00-tooling-installations/scripts/install-cloud.sh | sudo bash
```

#### 2. Ansible Playbook YAML (Direct without clone):
```bash
# Fetch and execute Ansible YAML playbook locally in 1 step:
sudo apt update && sudo apt install -y ansible
curl -fsSL https://raw.githubusercontent.com/ZohaibHasan2280168/cloud-devops-guide/main/00-tooling-installations/yaml/devops-playbook.yml -o /tmp/devops-playbook.yml
ansible-playbook -i localhost, -c local /tmp/devops-playbook.yml
```

---

### 🅱️ Method B: Local Execution (After Cloning Repo)

If you have cloned this repository onto your machine:

#### 1. Running Bash Scripts:
```bash
# 1. Navigate to scripts directory
cd cloud-devops-guide/00-tooling-installations/scripts

# 2. Grant execute permissions
chmod +x *.sh

# 3. Execute desired script with sudo:
sudo ./install-all.sh     # Master installer (installs everything)
sudo ./install-docker.sh  # Docker only
sudo ./install-k8s.sh     # Kubectl, Minikube, Helm
sudo ./install-cloud.sh   # AWS CLI v2, Terraform
```

#### 2. Running Ansible YAML Playbook:
```bash
# 1. Navigate to YAML directory
cd cloud-devops-guide/00-tooling-installations/yaml

# 2. Execute playbook locally
ansible-playbook -i localhost, -c local devops-playbook.yml
```

---

### ☁️ Method C: AWS EC2 Cloud-Init Auto-Bootstrap (`ec2-cloud-init.yaml`)

This file is designed for **Zero-Touch AWS Cloud Provisioning**:

1. Open **AWS Management Console** ➡️ Navigate to **EC2** ➡️ Click **Launch Instance**.
2. Select **Ubuntu 24.04 / 22.04 LTS**.
3. Scroll down to the bottom section: **Advanced Details**.
4. Locate the **User data** text box.
5. Copy the entire contents of [`yaml/ec2-cloud-init.yaml`](yaml/ec2-cloud-init.yaml) and paste it into the **User data** box.
6. Click **Launch Instance**.

> 💡 *When the instance boots up, AWS automatically runs this cloud-init script in the background. When you SSH into your EC2 server after 2 minutes, all tools (Docker, Kubectl, Helm, Terraform) are already installed and ready!*

