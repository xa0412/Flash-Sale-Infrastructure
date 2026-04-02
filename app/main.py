from fastapi import FastAPI, Request
from prometheus_client import make_asgi_app
from routers import health, products, flash_sale
from metrics import requests_total, request_duration
from database import SessionLocal
from services import inventory
import time
import logging

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Flash Sale Infrastructure",
    description="High-concurrency flash sale system with Redis rate limiting and atomic inventory",
    version="1.0.0",
)


@app.on_event("startup")
def reconcile_redis_on_startup():
    """Reconcile Redis stock from MySQL on startup to prevent oversell after Redis crash."""
    db = SessionLocal()
    try:
        count = inventory.reconcile_from_mysql(db)
        logger.info(f"Startup reconciliation complete: {count} active sales synced to Redis.")
    except Exception as e:
        logger.error(f"Startup reconciliation failed: {e}")
    finally:
        db.close()

# Mount Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    endpoint = request.url.path
    requests_total.labels(
        endpoint=endpoint,
        method=request.method,
        status_code=str(response.status_code),
    ).inc()
    request_duration.labels(endpoint=endpoint).observe(duration)

    return response


app.include_router(health.router)
app.include_router(products.router)
app.include_router(flash_sale.router)


@app.get("/")
def root():
    return {
        "service": "Flash Sale API",
        "docs": "/docs",
        "metrics": "/metrics",
        "health": "/health/ready",
    }
