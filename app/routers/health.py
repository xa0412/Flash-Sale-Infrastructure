from fastapi import APIRouter
from database import engine
from redis_client import redis_client
from sqlalchemy import text

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/live")
def liveness():
    """Liveness probe: is the process running?"""
    return {"status": "ok"}


@router.get("/ready")
def readiness():
    """Readiness probe: can we handle traffic (DB + Redis reachable)?"""
    errors = []

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as e:
        errors.append(f"mysql: {e}")

    try:
        redis_client.ping()
    except Exception as e:
        errors.append(f"redis: {e}")

    if errors:
        return {"status": "not ready", "errors": errors}
    return {"status": "ok", "mysql": "connected", "redis": "connected"}
