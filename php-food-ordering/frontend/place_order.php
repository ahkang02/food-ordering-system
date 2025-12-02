<?php
// $dataService is available from index.php

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!isset($_SESSION['cart']) || empty($_SESSION['cart'])) {
        header('Location: /');
        exit;
    }

    $name = $_POST['name'] ?? '';
    $phone = $_POST['phone'] ?? '';
    $address = $_POST['address'] ?? '';

    // Prepare cart items for DatabaseService
    // DatabaseService expects: [['menuItemId' => 1, 'quantity' => 2], ...]
    $cartItems = [];
    foreach ($_SESSION['cart'] as $item) {
        $cartItems[] = [
            'menuItemId' => $item['id'],
            'quantity' => $item['quantity']
        ];
    }

    try {
        $order = $dataService->createOrder($cartItems, $name, $phone, $address);
        
        // Clear cart
        unset($_SESSION['cart']);
        
        // Redirect to success
        header('Location: /success');
        exit;
    } catch (Exception $e) {
        // Handle error (simple version)
        echo "Error placing order: " . $e->getMessage();
        exit;
    }
} else {
    header('Location: /');
    exit;
}
?>
