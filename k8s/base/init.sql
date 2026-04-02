CREATE TABLE IF NOT EXISTS products (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    price       DECIMAL(10,2) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS flash_sales (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    product_id  INT NOT NULL,
    total_stock INT NOT NULL,
    start_time  TIMESTAMP NOT NULL,
    end_time    TIMESTAMP NOT NULL,
    status      ENUM('pending', 'active', 'ended') DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS orders (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    sale_id     INT NOT NULL,
    user_id     VARCHAR(64) NOT NULL,
    quantity    INT DEFAULT 1,
    status      ENUM('confirmed', 'cancelled') DEFAULT 'confirmed',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sale_id) REFERENCES flash_sales(id),
    INDEX idx_sale_user (sale_id, user_id)
);

-- Seed data
INSERT INTO products (name, description, price) VALUES
    ('iPhone 15 Pro', 'Latest Apple flagship', 999.00),
    ('PS5 Console', 'Sony PlayStation 5', 499.00),
    ('Nike Air Max', 'Limited edition sneakers', 199.00);
