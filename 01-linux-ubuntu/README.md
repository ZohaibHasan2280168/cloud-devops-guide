# 01 — Linux & Ubuntu Production Administration

Linux is the foundational operating system of the modern cloud, container engines, and Kubernetes nodes. A DevOps engineer must be fluent in managing Linux environments, configuring system daemons, managing memory constraints, and troubleshooting network performance.

---

## 1. Core Concepts & Why Linux for DevOps

1. **Deterministic & Lightweight:** Linux provides predictable resource isolation (cgroups and namespaces), which form the building blocks of Docker and Kubernetes.
2. **Systemd as Init System:** In production cloud VMs (e.g. Ubuntu EC2), background processes (Docker, Nginx, Runner daemons) are managed by `systemd`.
3. **Headless Administration:** Production instances have no graphical interface; 100% of tasks are handled over SSH via bash/sh.

---

## 2. Essential Commands Reference

### A. System & Package Management

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Update package repositories and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Install essential DevOps networking and debugging packages
sudo apt install -y curl wget git htop net-tools unzip jq ufw build-essential
```

---

### B. User & Permission Management

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Create a dedicated application user without password login
sudo adduser --disabled-password --gecos "" deployuser

# Add user to sudoers group
sudo usermod -aG sudo deployuser

# Add user to docker group (run docker commands without sudo)
sudo usermod -aG docker $USER
newgrp docker

# Modify file permissions:
# 400 = Read-only for owner (mandatory for AWS .pem SSH keys)
chmod 400 my-key.pem

# 755 = Read/Execute for all, Write for owner (standard for scripts/binaries)
chmod +x setup.sh

# Recursive ownership change
sudo chown -R $USER:$USER /var/www/html
```

---

### C. Systemd Service Administration

Systemd manages background background services (units) across boot cycles.

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Check status of a service (e.g., docker, nginx)
sudo systemctl status docker

# Start, stop, and restart services
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# Enable service to automatically start on boot
sudo systemctl enable docker
sudo systemctl enable nginx

# Reload systemd configuration after creating or modifying a .service file
sudo systemctl daemon-reload
```

#### Writing a Custom Systemd Service
File location: `/etc/systemd/system/myapp.service`
```ini
[Unit]
Description=My Production App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=5
Environment=PORT=8000

[Install]
WantedBy=multi-user.target
```

---

### D. Log Inspection with `journalctl`

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Follow live logs for a specific service
sudo journalctl -u docker.service -f

# View the last 100 log lines of a service
sudo journalctl -u nginx -n 100

# View logs since a specific time window
sudo journalctl -u myapp --since "30 minutes ago"

# View system boot logs
sudo journalctl -b
```

---

### E. Memory, Disk & Resource Monitoring

Small cloud instances (like AWS `t2.micro` or `t3.small`) can experience silent kernel out-of-memory (OOM) kills.

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Check RAM and Swap usage in Megabytes
free -m -h

# Check Disk space usage across all mounted filesystems
df -h

# Find largest directories in current path
du -sh * | sort -h

# Interactive process monitor (CPU, Memory, Threads)
htop

# Check listening network sockets and active ports (modern standard)
sudo ss -tuln
# (Flags: -t = TCP, -u = UDP, -l = Listening, -n = Numeric ports)

# Find which exact process (PID) is holding a specific port (e.g. port 3002 or 80)
sudo lsof -i :3002
sudo lsof -i :80

# Clean, brief 1-line table of all network interfaces & IPs (modern replacement for ifconfig)
ip -br a
```

---

### F. Swap Memory Setup (Mandatory for 1GB/2GB Cloud VMs)

When running Docker, Next.js builds, or multiple containers on free-tier EC2, RAM exhaustion causes the instance to freeze. Creating a 2GB Swap file solves this:

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# 1. Allocate a 2GB file using dd
sudo dd if=/dev/zero of=/swapfile bs=128M count=16

# 2. Secure file permissions (only root can read/write)
sudo chmod 600 /swapfile

# 3. Format file as swap area
sudo mkswap /swapfile

# 4. Enable swap immediately
sudo swapon /swapfile

# 5. Verify swap is active
free -m
sudo swapon --show

# 6. Make swap persistent across server reboots
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

---

### G. UFW (Uncomplicated Firewall)

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Allow SSH first to avoid locking yourself out
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check active rules
sudo ufw status verbose
```

---

### H. SSH Key Management

```bash
# 💻 [Local Laptop Terminal]
# Generate an ED25519 or RSA 4096 SSH key pair
ssh-keygen -t ed25519 -C "admin@company.com"

# Copy public key to remote server
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@3.94.149.149

# Connect using a private key file
ssh -i ~/.ssh/my-aws-key.pem ubuntu@3.94.149.149

# Set secure SSH key permissions (mandatory)
chmod 400 ~/.ssh/my-aws-key.pem
```

---

## 3. Comparison Cheat Table

| Task | 💻 [Local Laptop Terminal] | ☁️ [Ubuntu EC2 / Cloud VM] |
| :--- | :--- | :--- |
| **Package Install** | `brew install <tool>` / `choco` / `apt` | `sudo apt install -y <tool>` |
| **Process Logs** | stdout / IDE debugger | `journalctl -u <service> -f` |
| **Background Run** | Terminal tab or Docker Desktop | `systemd` daemon / Docker daemon |
| **Firewall** | OS settings | `sudo ufw status` + AWS Security Group |
| **Service Status**| `ps aux` / Docker GUI | `sudo systemctl status <service>` |
