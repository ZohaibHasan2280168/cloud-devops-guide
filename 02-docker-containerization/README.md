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
