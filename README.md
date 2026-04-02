# Flash Sale Infrastructure

A production-grade flash sale system demonstrating DevOps and distributed systems skills. Built with Kubernetes, Redis atomic operations, Prometheus/Grafana observability, and GitHub Actions CI/CD.

**Cost: $0** — runs entirely on Docker Compose + Minikube locally. Terraform modules are written and validated for GCP but not deployed.

---

## Architecture

```
         +-------------------+
         |   GitHub Actions  |
         | CI: lint+test+scan|
         | CD: build+push    |
         +---------+---------+
                   |
                   v
+------------------------------------------+
|          Minikube (local K8s)             |
|                                          |
|  +----------+  +----------+    (HPA)     |
|  | Pod 1    |  | Pod 2    |  auto-scale  |
|  | FastAPI  |  | FastAPI  |  1-4 pods    |
|  +----+-----+  +----+-----+             |
|       |              |                   |
|  +----v--------------v----+              |
|  |  Service (LoadBalancer) |             |
|  +-------------------------+             |
|       |              |                   |
|  +----v----+   +-----v-----+            |
|  |  MySQL  |   |   Redis   |            |
|  +---------+   +-----------+            |
|                                          |
|  +------------------+                    |
|  | Prometheus:9090  |                    |
|  | Grafana:3000     |                    |
|  +------------------+                    |
+------------------------------------------+

Terraform modules (GCP-ready, validated locally):
  vpc/ | gke/ | cloudsql/ | redis/ | monitoring/
```

---

## What This Demonstrates

| Skill | How |
|-------|-----|
| **Infrastructure as Code** | Modular Terraform (VPC, GKE, Cloud SQL, Redis, Monitoring) |
| **Container Orchestration** | Kubernetes Deployments, HPA autoscaling, health probes, Kustomize |
| **Distributed Systems** | Redis Lua scripts for atomic inventory, rate limiting, crash recovery |
| **Observability** | Prometheus custom metrics, Grafana dashboards |
| **CI/CD** | GitHub Actions: lint → test → docker build → trivy scan → push |
| **Load Testing** | Locust simulating 200 concurrent flash sale users, 0 failures |

---

## Tech Stack

| Tool | Why |
|------|-----|
| **FastAPI** | Async Python, auto OpenAPI docs, high concurrency |
| **Redis** | 100K ops/sec for inventory. Lua scripts prevent overselling |
| **MySQL** | Durable order storage with ACID guarantees |
| **Kubernetes** | Auto-scaling, self-healing, rolling deployments |
| **Docker Compose** | One-command local development environment |
| **Prometheus + Grafana** | Real-time metrics and dashboards |
| **Terraform** | Version-controlled, reproducible cloud infrastructure |
| **GitHub Actions** | Automated testing and container builds on every commit |
| **Locust** | Load testing framework for simulating flash sale traffic |

---

## Quick Start (Docker Compose)

```bash
# Start everything: MySQL + Redis + App + Prometheus + Grafana
docker-compose up --build

# API:        http://localhost:8000
# API Docs:   http://localhost:8000/docs
# Metrics:    http://localhost:8000/metrics
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000  (admin/admin)
```

### Run a flash sale

```bash
# 1. Create a flash sale (1000 units of product #1)
curl -X POST http://localhost:8000/api/v1/flash-sale/init \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 1,
    "total_stock": 1000,
    "start_time": "2026-01-01T00:00:00",
    "end_time": "2026-12-31T23:59:59"
  }'

# 2. Check live stock (reads from Redis)
curl http://localhost:8000/api/v1/flash-sale/1/stock

# 3. Purchase
curl -X POST http://localhost:8000/api/v1/flash-sale/1/purchase \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_123"}'

# 4. View all active sales with live stock
curl http://localhost:8000/api/v1/flash-sale/

# 5. View order history for a sale
curl http://localhost:8000/api/v1/flash-sale/1/orders
```

---

## Kubernetes (Minikube)

```bash
# Start Minikube
minikube start --driver=docker

# Build image inside Minikube's Docker daemon (Windows PowerShell)
minikube docker-env | Invoke-Expression
docker build -t flash-sale-api:latest ./app

# Deploy everything
kubectl apply -k k8s/overlays/staging/

# Expose via tunnel (run in separate terminal)
minikube tunnel

# App available at http://127.0.0.1/docs

# Monitor pods and autoscaler
kubectl get pods -n flash-sale
kubectl get hpa -n flash-sale
```

---

## Load Testing

```bash
pip install locust
locust -f load-test/locustfile.py --host=http://localhost:8000
# Open http://localhost:8089
# Set 200 users, 20/second spawn rate
```

**Results**: 200 concurrent users, 0 failures, no overselling, rate limiting activated.

---

## Key Design Decisions

### 1. Redis Lua Script for Atomic Inventory
Without atomicity, two pods could both read `stock=1`, both decrement, and sell 2 items when only 1 remains (overselling). The Lua script executes as a single Redis command — no other operation can run between the GET and DECR:

```lua
local stock = redis.call('GET', KEYS[1])
if tonumber(stock) > 0 then
    redis.call('DECR', KEYS[1])
    return 1  -- success
else
    return 0  -- sold out
end
```

### 2. Redis Crash Recovery
If Redis crashes mid-sale, stock resets to 0 — but MySQL still has the order history. On every startup, the app reconciles Redis stock from MySQL:

```
remaining = total_stock - confirmed_orders
redis.set("inventory:{sale_id}", remaining)
```

This prevents overselling after a Redis restart.

### 3. Asymmetric HPA Scaling
Scale UP aggressively (30s window) — users are waiting.
Scale DOWN slowly (300s window) — next spike might come in 2 minutes.

### 4. Three Health Probes
- **Liveness**: Is the process stuck? Kill and restart if yes.
- **Readiness**: Can it handle traffic? Remove from load balancer if DB is disconnected.
- **Startup**: Has it finished booting? Don't kill a slow-starting container.

### 5. Terraform for GCP (write + validate locally)
All Terraform modules are production-ready for GCP. Running `terraform validate` and `terraform fmt` in CI ensures the IaC is correct without incurring cloud costs.

---

## CI/CD Pipeline

```
PR opened:
  lint (ruff) → unit tests → docker build → trivy scan → terraform validate

Merge to main:
  build image → push to ghcr.io/xa0412/flash-sale-infrastructure
```

---

## Project Structure

```
├── app/                    # FastAPI application
│   ├── main.py             # App entrypoint, startup reconciliation, Prometheus middleware
│   ├── routers/            # API endpoints (flash_sale, products, health)
│   ├── services/           # inventory.py (Lua scripts + crash recovery), rate_limiter.py
│   ├── Dockerfile
│   └── tests/
├── k8s/                    # Kubernetes manifests (Kustomize)
│   ├── base/               # Deployment, Service, HPA, ConfigMap, MySQL, Redis
│   └── overlays/staging/   # Staging overrides
├── terraform/              # GCP Infrastructure as Code
│   ├── modules/            # vpc, gke, cloudsql, redis, monitoring
│   └── environments/staging/
├── monitoring/             # Prometheus + Grafana configs and dashboards
├── load-test/              # Locust load test
├── docker-compose.yaml     # Local dev environment
└── .github/workflows/      # CI (lint+test+scan) and CD (build+push) pipelines
```
