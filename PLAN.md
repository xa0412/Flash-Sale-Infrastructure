# Flash Sale Infrastructure - Project Plan

## Context
Resume/learning project to demonstrate production-grade DevOps skills for Cloud/DevOps job applications. Simulates a high-concurrency flash sale system (like Shopee). The goal is to learn and understand every tool in the DevOps workflow end-to-end.

**Cost: $0** - Everything runs locally using Docker Compose + Minikube. Terraform code is written and validated but not deployed to GCP.

---

## Approach: Local-First, Cloud-Ready

The Terraform modules exist to demonstrate IaC skills, but the actual running system uses free local tools:

| Concept | Cloud Version (reference) | Local Version (what we run) | Same Skill? |
|---------|--------------------------|---------------------------|-------------|
| Container orchestration | GKE | **Minikube** (local K8s) | Yes - same manifests, same kubectl |
| Relational database | Cloud SQL | **MySQL in Docker** | Yes - same SQL, same app code |
| In-memory cache | Memorystore | **Redis in Docker** | Yes - same commands, Lua scripts |
| Load balancer | GCP LB | **minikube tunnel** / port-forward | Yes - same Service concept |
| Container registry | Artifact Registry | **Local Docker images** | Yes - same Dockerfile |
| Monitoring | GCP Cloud Monitoring | **Prometheus + Grafana in Docker** | Yes - identical (they're open source) |
| CI/CD | GitHub Actions | **GitHub Actions** (free for public repos) | Yes - identical |
| IaC | Terraform apply to GCP | **Terraform validate + plan** (no apply) | Mostly - shows you can write production IaC |

---

## Tools & Skills Overview

| Tool | What It Is | Problem It Solves Here |
|------|-----------|----------------------|
| **Terraform** | Infrastructure as Code - define cloud resources in declarative config files | Reproducible, version-controlled infra. Write once, deploy anywhere. Shows you understand production IaC |
| **Minikube** | Local single-node Kubernetes cluster | Run K8s on your laptop for free. Same kubectl, same manifests as real GKE |
| **Docker / Docker Compose** | Container packaging + multi-container orchestration | Bundle app + dependencies into portable images. Compose runs MySQL, Redis, app together locally |
| **Kubernetes** | Container orchestration platform | Auto-scaling, self-healing, rolling deployments. Flash sales need rapid scaling |
| **MySQL** | Relational database | Durable storage for products, orders, flash sale records |
| **Redis** | In-memory key-value store (sub-millisecond latency) | Inventory caching (100K ops/sec), rate limiting, atomic Lua scripts to prevent overselling |
| **FastAPI** | Async Python web framework | High-concurrency API with auto-generated OpenAPI docs and type validation |
| **Kustomize** | K8s manifest customization without templating | Base manifests + environment overlays. No YAML duplication |
| **Prometheus** | Time-series metrics database - scrapes `/metrics` endpoints | Answers "how many req/sec?", "what's P99 latency?", "is Redis full?" |
| **Grafana** | Dashboard visualization for Prometheus metrics | Real-time graphs showing autoscaling, latency, errors during flash sale |
| **GitHub Actions** | CI/CD automation triggered by git events | PR triggers tests. Merge triggers build + deploy. No manual deployment |
| **Locust** | Python-based load testing framework | Simulates 500 concurrent users proving autoscaling and rate limiting work |

---

## Final Repository Structure

```
Flash Sale Infrastructure/
├── terraform/                    # IaC (validate + plan, shows production knowledge)
│   ├── modules/
│   │   ├── vpc/                  # (DONE) Network foundation
│   │   ├── gke/                  # GKE cluster definition
│   │   ├── cloudsql/             # Cloud SQL (MySQL) definition
│   │   ├── redis/                # Memorystore (Redis) definition
│   │   └── monitoring/           # GCP alert policies
│   └── environments/
│       └── staging/              # (PARTIAL) Environment config
├── app/                          # Flash sale FastAPI application
│   ├── main.py
│   ├── config.py
│   ├── models.py
│   ├── schemas.py
│   ├── database.py
│   ├── redis_client.py
│   ├── routers/
│   │   ├── health.py
│   │   ├── products.py
│   │   └── flash_sale.py
│   ├── services/
│   │   ├── inventory.py          # Redis Lua scripts for atomic inventory
│   │   └── rate_limiter.py       # Sliding window rate limiter
│   ├── Dockerfile
│   ├── requirements.txt
│   └── tests/
├── k8s/                          # Kubernetes manifests (Kustomize)
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── configmap.yaml
│   └── overlays/
│       └── staging/
├── monitoring/                   # Prometheus + Grafana configs
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       └── dashboards/
├── load-test/                    # Locust load tests
│   └── locustfile.py
├── docker-compose.yaml           # Local dev: MySQL + Redis + App + Prometheus + Grafana
├── .github/
│   └── workflows/
│       ├── ci.yaml               # Lint, test, build, Terraform validate
│       └── cd.yaml               # Build image, deploy to Minikube (or K8s)
├── PLAN.md                       # This file
└── README.md
```

---

## Phase 1: Docker Compose + Local Dev Environment (2 days)

**What**: Set up the local development stack so everything runs with one command.

**`docker-compose.yaml`** will define:
- **MySQL 8.0** container (port 3306) with initialization SQL script
- **Redis 7** container (port 6379)
- **FastAPI app** container (port 8000) - added in Phase 3
- **Prometheus** container (port 9090) - added in Phase 5
- **Grafana** container (port 3000) - added in Phase 5

**What you learn**:
- Docker Compose for multi-container apps
- Container networking (services talk by container name)
- Volume mounts for data persistence
- Environment variable configuration

**Deliverable**: `docker-compose up` starts MySQL + Redis, ready for the app.

---

## Phase 2: Terraform Modules (4 days)

**What**: Write all Terraform modules. Validate with `terraform validate` and `terraform fmt`. Run `terraform plan` if you have GCP credentials (costs nothing, creates nothing).

**Why still write Terraform if we don't deploy?**: Employers look at your GitHub. Seeing well-structured Terraform modules with proper variables, outputs, and documentation shows you understand production IaC. You can explain "I designed this for GCP deployment but ran the system locally for cost reasons" - that's a mature engineering decision.

### Module: GKE (`terraform/modules/gke/`)
**Key resources**:
- `google_container_cluster` - Private cluster, VPC-native, Workload Identity
- `google_container_node_pool` - e2-medium Spot nodes, autoscaling 1-3

### Module: Cloud SQL (`terraform/modules/cloudsql/`)
**Key resources**:
- `google_compute_global_address` + `google_service_networking_connection` (VPC peering)
- `google_sql_database_instance` - MySQL 8.0, private IP only, automated backups
- `google_sql_database` + `google_sql_user`

### Module: Redis (`terraform/modules/redis/`)
**Key resources**:
- `google_redis_instance` - Basic tier, 1GB, Redis 7.0, private network

### Module: Monitoring (`terraform/modules/monitoring/`)
**Key resources**:
- `google_monitoring_alert_policy` - CPU, memory, pod restart alerts
- `google_monitoring_uptime_check`

**Wire into staging**: Update `terraform/environments/staging/main.tf` to call all modules.

**Deliverable**: All modules pass `terraform validate` and `terraform fmt -check`.

---

## Phase 3: Flash Sale Application (8 days)

**What**: Python/FastAPI app - the core of the project.

### API Endpoints
```
GET  /health/live            -> Always 200 (liveness probe)
GET  /health/ready           -> Checks DB + Redis connectivity (readiness probe)
GET  /api/v1/products        -> List all products
GET  /api/v1/products/{id}   -> Get product detail
POST /api/v1/products        -> Create product (admin)

POST /api/v1/flash-sale/init            -> Initialize flash sale (load inventory into Redis)
GET  /api/v1/flash-sale/{id}/stock      -> Real-time stock count (reads from Redis)
POST /api/v1/flash-sale/{id}/purchase   -> Attempt purchase (THE critical endpoint)
```

### The Purchase Flow (centerpiece of the project)

**Step 1 - Rate Limiting (Redis)**:
```
Check: Has this IP exceeded 10 requests/second?
  Yes -> 429 Too Many Requests
  No  -> Continue
How: Redis INCR + EXPIRE (sliding window counter)
```

**Step 2 - Atomic Stock Decrement (Redis Lua Script)**:
```lua
-- This runs atomically in Redis - no other command can interrupt
local stock = redis.call('GET', KEYS[1])
if tonumber(stock) > 0 then
    redis.call('DECR', KEYS[1])
    return 1  -- success
else
    return 0  -- sold out
end
```
**Why Lua**: Without atomicity, two pods could both read stock=1 and both sell the last item (overselling). The Lua script makes GET+DECR one uninterruptible operation.

**Step 3 - Create Order (MySQL)**:
```
INSERT INTO orders (sale_id, user_id, status)
If MySQL fails: INCR Redis inventory back (compensating transaction)
```

**Step 4 - Return Result**:
```
200: { order_id: "...", status: "confirmed" }
409: { error: "sold_out" }
429: { error: "rate_limited", retry_after: 1 }
```

### Database Schema
```sql
products     (id, name, description, price, created_at)
flash_sales  (id, product_id, total_stock, start_time, end_time, status)
orders       (id, sale_id, user_id, quantity, status, created_at)
```

### Dockerfile
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### 12-Factor Config
All config via environment variables (DATABASE_URL, REDIS_HOST, etc.). Same image, different env vars per environment.

**Deliverable**: App runs in Docker Compose, purchase endpoint works with rate limiting + atomic inventory, unit tests pass.

---

## Phase 4: Kubernetes Manifests (5 days)

**What**: K8s resource definitions using Kustomize, deployed to Minikube.

### Prerequisites
- Install Minikube: `minikube start --driver=docker`
- Install kubectl (comes with Minikube)

### Resources

**Deployment** (`k8s/base/deployment.yaml`):
- 2 replicas of the Flash Sale API
- Resource requests (100m CPU, 128Mi RAM) and limits (500m CPU, 256Mi RAM)
- 3 health probes:
  - **Liveness** (`/health/live`): Is the process stuck? Kill and restart if yes
  - **Readiness** (`/health/ready`): Can it handle traffic? Remove from load balancer if no
  - **Startup** (`/health/live`): Has it finished booting? Don't kill slow starters

**Service** (`k8s/base/service.yaml`):
- Type: LoadBalancer (use `minikube tunnel` to get an external IP locally)
- Port 80 -> 8000

**HPA** (`k8s/base/hpa.yaml`):
- Scale 2-10 pods based on CPU utilization (target: 70%)
- Asymmetric scaling: fast scale-up (30s window), slow scale-down (300s window)
- **Why asymmetric**: Flash sales = spiky traffic. Scale up fast (users waiting). Scale down slow (next spike might be 2 minutes away)

**ConfigMap** (`k8s/base/configmap.yaml`):
- Database URL, Redis host/port, rate limit settings
- In Minikube, these point to Docker containers or in-cluster services

**Namespace** (`k8s/base/namespace.yaml`):
- `flash-sale` namespace for workload isolation

**MySQL + Redis as K8s Deployments** (for Minikube):
- Since we don't have Cloud SQL/Memorystore locally, run MySQL and Redis as K8s Deployments inside Minikube
- This also demonstrates StatefulSet or PersistentVolumeClaim usage

**Deliverable**: `kubectl apply -k k8s/overlays/staging/` deploys everything to Minikube. App accessible via `minikube tunnel`.

---

## Phase 5: Monitoring & Observability (5 days)

**What**: Prometheus + Grafana running locally (Docker Compose or in Minikube).

### Application Metrics (add to FastAPI app)

Using `prometheus_client` Python library, expose a `/metrics` endpoint:

| Metric | Type | What It Measures |
|--------|------|-----------------|
| `flash_sale_requests_total` | Counter | Total requests by endpoint + status code |
| `flash_sale_request_duration_seconds` | Histogram | Latency distribution (P50/P95/P99) |
| `flash_sale_inventory_current` | Gauge | Current stock level per flash sale |
| `flash_sale_orders_total` | Counter | Successful purchase count |
| `flash_sale_rate_limited_total` | Counter | Requests rejected by rate limiter |

### Prometheus Config (`monitoring/prometheus/prometheus.yml`)
- Scrape the Flash Sale API `/metrics` endpoint every 15s
- Scrape Minikube's kube-state-metrics for pod/node data

### Grafana Dashboards

**Dashboard 1 - Flash Sale Overview**:
- Request rate (req/sec) by endpoint
- Error rate (4xx, 5xx) percentage
- P50 / P95 / P99 latency
- Current inventory level (gauge dropping from 1000 to 0)
- Orders per minute

**Dashboard 2 - Infrastructure**:
- Pod CPU and memory usage vs limits
- HPA desired vs current replicas
- Redis memory usage
- MySQL connection count

**Dashboard 3 - Live Flash Sale Event** (for load test demos):
- Real-time inventory countdown
- Orders/second throughput
- Rate-limited requests spike

### Alerting Rules (Prometheus AlertManager)
- High error rate: >5% 5xx for 2 minutes
- High latency: P99 >2 seconds for 1 minute
- Inventory desync: Redis and MySQL inventory differ by >5

**Deliverable**: Grafana accessible at localhost:3000 with working dashboards showing live metrics.

---

## Phase 6: CI/CD Pipeline (4 days)

**What**: GitHub Actions workflows. Free for public repositories.

### Pipeline 1 - CI (`ci.yaml`)
**Triggers**: Push to any branch, PR to `main`

```
Steps:
1. Lint & Format
   - Python: ruff (lint) + black (format check)
   - Terraform: terraform fmt -check + terraform validate
   - YAML: yamllint on K8s manifests

2. Unit Tests
   - pytest with coverage report
   - Fail if coverage < 80%

3. Docker Build
   - docker build (verify it compiles)
   - Trivy vulnerability scan on the image

4. Terraform Validate
   - terraform init + validate on all modules
   - terraform fmt -check
```

### Pipeline 2 - CD (`cd.yaml`)
**Triggers**: Push to `main` (after PR merge)

```
Steps:
1. Build Docker Image
   - Tag with git SHA (e.g., flash-sale-api:abc123f)
   - Push to GitHub Container Registry (ghcr.io) - FREE

2. Update K8s Manifests
   - Update image tag in kustomization.yaml
   - Commit the change (GitOps style)
```

Note: Since we're not deploying to GCP, the CD pipeline builds and pushes the image to the free GitHub Container Registry. The K8s deployment to Minikube is done manually (`kubectl apply -k`). This still demonstrates the CI/CD concept.

**Deliverable**: PR triggers CI checks (green checkmarks), merge builds + pushes image.

---

## Phase 7: Load Testing & Validation (3 days)

**What**: Locust load test proving the system works under pressure.

### Locust Script (`load-test/locustfile.py`)
```python
class FlashSaleUser(HttpUser):
    wait_time = between(0.1, 0.5)  # Aggressive timing

    @task(1)
    def check_stock(self):
        self.client.get("/api/v1/flash-sale/1/stock")

    @task(3)
    def purchase(self):
        self.client.post("/api/v1/flash-sale/1/purchase",
                        json={"user_id": f"user_{self.user_id}"})
```

### Test Scenario
1. Initialize flash sale: 1,000 units of stock
2. Ramp from 0 to 200 concurrent users over 30s (scaled down from 500 since this is local)
3. Sustain for 3 minutes
4. Validate:
   - Exactly 1,000 orders created (no overselling, no underselling)
   - Rate limiting activated (429 responses visible in Grafana)
   - HPA attempted to scale pods (visible in Grafana)
   - P99 latency stayed reasonable
   - Zero 500 errors

### Capture Evidence
- Screenshot Grafana dashboards during the load test
- These screenshots go in the README - the most impressive part of the portfolio

**Deliverable**: Load test passes, Grafana screenshots captured showing inventory drain + autoscaling.

---

## Phase 8: Documentation & Polish (2 days)

### README.md Structure
```
# Flash Sale Infrastructure

## Architecture Diagram
## What This Project Demonstrates
## Tech Stack (with brief "why" for each choice)
## Prerequisites (Docker, Minikube, Python 3.11)
## Quick Start
  docker-compose up        # Start MySQL + Redis + App + Monitoring
  minikube start           # For K8s deployment
## API Documentation (link to /docs endpoint)
## Key Design Decisions
  - Why Redis Lua scripts for atomic inventory
  - Why Kustomize over Helm
  - Why async Python for high concurrency
  - Why this architecture handles flash sale traffic
## Load Test Results (Grafana screenshots)
## Terraform (Cloud-Ready IaC)
  - Module structure explanation
  - "Designed for GCP, validated locally"
## CI/CD Pipeline Diagram
## What I Would Add With More Time
  - Message queue (Pub/Sub) for async order processing
  - Cloud CDN for static assets
  - Multi-region deployment
  - Chaos engineering (pod failure injection)
```

**Deliverable**: Professional README with architecture diagram and load test evidence.

---

## Architecture Diagram

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
|  | FastAPI  |  | FastAPI  |              |
|  +----+-----+  +----+-----+             |
|       |              |                   |
|  +----+--------------+----+              |
|  |  Service (LoadBalancer) |             |
|  +-------------------------+             |
|       |              |                   |
|  +----v----+   +-----v-----+            |
|  |  MySQL  |   |   Redis   |            |
|  | (Pod)   |   |   (Pod)   |            |
|  +---------+   +-----------+            |
|                                          |
|  +------------------+                    |
|  | Prometheus+Grafana|                   |
|  +------------------+                    |
+------------------------------------------+

Terraform modules (validated, not deployed):
  vpc/ | gke/ | cloudsql/ | redis/ | monitoring/
  "Cloud-ready IaC - designed for GCP deployment"
```

---

## Timeline (~5 weeks, part-time ~2-3 hrs/day)

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 1. Docker Compose + Local Env | 2 days | Day 2 |
| 2. Terraform Modules | 4 days | Day 6 |
| 3. Flash Sale Application | 8 days | Day 14 |
| 4. Kubernetes Manifests | 5 days | Day 19 |
| 5. Monitoring (Prometheus+Grafana) | 5 days | Day 24 |
| 6. CI/CD (GitHub Actions) | 4 days | Day 28 |
| 7. Load Testing | 3 days | Day 31 |
| 8. Documentation | 2 days | Day 33 |

**Priority order**: Phases 1-4 are the core (working system). Phases 5-8 layer on DevOps practices. If short on time, a working app + K8s + Redis Lua scripts is already impressive.

---

## What This Proves to Employers

- **IaC**: Modular Terraform with environments, proper networking design (even if not deployed)
- **Containers**: Docker multi-stage builds, Docker Compose, container orchestration
- **Kubernetes**: Deployments, HPA, health probes, Kustomize, resource management
- **Distributed systems**: Redis atomic operations, rate limiting, cache + DB sync, race condition handling
- **Observability**: Custom Prometheus metrics, Grafana dashboards, alerting rules
- **CI/CD**: GitHub Actions with lint, test, build, scan, deploy stages
- **Load testing**: Quantified performance claims backed by Grafana evidence
- **Cost awareness**: "I designed cloud-ready IaC but ran locally - a deliberate cost optimization"
