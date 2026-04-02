"""
Unit tests for the core flash sale logic (inventory + rate limiting).
These tests mock Redis and MySQL so no running services are required.
"""
import pytest
from unittest.mock import patch, MagicMock


class TestRateLimiter:
    def test_allows_request_under_limit(self):
        with patch("services.rate_limiter.redis_client") as mock_redis:
            mock_redis.incr.return_value = 1
            from services.rate_limiter import is_rate_limited
            assert is_rate_limited("user_1") is False

    def test_blocks_request_over_limit(self):
        with patch("services.rate_limiter.redis_client") as mock_redis:
            mock_redis.incr.return_value = 11  # Over limit of 10
            from services.rate_limiter import is_rate_limited
            assert is_rate_limited("user_1") is True

    def test_sets_ttl_on_first_request(self):
        with patch("services.rate_limiter.redis_client") as mock_redis:
            mock_redis.incr.return_value = 1
            from services.rate_limiter import is_rate_limited
            is_rate_limited("user_1")
            mock_redis.expire.assert_called_once_with("rate_limit:user_1", 1)


class TestInventoryService:
    def test_get_stock_returns_value(self):
        with patch("services.inventory.redis_client") as mock_redis:
            mock_redis.get.return_value = "500"
            from services.inventory import get_stock
            assert get_stock(1) == 500

    def test_get_stock_returns_minus_one_when_missing(self):
        with patch("services.inventory.redis_client") as mock_redis:
            mock_redis.get.return_value = None
            from services.inventory import get_stock
            assert get_stock(1) == -1

    def test_restore_stock_increments_redis(self):
        with patch("services.inventory.redis_client") as mock_redis:
            from services.inventory import restore_stock
            restore_stock(1)
            mock_redis.incr.assert_called_once_with("inventory:1")

    def test_load_inventory_sets_redis_key(self):
        with patch("services.inventory.redis_client") as mock_redis:
            from services.inventory import load_inventory
            load_inventory(1, 1000)
            mock_redis.set.assert_called_once_with("inventory:1", 1000)
