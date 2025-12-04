<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Load database configuration
if (file_exists(__DIR__ . '/db_config.php')) {
    require_once __DIR__ . '/db_config.php';
}

require_once __DIR__ . '/db_service.php';

$dataService = new DatabaseService();

$method = $_SERVER['REQUEST_METHOD'];
$path = $_SERVER['REQUEST_URI'];
$pathParts = explode('/', trim(parse_url($path, PHP_URL_PATH), '/'));

// Remove 'api' and 'orders' from path
$pathParts = array_slice($pathParts, array_search('orders', $pathParts) + 1);

if ($method === 'GET') {
    if (empty($pathParts[0])) {
        // GET /api/orders
        echo json_encode($dataService->getAllOrders());
    } elseif (is_numeric($pathParts[0])) {
        // GET /api/orders/{id}
        $id = (int)$pathParts[0];
        $order = $dataService->getOrder($id);
        if ($order) {
            echo json_encode($order);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Order not found']);
        }
    } else {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid request']);
    }
} elseif ($method === 'POST') {
    // POST /api/orders
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['cartItems']) || empty($input['cartItems'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Cart cannot be empty']);
        exit();
    }
    
    $order = $dataService->createOrder(
        $input['cartItems'] ?? [],
        $input['customerName'] ?? null,
        $input['customerPhone'] ?? null,
        $input['deliveryAddress'] ?? null
    );
    
    http_response_code(201);
    echo json_encode($order);
} elseif ($method === 'PATCH') {
    // PATCH /api/orders/{id}/status
    if (is_numeric($pathParts[0]) && isset($pathParts[1]) && $pathParts[1] === 'status') {
        $id = (int)$pathParts[0];
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($input['status'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Status is required']);
            exit();
        }
        
        $order = $dataService->updateOrderStatus($id, $input['status']);
        if ($order) {
            echo json_encode($order);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Order not found']);
        }
    } else {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid request']);
    }
} else {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
}
?>

