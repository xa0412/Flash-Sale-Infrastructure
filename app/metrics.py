from prometheus_client import Counter, Histogram, Gauge

requests_total = Counter(
    "flash_sale_requests_total",
    "Total HTTP requests",
    ["endpoint", "method", "status_code"],
)

request_duration = Histogram(
    "flash_sale_request_duration_seconds",
    "HTTP request duration in seconds",
    ["endpoint"],
)

inventory_gauge = Gauge(
    "flash_sale_inventory_current",
    "Current inventory level",
    ["sale_id"],
)

orders_total = Counter(
    "flash_sale_orders_total",
    "Total confirmed orders",
    ["sale_id"],
)

rate_limited_total = Counter(
    "flash_sale_rate_limited_total",
    "Total rate-limited requests",
)
