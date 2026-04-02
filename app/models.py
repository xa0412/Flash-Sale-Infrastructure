from sqlalchemy import Column, Integer, String, Text, Numeric, Enum, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from database import Base


class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    price = Column(Numeric(10, 2), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())


class FlashSale(Base):
    __tablename__ = "flash_sales"
    id = Column(Integer, primary_key=True, autoincrement=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    total_stock = Column(Integer, nullable=False)
    start_time = Column(TIMESTAMP, nullable=False)
    end_time = Column(TIMESTAMP, nullable=False)
    status = Column(Enum("pending", "active", "ended"), default="pending")
    created_at = Column(TIMESTAMP, server_default=func.now())


class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, autoincrement=True)
    sale_id = Column(Integer, ForeignKey("flash_sales.id"), nullable=False)
    user_id = Column(String(64), nullable=False)
    quantity = Column(Integer, default=1)
    status = Column(Enum("confirmed", "cancelled"), default="confirmed")
    created_at = Column(TIMESTAMP, server_default=func.now())
