<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', '/var/log/php_errors.log');

session_start();

// Simple router for PHP food ordering API and frontend
$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];
$path = parse_url($requestUri, PHP_URL_PATH);

// API routing
if (strpos($path, '/api/menu') === 0) {
    require_once __DIR__ . '/api/menu.php';
    exit;
} elseif (strpos($path, '/api/orders') === 0) {
    require_once __DIR__ . '/api/orders.php';
    exit;
}

// Frontend routing - load database config first, then service
if (file_exists(__DIR__ . '/api/db_config.php')) {
    require_once __DIR__ . '/api/db_config.php';
}
require_once __DIR__ . '/api/db_service.php';
$dataService = new DatabaseService();

if ($path === '/' || $path === '/index.php') {
    // Filter logic for home page
    $activeCategory = $_GET['category'] ?? 'All';
    
    $menuItems = $dataService->getAllMenuItems();
    $categories = $dataService->getCategories();
    array_unshift($categories, 'All'); // Add 'All' option manually

    $filteredItems = $activeCategory === 'All' 
        ? $menuItems 
        : array_filter($menuItems, fn($item) => $item['category'] === $activeCategory);
    
    require __DIR__ . '/frontend/home.php';
    exit;
}

if ($path === '/checkout') {
    require __DIR__ . '/frontend/checkout.php';
    exit;
}

if ($path === '/place_order') {
    require __DIR__ . '/frontend/place_order.php';
    exit;
}

if ($path === '/success') {
    require __DIR__ . '/frontend/success.php';
    exit;
}

if ($path === '/cart') {
    require __DIR__ . '/frontend/cart_actions.php';
    exit;
}

// Serve static assets if needed (though we're using CDN for icons/fonts)
// ...

// 404
http_response_code(404);
echo "404 Not Found";
?>
