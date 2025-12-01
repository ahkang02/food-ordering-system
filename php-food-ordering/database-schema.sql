-- Food Ordering System Database Schema for PHP
-- Compatible with MySQL/MariaDB

CREATE DATABASE IF NOT EXISTS foodordering;
USE foodordering;

-- Menu Items Table
CREATE TABLE IF NOT EXISTS menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500),
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    image_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category)
);

-- Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    customer_name VARCHAR(200),
    customer_phone VARCHAR(50),
    delivery_address VARCHAR(500),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    menu_item_name VARCHAR(200) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_menu_item_id (menu_item_id)
);

-- Insert Sample Menu Items
INSERT INTO menu_items (name, description, price, category, image_url) VALUES
('Margherita Pizza', 'Classic tomato, mozzarella, and basil', 12.99, 'Pizza', 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&h=300&fit=crop'),
('Pepperoni Pizza', 'Pepperoni and mozzarella cheese', 14.99, 'Pizza', 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400&h=300&fit=crop'),
('Caesar Salad', 'Fresh romaine lettuce with caesar dressing', 8.99, 'Salads', 'https://images.unsplash.com/photo-1546793665-c74611f273ed?w=400&h=300&fit=crop'),
('Chicken Burger', 'Grilled chicken breast with lettuce and mayo', 10.99, 'Burgers', 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=400&h=300&fit=crop'),
('Beef Burger', 'Juicy beef patty with cheese and vegetables', 11.99, 'Burgers', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop'),
('French Fries', 'Crispy golden fries', 4.99, 'Sides', 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&h=300&fit=crop'),
('Coca Cola', 'Refreshing cola drink', 2.99, 'Drinks', 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400&h=300&fit=crop'),
('Chocolate Cake', 'Rich chocolate cake slice', 6.99, 'Desserts', 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&h=300&fit=crop')
ON DUPLICATE KEY UPDATE name=name;

