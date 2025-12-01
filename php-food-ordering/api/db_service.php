<?php

class DatabaseService {
    private $conn;

    public function __construct() {
        // Database configuration - update these for your RDS instance
        $host = getenv('DB_HOST') ?: 'localhost';
        $dbname = getenv('DB_NAME') ?: 'foodordering';
        $username = getenv('DB_USER') ?: 'root';
        $password = getenv('DB_PASS') ?: '';

        try {
            $this->conn = new PDO(
                "mysql:host=$host;dbname=$dbname;charset=utf8mb4",
                $username,
                $password,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
        } catch (PDOException $e) {
            error_log("Database connection failed: " . $e->getMessage());
            throw new Exception("Database connection failed");
        }
    }

    public function getAllMenuItems() {
        $stmt = $this->conn->query("SELECT * FROM menu_items ORDER BY id");
        return $stmt->fetchAll();
    }

    public function getMenuItem($id) {
        $stmt = $this->conn->prepare("SELECT * FROM menu_items WHERE id = ?");
        $stmt->execute([$id]);
        return $stmt->fetch();
    }

    public function getMenuItemsByCategory($category) {
        $stmt = $this->conn->prepare("SELECT * FROM menu_items WHERE category = ? ORDER BY id");
        $stmt->execute([$category]);
        return $stmt->fetchAll();
    }

    public function getCategories() {
        $stmt = $this->conn->query("SELECT DISTINCT category FROM menu_items ORDER BY category");
        $result = $stmt->fetchAll(PDO::FETCH_COLUMN);
        return $result;
    }

    public function createOrder($cartItems, $customerName = null, $customerPhone = null, $deliveryAddress = null) {
        $this->conn->beginTransaction();
        
        try {
            // Create order
            $stmt = $this->conn->prepare("
                INSERT INTO orders (customer_name, customer_phone, delivery_address, status, created_at)
                VALUES (?, ?, ?, 'pending', NOW())
            ");
            $stmt->execute([$customerName, $customerPhone, $deliveryAddress]);
            $orderId = $this->conn->lastInsertId();

            // Add order items and calculate total
            $total = 0;
            foreach ($cartItems as $cartItem) {
                $menuItem = $this->getMenuItem($cartItem['menuItemId']);
                if ($menuItem) {
                    $itemTotal = $menuItem['price'] * $cartItem['quantity'];
                    $total += $itemTotal;

                    $stmt = $this->conn->prepare("
                        INSERT INTO order_items (order_id, menu_item_id, menu_item_name, quantity, price)
                        VALUES (?, ?, ?, ?, ?)
                    ");
                    $stmt->execute([
                        $orderId,
                        $menuItem['id'],
                        $menuItem['name'],
                        $cartItem['quantity'],
                        $menuItem['price']
                    ]);
                }
            }

            // Update order total
            $stmt = $this->conn->prepare("UPDATE orders SET total = ? WHERE id = ?");
            $stmt->execute([$total, $orderId]);

            $this->conn->commit();

            // Return order with items
            return $this->getOrder($orderId);
        } catch (Exception $e) {
            $this->conn->rollBack();
            error_log("Error creating order: " . $e->getMessage());
            throw $e;
        }
    }

    public function getAllOrders() {
        $stmt = $this->conn->query("
            SELECT o.*, 
                   GROUP_CONCAT(
                       CONCAT(oi.menu_item_name, ' x', oi.quantity, ' ($', oi.price * oi.quantity, ')')
                       SEPARATOR ', '
                   ) as items_summary
            FROM orders o
            LEFT JOIN order_items oi ON o.id = oi.order_id
            GROUP BY o.id
            ORDER BY o.created_at DESC
        ");
        return $stmt->fetchAll();
    }

    public function getOrder($id) {
        // Get order
        $stmt = $this->conn->prepare("SELECT * FROM orders WHERE id = ?");
        $stmt->execute([$id]);
        $order = $stmt->fetch();

        if (!$order) {
            return null;
        }

        // Get order items
        $stmt = $this->conn->prepare("SELECT * FROM order_items WHERE order_id = ?");
        $stmt->execute([$id]);
        $order['items'] = $stmt->fetchAll();

        return $order;
    }

    public function updateOrderStatus($id, $status) {
        $stmt = $this->conn->prepare("UPDATE orders SET status = ? WHERE id = ?");
        $stmt->execute([$status, $id]);
        return $this->getOrder($id);
    }
}

?>

