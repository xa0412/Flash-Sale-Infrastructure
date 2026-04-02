from fastapi import APIRouter, Depends, HTTPException, Request
from redis_client import redis_client
from sqlalchemy.orm import Session
from database import get_db
from models import FlashSale, Order
from schemas import FlashSaleCreate, FlashSaleOut, FlashSaleWithStock, OrderOut, PurchaseRequest, PurchaseResponse
from services import inventory, rate_limiter
from metrics import inventory_gauge, orders_total, rate_limited_total
from datetime import datetime

router = APIRouter(prefix="/api/v1/flash-sale", tags=["flash-sale"])


@router.get("/", response_model=list[FlashSaleWithStock])
def list_flash_sales(db: Session = Depends(get_db)):
    """List all active flash sales with real-time stock from Redis."""
    sales = db.query(FlashSale).filter(FlashSale.status == "active").all()
    result = []
    for sale in sales:
        stock = inventory.get_stock(sale.id)
        result.append(FlashSaleWithStock(
            id=sale.id,
            product_id=sale.product_id,
            total_stock=sale.total_stock,
            stock_remaining=stock if stock >= 0 else 0,
            status=sale.status,
            start_time=sale.start_time,
            end_time=sale.end_time,
        ))
    return result


@router.post("/init", response_model=FlashSaleOut)
def init_flash_sale(data: FlashSaleCreate, db: Session = Depends(get_db)):
    """Create a flash sale and load inventory into Redis."""
    sale = FlashSale(
        product_id=data.product_id,
        total_stock=data.total_stock,
        start_time=data.start_time,
        end_time=data.end_time,
        status="active",
    )
    db.add(sale)
    db.commit()
    db.refresh(sale)

    # Load stock into Redis
    inventory.load_inventory(sale.id, data.total_stock)
    inventory_gauge.labels(sale_id=str(sale.id)).set(data.total_stock)

    return sale


@router.delete("/{sale_id}")
def delete_flash_sale(sale_id: int, db: Session = Depends(get_db)):
    """Delete a flash sale and its orders. Also clears Redis stock."""
    sale = db.query(FlashSale).filter(FlashSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Flash sale not found")

    db.query(Order).filter(Order.sale_id == sale_id).delete()
    db.delete(sale)
    db.commit()

    redis_client.delete(inventory.inventory_key(sale_id))

    return {"message": f"Flash sale {sale_id} and all its orders deleted."}


@router.get("/{sale_id}/orders", response_model=list[OrderOut])
def get_orders(sale_id: int, db: Session = Depends(get_db)):
    """Get all order history for a flash sale from MySQL."""
    return db.query(Order).filter(Order.sale_id == sale_id).all()


@router.get("/{sale_id}/stock")
def get_stock(sale_id: int):
    """Get real-time stock from Redis (fast path)."""
    stock = inventory.get_stock(sale_id)
    if stock == -1:
        raise HTTPException(status_code=404, detail="Flash sale not found or not initialized")
    return {"sale_id": sale_id, "stock": stock}


@router.post("/{sale_id}/purchase", response_model=PurchaseResponse)
def purchase(sale_id: int, request: Request, body: PurchaseRequest, db: Session = Depends(get_db)):
    """
    Attempt to purchase from a flash sale.

    Flow:
    1. Rate limit check (Redis INCR+EXPIRE)
    2. Atomic stock decrement (Redis Lua script)
    3. Create order in MySQL
    4. Compensating transaction if MySQL fails
    """
    client_ip = request.client.host

    # Step 1: Rate limiting
    if rate_limiter.is_rate_limited(client_ip):
        rate_limited_total.inc()
        raise HTTPException(status_code=429, detail="Too many requests. Slow down.")

    # Step 2: Atomic decrement via Lua script
    result = inventory.try_decrement(sale_id)

    if result == -1:
        raise HTTPException(status_code=404, detail="Flash sale not initialized")
    if result == 0:
        raise HTTPException(status_code=409, detail="Sold out")

    # Step 3: Create order in MySQL
    try:
        order = Order(sale_id=sale_id, user_id=body.user_id, quantity=body.quantity)
        db.add(order)
        db.commit()
        db.refresh(order)
    except Exception:
        # Step 4: Compensating transaction - restore Redis stock
        inventory.restore_stock(sale_id)
        db.rollback()
        raise HTTPException(status_code=500, detail="Order creation failed, stock restored")

    # Update metrics
    current_stock = inventory.get_stock(sale_id)
    inventory_gauge.labels(sale_id=str(sale_id)).set(max(current_stock, 0))
    orders_total.labels(sale_id=str(sale_id)).inc()

    return PurchaseResponse(
        order_id=order.id,
        status="confirmed",
        message=f"Purchase successful! {current_stock} items remaining.",
    )
