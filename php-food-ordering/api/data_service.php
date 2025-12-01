<?php

class DataService {
    private $menuItems = [];
    private $orders = [];
    private $nextOrderId = 1;
    private $dataFile = __DIR__ . '/data.json';

    public function __construct() {
        $this->loadData();
        if (empty($this->menuItems)) {
            $this->initializeMenu();
            $this->saveData();
        }
    }

    private function initializeMenu() {
        $this->menuItems = [
            [
                'id' => 1,
                'name' => 'Margherita Pizza',
                'description' => 'Classic tomato, mozzarella, and basil',
                'price' => 12.99,
                'category' => 'Pizza',
                'imageUrl' => '/images/margherita.jpg'
            ],
            [
                'id' => 2,
                'name' => 'Pepperoni Pizza',
                'description' => 'Pepperoni and mozzarella cheese',
                'price' => 14.99,
                'category' => 'Pizza',
                'imageUrl' => '/images/pepperoni.jpg'
            ],
            [
                'id' => 3,
                'name' => 'Caesar Salad',
                'description' => 'Fresh romaine lettuce with caesar dressing',
                'price' => 8.99,
                'category' => 'Salads',
                'imageUrl' => '/images/caesar.jpg'
            ],
            [
                'id' => 4,
                'name' => 'Chicken Burger',
                'description' => 'Grilled chicken breast with lettuce and mayo',
                'price' => 10.99,
                'category' => 'Burgers',
                'imageUrl' => '/images/chicken-burger.jpg'
            ],
            [
                'id' => 5,
                'name' => 'Beef Burger',
                'description' => 'Juicy beef patty with cheese and vegetables',
                'price' => 11.99,
                'category' => 'Burgers',
                'imageUrl' => '/images/beef-burger.jpg'
            ],
            [
                'id' => 6,
                'name' => 'French Fries',
                'description' => 'Crispy golden fries',
                'price' => 4.99,
                'category' => 'Sides',
                'imageUrl' => '/images/fries.jpg'
            ],
            [
                'id' => 7,
                'name' => 'Coca Cola',
                'description' => 'Refreshing cola drink',
                'price' => 2.99,
                'category' => 'Drinks',
                'imageUrl' => '/images/coke.jpg'
            ],
            [
                'id' => 8,
                'name' => 'Chocolate Cake',
                'description' => 'Rich chocolate cake slice',
                'price' => 6.99,
                'category' => 'Desserts',
                'imageUrl' => '/images/chocolate-cake.jpg'
            ]
        ];
    }

    private function loadData() {
        if (file_exists($this->dataFile)) {
            $data = json_decode(file_get_contents($this->dataFile), true);
            $this->menuItems = $data['menuItems'] ?? [];
            $this->orders = $data['orders'] ?? [];
            $this->nextOrderId = $data['nextOrderId'] ?? 1;
        }
    }

    private function saveData() {
        $data = [
            'menuItems' => $this->menuItems,
            'orders' => $this->orders,
            'nextOrderId' => $this->nextOrderId
        ];
        file_put_contents($this->dataFile, json_encode($data, JSON_PRETTY_PRINT));
    }

    public function getAllMenuItems() {
        return array_values($this->menuItems);
    }

    public function getMenuItem($id) {
        foreach ($this->menuItems as $item) {
            if ($item['id'] == $id) {
                return $item;
            }
        }
        return null;
    }

    public function getMenuItemsByCategory($category) {
        $result = [];
        foreach ($this->menuItems as $item) {
            if (strcasecmp($item['category'], $category) === 0) {
                $result[] = $item;
            }
        }
        return $result;
    }

    public function getCategories() {
        $categories = [];
        foreach ($this->menuItems as $item) {
            if (!in_array($item['category'], $categories)) {
                $categories[] = $item['category'];
            }
        }
        sort($categories);
        return $categories;
    }

    public function createOrder($cartItems, $customerName = null, $customerPhone = null, $deliveryAddress = null) {
        $order = [
            'id' => $this->nextOrderId++,
            'createdAt' => date('c'),
            'status' => 'pending',
            'items' => [],
            'total' => 0,
            'customerName' => $customerName,
            'customerPhone' => $customerPhone,
            'deliveryAddress' => $deliveryAddress
        ];

        foreach ($cartItems as $cartItem) {
            $menuItem = $this->getMenuItem($cartItem['menuItemId']);
            if ($menuItem) {
                $orderItem = [
                    'menuItemId' => $menuItem['id'],
                    'menuItemName' => $menuItem['name'],
                    'quantity' => $cartItem['quantity'],
                    'price' => $menuItem['price']
                ];
                $order['items'][] = $orderItem;
                $order['total'] += $menuItem['price'] * $cartItem['quantity'];
            }
        }

        $this->orders[] = $order;
        $this->saveData();
        return $order;
    }

    public function getAllOrders() {
        usort($this->orders, function($a, $b) {
            return strtotime($b['createdAt']) - strtotime($a['createdAt']);
        });
        return $this->orders;
    }

    public function getOrder($id) {
        foreach ($this->orders as $order) {
            if ($order['id'] == $id) {
                return $order;
            }
        }
        return null;
    }

    public function updateOrderStatus($id, $status) {
        foreach ($this->orders as &$order) {
            if ($order['id'] == $id) {
                $order['status'] = $status;
                $this->saveData();
                return $order;
            }
        }
        return null;
    }
}

?>

