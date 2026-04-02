from redis_client import redis_client
from config import settings


def is_rate_limited(identifier: str) -> bool:
    """
    Sliding window rate limiter using Redis.
    Allows up to RATE_LIMIT_PER_SECOND requests per second per identifier.
    """
    key = f"rate_limit:{identifier}"
    count = redis_client.incr(key)
    if count == 1:
        # First request in this window, set 1 second TTL
        redis_client.expire(key, 1)
    return count > settings.rate_limit_per_second
