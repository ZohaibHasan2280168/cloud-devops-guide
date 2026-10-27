# 02 — Docker & Multi-Stage Containerization

Containers package application code, system libraries, and runtime dependencies into immutable images, ensuring parity across local workstations, staging environments, and production Kubernetes clusters.

---

## 1. Core Architecture & Concepts

1. **Virtual Machines vs Containers:**
   - **VMs:** Emulate full hardware with hypervisors (Type 1/Type 2) and run a complete guest OS kernel (heavy, gigabytes, slow boot).
   - **Containers:** Share the host Linux kernel while isolating processes using Linux kernel **cgroups** (resource limits) and **namespaces** (PID, NET, IPC, MNT, UTS).
2. **Layer Caching:** Dockerfiles execute from top to bottom. Each instruction (`FROM`, `COPY`, `RUN`) creates an immutable layer. Optimize cache by placing slow-changing layers (e.g. `package.json`, `requirements.txt`) before application code.
3. **Multi-Stage Builds:** Separate build dependencies (Node.js SDK, Python compilers, headers) from the lean production runtime image, reducing image sizes by up to 90%.

---

## 2. Production Multi-Stage Dockerfile Example

### Next.js 14 Standalone Production Dockerfile
```dockerfile
# Stage 1: Dependency installation
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: Source build
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 3: Minimal production runtime (Scratch/Alpine)
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Security: Run as non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

---

## 3. Docker CLI Command Master Reference

### A. Image Management

```bash
# 💻 [Local Laptop Terminal] or ☁️ [Ubuntu EC2 Terminal]
# Build an image with a specific tag
docker build -t myapp:1.0.0 .

# Build without cache (force rebuild)
docker build --no-cache -t myapp:latest .

# List all local images
docker images

# Tag an image for AWS ECR or Docker Hub
docker tag myapp:latest 479537131188.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# Remove an image
docker rmi myapp:1.0.0

# Prune unused dangling images
docker image prune -f
```

---

### B. Container Execution & Lifecycle

```bash
# 💻 [Local Laptop Terminal] or ☁️ [Ubuntu EC2 Terminal]
# Run container in background (-d) with port forwarding (-p) and restart policy
docker run -d \
  --name web-app \
  -p 80:3000 \
  -e NODE_ENV=production \
  --restart always \
  myapp:latest

# List running containers
docker ps

# List ALL containers (including stopped/crashed)
docker ps -a

# View container logs live with timestamps
docker logs -f --tail 100 -t web-app

# Execute interactive shell inside running container
docker exec -it web-app /bin/sh

# Stop and remove containers
docker stop web-app
docker start web-app
docker restart web-app
docker rm -f web-app

# Real-time resource usage statistics (CPU, Memory, Network I/O)
docker stats
```

---

### C. Docker Networks & Volumes

```bash
# 💻 [Local Laptop Terminal] or ☁️ [Ubuntu EC2 Terminal]
# Create a dedicated bridge network
docker network create smartdoc-net

# Connect container to network
docker network connect smartdoc-net web-app

# Inspect network and connected IPs
docker network inspect smartdoc-net

# Create a persistent named volume
docker volume create pgdata

# Run PostgreSQL with persistent volume mount
docker run -d \
  --name postgres-db \
  --network smartdoc-net \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:15-alpine

# Prune unused volumes (caution: removes unattached data)
docker volume prune -f
```

---

## 4. Docker Compose Orchestration

Docker Compose manages multi-container application topologies declaratively.

### `docker-compose.yml`
```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: smartdoc-backend
    restart: always
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/smartdoc
      - REDIS_URL=redis://redis:6379
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - app-network

  postgres:
    image: postgres:15-alpine
    container_name: smartdoc-postgres
    restart: always
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: smartdoc
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d smartdoc"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    container_name: smartdoc-redis
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### Essential Docker Compose Commands

```bash
# ☁️ [Ubuntu EC2 Terminal] or 💻 [Local Laptop Terminal]
# Start all services in the background and build if images missing
docker compose up -d

# Rebuild containers before starting
docker compose up -d --build

# View logs for a specific service
docker compose logs -f backend

# Check status of running compose services
docker compose ps

# Stop and remove all containers, networks (preserve volumes)
docker compose down

# Stop and wipe ALL containers, networks, AND volumes (fresh start)
docker compose down -v
```

---

## 5. SRE Container Diagnostics, IP Discovery & Networking Deep Dive

In enterprise DevOps and SRE operations, engineers must rapidly inspect container network namespaces, diagnose health probes, and track down IP addresses across multi-container topologies.

---

### A. Quick Container IP Discovery (Day-to-Day Shortcuts)

#### Method 1: The Quickest 2-Word Inspection (Recommended)
```bash
# Grep for IP address directly from container inspect metadata:
docker inspect <container_name> | grep IPAddress

# Examples:
docker inspect zohaib_portfolio_prod | grep IPAddress
docker inspect smartdoc-backend | grep IPAddress
```

#### Method 2: Inspect Entire Project Network (See All IPs at Once)
```bash
# List all active Docker networks:
docker network ls

# Inspect a specific project bridge network (shows all connected containers & IPs):
docker network inspect portfolio_default
docker network inspect smartdoc-ai_smartdoc-network
```

#### Method 3: SRE 1-Word Terminal Alias (`dip`)
Add this permanent alias to your `~/.bashrc` to query any container IP in milliseconds:
```bash
# Add to ~/.bashrc:
alias dip='docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'

# Usage:
dip zohaib_portfolio_prod   # Output: 172.18.0.2
dip smartdoc-backend        # Output: 172.20.0.4
dip smartdoc-frontend       # Output: 172.20.0.2
```

---

### B. SRE Master Fleet Diagnostic Dashboard (All Containers + IPs + Health)

Run this one-liner in your terminal to generate an instant, formatted audit table of every running container, its internal IP, and its Docker Healthcheck status:

```bash
docker ps --format '{{.Names}}' | while read name; do
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$name" | xargs)
  status=$(docker inspect -f '{{.State.Status}} ({{if .State.Health}}{{.State.Health.Status}}{{else}}no-probe{{end}})' "$name")
  printf "%-30s | %-20s | %s\n" "$name" "$ip" "$status"
done
```

**Sample Output:**
```text
CONTAINER NAME                 | IP ADDRESS           | HEALTH STATUS
-------------------------------+----------------------+---------------------
zohaib_portfolio_prod          | 172.18.0.2           | running (healthy)
smartdoc-frontend              | 172.20.0.2           | running (healthy)
smartdoc-backend               | 172.20.0.4           | running (healthy)
smartdoc-postgres              | 172.20.0.5           | running (healthy)
smartdoc-redis                 | 172.20.0.3           | running (healthy)
go-devops-mongo                | 172.17.0.2           | running (no-probe)
smartdoc-jenkins               | 172.17.0.3           | running (no-probe)
```

---

### C. Host Network vs Container Bridge Network (`hostname -i` vs `hostname -I`)

Understanding where an IP originates is critical for routing and firewall administration:

| Command | Output Example | Explanation & Scope |
| :--- | :--- | :--- |
| **`hostname -i`** *(lowercase)* | `127.0.1.1` | **Loopback / Hostname resolution:** Resolves the local machine name from `/etc/hosts`. |
| **`hostname -I`** *(uppercase)* | `192.168.1.7 172.18.0.1 172.20.0.1 192.168.49.1` | **All Network Interfaces:** Shows Host Wi-Fi IP (`192.168.1.x`), Docker bridge gateways (`172.x.x.1`), and Minikube virtual adapter (`192.168.49.1`). |

---

### D. Health Check Probing: Internal vs External (`curl` vs `wget`, `-i` vs `-I`)

#### 1. Internal Container Health Probe (via `wget`):
Lightweight images like `nginx:alpine-slim` do not include `curl` to preserve a ~25MB image footprint. Health checks inside the container use built-in BusyBox `wget`:
```bash
docker exec -it zohaib_portfolio_prod wget -qO- http://127.0.0.1:80/health
# Output: healthy
```

#### 2. External Health Probe (via Host `curl`):
From your host terminal, query the forwarded port (`3002:80`) or direct internal IP:
```bash
# Query via mapped host port:
curl http://localhost:3002/health

# Query via direct container IP (Port 80):
curl http://172.18.0.2:80/health
```

#### 3. Difference Between `curl -i` and `curl -I`:
* **`curl -I <url>` (HEAD request):** Fetches **ONLY the HTTP response headers** (`200 OK`, `Content-Type`, `Server`). Ideal for automated monitoring scripts because it consumes zero bandwidth downloading page bodies.
* **`curl -i <url>` (GET request):** Fetches the **HTTP response headers PLUS the entire response body** (HTML, JSON, data).

---

### E. Why Containers Have Isolated Private IPs (No Port Conflicts)

#### ❓ The Problem Without Network Namespaces:
If three microservices (`portfolio`, `smartdoc-frontend`, `godevops`) all attempted to bind to port `80` on the host laptop directly:
```text
Port 80 Conflict: Only the first container starts; all subsequent containers crash with:
"Bind for 0.0.0.0:80 failed: port is already allocated"
```

#### 🛡️ The Docker Solution:
Docker assigns every container its own dedicated virtual network interface and private IP (`172.18.0.2`, `172.20.0.2`):
1. **Internal Freedom:** Every container can freely bind to standard port `80` inside its private network without conflict.
2. **Port Mapping Bridge (`3002:80`, `3000:80`):** The host maps distinct external ports to individual container private IPs, enabling hundreds of microservices to run simultaneously on a single host.

---

### F. Host Port Conflict & Interface Troubleshooting (`ip -br a`, `ss -tuln`, `lsof -i`)

Before binding a container to host ports (e.g. `-p 3002:80`), SREs diagnose listening sockets and existing bindings:

#### 1. `ip -br a` (Brief 1-Line Interface & IP Overview):
Modern replacement for `ifconfig`. Displays a concise summary of all physical, Docker, and Minikube interfaces, their UP/DOWN state, and assigned IP/CIDR:
```bash
ip -br a

# Sample Output:
# lo               UNKNOWN        127.0.0.1/8 ::1/128 
# wlan0            UP             192.168.1.7/24 
# docker0          DOWN           172.17.0.1/16 
# br-f04d82b57cf2  UP             172.18.0.1/16 
# minikube         UP             192.168.49.1/24 
```

#### 2. `sudo ss -tuln` (Socket Statistics):
Instantly checks which ports are actively listening on the host:
* `-t`: TCP sockets
* `-u`: UDP sockets
* `-l`: Listening state only
* `-n`: Numeric port numbers (e.g. `:3002` instead of service names)
```bash
sudo ss -tuln

# Look for: 0.0.0.0:3002 or [::]:3002
```

#### 3. `sudo lsof -i :3002` (Locate Exact Process Locking a Port):
If Docker fails with `"port is already allocated"`, use `lsof` to find the exact process name and PID holding the port:
```bash
sudo lsof -i :3002

# Sample Output:
# COMMAND      PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
# docker-pr 941020 root    4u  IPv6 793140      0t0  TCP *:3002 (LISTEN)
```
*(If a rogue process is holding your port, terminate it using: `sudo kill -9 <PID>`)*


