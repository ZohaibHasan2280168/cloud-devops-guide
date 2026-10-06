# 05 — Amazon RDS PostgreSQL Architecture

Amazon Relational Database Service (RDS) is a fully managed database service that automates provisioning, hardware scaling, OS patching, automated daily backups, and Multi-AZ failover.

---

## 1. Managed RDS vs Self-Hosted Database Comparison

| Feature | Self-Hosted in EC2 | Amazon RDS (PostgreSQL) |
| :--- | :--- | :--- |
| **Backups** | Manual cron scripts, S3 upload scripts | Automated daily snapshots + Point-in-Time Recovery |
| **High Availability** | Manual replication & failover scripting | One-click Multi-AZ synchronous standby |
| **OS & Security Patching**| Manual `apt upgrade` downtime | Automated maintenance windows |
| **Storage Scaling** | Manual LVM / EBS volume resizing | Storage Auto-Scaling without downtime |
| **Isolation** | Needs manual firewall management | Enforces VPC DB Subnet Groups & Private Subnets |

---

## 2. DB Subnet Group Architecture

Amazon RDS requires a **DB Subnet Group** spanning at least two Availability Zones (e.g. `us-east-1a` and `us-east-1b`) in the chosen VPC, ensuring that failovers can automatically spin up standby instances in an alternate data center.

```bash
# 💻 [Local Laptop Terminal]
# Create DB Subnet Group using our private subnets
aws rds create-db-subnet-group \
  --db-subnet-group-name smartdoc-db-subnet-group \
  --db-subnet-group-description "Private subnet group for smartdoc database" \
  --subnet-ids "$PRIV_SUB1" "$PRIV_SUB2"
```

---

## 3. Provisioning RDS PostgreSQL via AWS CLI

```bash
# 💻 [Local Laptop Terminal]
# Provision a PostgreSQL 15 instance on db.t3.micro (Free-Tier eligible)
aws rds create-db-instance \
  --db-instance-identifier smartdoc-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.7 \
  --master-username postgres \
  --master-user-password "YourStrongPassword123!" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --vpc-security-group-ids $RDS_SG \
  --db-subnet-group-name smartdoc-db-subnet-group \
  --no-publicly-accessible \
  --backup-retention-period 7 \
  --tags Key=Environment,Value=Production

echo "Provisioning RDS instance... this takes ~5-8 minutes."
```

---

## 4. Retrieving Endpoint & Testing Connectivity

```bash
# 💻 [Local Laptop Terminal]
# Wait until DB Instance Status is 'available'
aws rds wait db-instance-available --db-instance-identifier smartdoc-db

# Extract DB Endpoint Address
DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier smartdoc-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "PostgreSQL Endpoint: $DB_HOST"
```

### Testing Connection from EC2 Demo Server:
Because RDS is inside private subnets, you must connect from within the VPC (e.g., from the EC2 demo instance whose Security Group was chained):

```bash
# ☁️ [Ubuntu EC2 / Cloud VM Terminal]
# Install PostgreSQL client utilities
sudo apt install -y postgresql-client

# Connect using psql CLI
psql -h $DB_HOST -U postgres -d postgres -W

# Verify connection inside psql shell:
SELECT version();
\l
\q
```

---

## 5. Application Integration (SQLAlchemy / Alembic)

FastAPI connects to PostgreSQL using the standard connection URI:

```ini
DATABASE_URL=postgresql://postgres:YourStrongPassword123!@smartdoc-db.cu7qimoo0rm4.us-east-1.rds.amazonaws.com:5432/smartdoc
```

### Table Schema for SmartDoc AI
```sql
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(512),
    file_size_bytes BIGINT,
    mime_type VARCHAR(100),
    summary_preview TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    char_count INTEGER
);
```

---

## 6. Cost Optimization & Teardown

```bash
# 💻 [Local Laptop Terminal]
# Stop RDS temporarily when not actively developing (stops compute billing for 7 days)
aws rds stop-db-instance --db-instance-identifier smartdoc-db

# Delete RDS instance permanently without final snapshot (cost saving)
aws rds delete-db-instance \
  --db-instance-identifier smartdoc-db \
  --skip-final-snapshot \
  --delete-automated-backups
```
