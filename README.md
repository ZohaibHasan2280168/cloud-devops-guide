# Cloud & DevOps Engineering: Zero to Production Master Playbook

> A production-grade handbook, cheatsheet, and architectural blueprint covering Linux, Docker, AWS Core Cloud Services, Kubernetes, GitOps with ArgoCD, and CI/CD Automation.

---

## 📌 Table of Contents

| Module | Title | Core Focus & Topics Covered |
| :--- | :--- | :--- |
| **[01](01-linux-ubuntu/README.md)** | **[Linux & Ubuntu Production Administration](01-linux-ubuntu/README.md)** | User management, permissions, systemd, journalctl, swap setup, storage, ufw, SSH keys. |
| **[02](02-docker-containerization/README.md)** | **[Docker & Multi-Stage Containerization](02-docker-containerization/README.md)** | Dockerfile best practices, multi-stage builds, networks, volumes, Docker Compose profiles. |
| **[03](03-aws-core-networking-vpc/README.md)** | **[AWS Core Cloud Networking & VPC](03-aws-core-networking-vpc/README.md)** | VPC, CIDR, Public vs Private Subnets, IGW, Route Tables, NAT, Multi-AZ High Availability. |
| **[04](04-aws-compute-ec2/README.md)** | **[AWS EC2 & Zero-Trust Security Group Chaining](04-aws-compute-ec2/README.md)** | Provisioning instances, SSH keys, Nginx reverse proxy, SG Chaining (No public CIDRs). |
| **[05](05-aws-database-rds/README.md)** | **[Amazon RDS PostgreSQL Architecture](05-aws-database-rds/README.md)** | DB Subnet Groups, Private Subnet isolation, parameter groups, backups, migrations, connections. |
| **[06](06-aws-storage-s3/README.md)** | **[Amazon S3 Object Storage](06-aws-storage-s3/README.md)** | S3 buckets, CLI commands, Python Boto3 streaming, lifecycle rules, bucket policies, encryption. |
| **[07](07-aws-registry-ecr/README.md)** | **[Amazon ECR Container Registry](07-aws-registry-ecr/README.md)** | Private registries, docker login with AWS CLI, image tagging with Git SHA, push/pull. |
| **[08](08-kubernetes-fundamentals/README.md)** | **[Kubernetes Core Operations & kubectl](08-kubernetes-fundamentals/README.md)** | Pods, Deployments, Services (ClusterIP, NodePort, LoadBalancer), ConfigMaps, Secrets, Probes. |
| **[09](09-aws-eks-production/README.md)** | **[Amazon EKS Production Deployment](09-aws-eks-production/README.md)** | `eksctl`, Managed NodeGroups, CoreDNS, Classic ELB, AWS Load Balancer Controller, cost teardown. |
| **[10](10-gitops-argocd/README.md)** | **[GitOps Continuous Delivery with ArgoCD](10-gitops-argocd/README.md)** | Declarative CD, ArgoCD CRD, Auto-sync, Self-healing, initial admin secret, port-forwarding. |
| **[11](11-cicd-github-actions/README.md)** | **[GitHub Actions CI/CD Automation](11-cicd-github-actions/README.md)** | Multi-tier pipelines, GitHub Secrets, ECR push, auto-committing manifest tags to git repo. |
| **[12](12-production-troubleshooting/README.md)** | **[Production Troubleshooting & War Stories](12-production-troubleshooting/README.md)** | Next.js standalone DNS rewrites, shallow probes, CrashLoopBackOff, CoreDNS split-horizon. |

---

## 🏛️ High-Level Production Architecture

```mermaid
graph TD
    User([🌐 End User / Web Browser])

    subgraph AWS_Cloud ["AWS Cloud (us-east-1)"]
        subgraph VPC ["Custom Multi-AZ VPC (10.0.0.0/16)"]
            
            subgraph Public_Subnets ["Public Subnets (us-east-1a, us-east-1b)"]
                ELB["AWS Classic Load Balancer (Port 80)"]
                EC2_Demo["Free-Tier EC2 Demo Server (3.94.149.149:80)"]
                EKS_Workers["EKS Managed Worker Nodes (2x t3.small EC2)"]
            end

            subgraph EKS_Cluster ["Amazon EKS Cluster (smartdoc-ai namespace)"]
                Frontend_Pod["Frontend Pods (Next.js 14 Standalone :3000)"]
                Backend_Pod["Backend Pods (FastAPI Python :8000)"]
                Redis_Pod["Redis Pod (In-Memory Cache :6379)"]
            end

            subgraph Private_Subnets ["Private Subnets (Isolated - No Public IP)"]
                RDS[("Amazon RDS PostgreSQL 15<br/>smartdoc-db :5432")]
            end

        end

        S3[("Amazon S3 Bucket<br/>smartdoc-storage-zohaib-2026")]
        ECR[("Amazon ECR<br/>Image Registry")]
    end

    subgraph GitOps_CI_CD ["DevOps CI/CD & GitOps Automation"]
        GitHub["GitHub Repository (smartdoc-ai)"]
        GHA["GitHub Actions CI/CD Runner"]
        ArgoCD["ArgoCD GitOps Controller (localhost:8081)"]
    end

    User -->|HTTP Port 80| ELB
    User -->|HTTP Port 80| EC2_Demo
    ELB -->|NodePort :32617| Frontend_Pod
    Frontend_Pod -->|Internal ClusterIP DNS :8000| Backend_Pod
    Backend_Pod -->|ClusterIP :6379| Redis_Pod
    Backend_Pod -->|Private Subnet :5432 / SG Chained| RDS
    Backend_Pod -->|IAM / Boto3 Streaming| S3

    GitHub -->|git push trigger| GHA
    GHA -->|Build & Push Docker Images| ECR
    GHA -->|Auto-commit Image Tag SHAs| GitHub
    ArgoCD -->|Reconciliation Loop| GitHub
    ArgoCD -->|Declarative Sync & Self-Healing| EKS_Cluster
```

---

## 🏷️ Terminal Command Tagging Standard

To prevent environment confusion, commands across all chapters are explicitly labeled with one of the following tags:

- 💻 **`[Local Laptop Terminal]`** — Commands executed on your local development machine (macOS / Linux / Windows WSL).
- ☁️ **`[Ubuntu EC2 / Cloud VM Terminal]`** — Commands executed directly on a remote Ubuntu cloud server via SSH.
- ☸️ **`[Kubernetes / EKS Terminal]`** — Cluster orchestration commands executed using `kubectl` or `eksctl`.

---

## 🚀 How to Use This Playbook

1. **For Beginners:** Follow the modules sequentially from `01` to `12`.
2. **For Cloud Deployments:** Jump directly to `03-aws-core-networking-vpc` through `09-aws-eks-production`.
3. **For Job Interviews:** Review `12-production-troubleshooting` and the architecture sections in each chapter for battle-tested talking points.
