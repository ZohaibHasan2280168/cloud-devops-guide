# 04 — AWS EC2 & Zero-Trust Security Group Chaining

Amazon Elastic Compute Cloud (EC2) provides resizable compute capacity in the cloud. In production architectures, EC2 instances host container runtimes, Kubernetes worker nodes, or reverse proxies.

---

## 1. Zero-Trust Security Group Chaining Architecture

A critical production standard is **Security Group Chaining**: instead of whitelisting IP addresses or broad VPC CIDR blocks (`10.0.0.0/16`), one Security Group directly references another Security Group ID.

```mermaid
graph LR
    Internet([🌐 Public Internet])
    
    subgraph Public_Subnet ["Public Subnet"]
        EC2["EC2 Instance (3.94.149.149)<br/>Security Group: sg-ec2-demo"]
    end

    subgraph Private_Subnet ["Private Subnet"]
        RDS[("Amazon RDS PostgreSQL<br/>Security Group: sg-rds-db")]
    end

    Internet -->|Inbound Port 80 (HTTP)<br/>Inbound Port 22 (SSH)| EC2
    EC2 -->|Inbound Port 5432<br/>Source: sg-ec2-demo ONLY| RDS
    Internet -.->|BLOCKED 0.0.0.0/0| RDS
```

### Why SG Chaining is Superior:
1. **Dynamic Scaling:** If auto-scaling adds 10 new EC2 nodes, their dynamic private IPs are automatically allowed without modifying firewall rules.
2. **Zero Blast Radius:** Unauthenticated machines within the same VPC subnet cannot connect to the database.

---

## 2. Step-by-Step Security Group Setup via AWS CLI

```bash
# 💻 [Local Laptop Terminal]

# 1. Create Security Group for EC2 Demo Server
EC2_SG=$(aws ec2 create-security-group \
  --group-name smartdoc-ec2-sg \
  --description "Security group for public EC2 server" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# Allow SSH (Port 22) from your IP and HTTP (Port 80) from anywhere
aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

# 2. Create Security Group for RDS PostgreSQL
RDS_SG=$(aws ec2 create-security-group \
  --group-name smartdoc-rds-sg \
  --description "Security group for private RDS database" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# 3. CHAIN SECURITY GROUPS: Allow PostgreSQL (Port 5432) ONLY from EC2_SG ID
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $EC2_SG

echo "Chained $EC2_SG into $RDS_SG on Port 5432"
```

---

## 3. Provisioning the Ubuntu EC2 Instance

```bash
# 💻 [Local Laptop Terminal]
# Launch a Free-Tier t2.micro or t3.micro Ubuntu 22.04 LTS instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t2.micro \
  --key-name smartdoc-key \
  --security-group-ids $EC2_SG \
  --subnet-id $PUB_SUB1 \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=smartdoc-ec2-demo}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "Launched Instance: $INSTANCE_ID"

# Query the Public IPv4 Address
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
echo "Instance Public IP: $PUBLIC_IP"
```

---

## 4. EC2 Bootstrapping Script (Production User-Data)

Execute on initial login to prepare the host for Docker and microservices:

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git nginx htop

# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose Plugin
sudo apt install -y docker-compose-plugin

# Configure 2GB Swap Memory (Prevent OOM on t2.micro)
sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

---

## 5. Nginx Production Reverse Proxy Configuration

Nginx acts as the edge reverse proxy, receiving public HTTP traffic on port 80 and forwarding requests to backend containers.

### Configuration file: `/etc/nginx/sites-available/smartdoc`
```nginx
server {
    listen 80;
    server_name _;

    client_max_body_size 50M;

    # Frontend Route
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API Route
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Enable site and test configuration
sudo ln -s /etc/nginx/sites-available/smartdoc /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```
