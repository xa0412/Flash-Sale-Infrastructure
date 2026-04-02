from redis_client import redis_client
from sqlalchemy.orm import Session

# Lua script: atomically decrement stock if > 0
# Returns 1 on success (stock decremented), 0 if sold out
DECR_IF_POSITIVE = """
local stock = redis.call('GET', KEYS[1])
if stock == false then
    return -1
end
if tonumber(stock) > 0 then
    redis.call('DECR', KEYS[1])
    return 1
else
    return 0
end
"""

_decr_script = redis_client.register_script(DECR_IF_POSITIVE)


def inventory_key(sale_id: int) -> str:
    return f"inventory:{sale_id}"


def load_inventory(sale_id: int, stock: int):
    """Load initial stock into Redis when a flash sale starts."""
    redis_client.set(inventory_key(sale_id), stock)


def get_stock(sale_id: int) -> int:
    """Get current stock from Redis. Returns -1 if key doesn't exist."""
    val = redis_client.get(inventory_key(sale_id))
    return int(val) if val is not None else -1


def try_decrement(sale_id: int) -> int:
    """
    Atomically decrement inventory if stock > 0.
    Returns: 1 = success, 0 = sold out, -1 = sale not initialized
    """
    return _decr_script(keys=[inventory_key(sale_id)])


def restore_stock(sale_id: int):
    """Compensating transaction: restore stock if order creation fails."""
    redis_client.incr(inventory_key(sale_id))


def reconcile_from_mysql(db: Session):
    """
    On startup: recalculate Redis stock from MySQL for all active sales.
    Fixes oversell risk if Redis crashed mid-sale.
    Formula: remaining = total_stock - confirmed orders
    """
    from models import FlashSale, Order
    from sqlalchemy import func

    active_sales = db.query(FlashSale).filter(FlashSale.status == "active").all()

    for sale in active_sales:
        orders_placed = (
            db.query(func.count(Order.id))
            .filter(Order.sale_id == sale.id, Order.status == "confirmed")
            .scalar()
        )
        remaining = max(sale.total_stock - orders_placed, 0)
        redis_client.set(inventory_key(sale.id), remaining)

    return len(active_sales)
