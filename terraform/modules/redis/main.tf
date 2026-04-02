# Memorystore (Redis) Module
# Provisions a managed Redis instance accessible only within the VPC.
#
# Why Redis for flash sales:
# 1. Inventory caching: 100K ops/sec vs MySQL's ~1K. DB would crash under flash sale load.
# 2. Rate limiting: INCR + EXPIRE tracks requests per IP per second atomically.
# 3. Atomic ops: Lua scripts prevent overselling - GET+DECR in one uninterruptible operation.

resource "google_redis_instance" "main" {
  name           = "flash-sale-redis-${var.environment}"
  tier           = "BASIC" # STANDARD_HA for prod (has automatic failover)
  memory_size_gb = var.memory_size_gb
  region         = var.region

  authorized_network = var.vpc_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_version = "REDIS_7_0"

  redis_configs = {
    maxmemory-policy = "allkeys-lru" # Evict least-recently-used keys when memory is full
  }

  labels = {
    environment = var.environment
  }
}
