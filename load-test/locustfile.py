"""
Flash Sale Load Test
====================
Simulates concurrent users during a flash sale event.

Run:
    pip install locust
    locust -f locustfile.py --host=http://localhost:8000

Then open http://localhost:8089 to start the test.

Recommended settings for flash sale simulation:
  - Users: 200
  - Spawn rate: 20/second
  - Duration: 3 minutes
"""

from locust import HttpUser, task, between, events
import random
import logging

SALE_ID = 1  # Must match an initialized flash sale


class FlashSaleUser(HttpUser):
    # Wait 100-500ms between requests (aggressive, simulates flash sale rush)
    wait_time = between(0.1, 0.5)

    def on_start(self):
        """Called when a simulated user starts."""
        self.user_id = f"user_{random.randint(1, 100000)}"

    @task(1)
    def check_stock(self):
        """Check current stock (read-heavy operation, hits Redis)."""
        with self.client.get(
            f"/api/v1/flash-sale/{SALE_ID}/stock",
            name="/api/v1/flash-sale/[id]/stock",
            catch_response=True,
        ) as response:
            if response.status_code == 404:
                response.failure("Sale not initialized - run /api/v1/flash-sale/init first")

    @task(3)
    def purchase(self):
        """Attempt to purchase (the critical path: rate limit -> Redis Lua -> MySQL)."""
        with self.client.post(
            f"/api/v1/flash-sale/{SALE_ID}/purchase",
            name="/api/v1/flash-sale/[id]/purchase",
            json={"user_id": self.user_id, "quantity": 1},
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 409:
                # Sold out - expected, not a failure
                response.success()
            elif response.status_code == 429:
                # Rate limited - expected, not a failure
                response.success()
            else:
                response.failure(f"Unexpected status: {response.status_code}")

    @task(1)
    def list_products(self):
        """Browse products (background traffic)."""
        self.client.get("/api/v1/products", name="/api/v1/products")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    logging.info("Load test starting. Make sure flash sale is initialized:")
    logging.info("POST /api/v1/flash-sale/init with total_stock=1000")
