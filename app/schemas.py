from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ProductOut(BaseModel):
    id: int
    name: str
    description: Optional[str]
    price: float
    created_at: datetime

    class Config:
        from_attributes = True


class FlashSaleCreate(BaseModel):
    product_id: int
    total_stock: int
    start_time: datetime
    end_time: datetime


class FlashSaleOut(BaseModel):
    id: int
    product_id: int
    total_stock: int
    status: str
    start_time: datetime
    end_time: datetime

    class Config:
        from_attributes = True


class FlashSaleWithStock(BaseModel):
    id: int
    product_id: int
    total_stock: int
    stock_remaining: int
    status: str
    start_time: datetime
    end_time: datetime

    class Config:
        from_attributes = True


class OrderOut(BaseModel):
    id: int
    sale_id: int
    user_id: str
    quantity: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class PurchaseRequest(BaseModel):
    user_id: str
    quantity: int = 1


class PurchaseResponse(BaseModel):
    order_id: int
    status: str
    message: str
