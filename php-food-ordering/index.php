<?php
// Simple router for PHP food ordering API
$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];

// Remove query string
$path = parse_url($requestUri, PHP_URL_PATH);

// Route to appropriate endpoint
if (strpos($path, '/api/menu') === 0) {
    require_once __DIR__ . '/api/menu.php';
} elseif (strpos($path, '/api/orders') === 0) {
    require_once __DIR__ . '/api/orders.php';
} else {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Endpoint not found']);
}
?>

