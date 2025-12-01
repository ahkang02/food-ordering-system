<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/db_service.php';

$dataService = new DatabaseService();

$method = $_SERVER['REQUEST_METHOD'];
$path = $_SERVER['REQUEST_URI'];
$pathParts = explode('/', trim(parse_url($path, PHP_URL_PATH), '/'));

// Remove 'api' and 'menu' from path
$pathParts = array_slice($pathParts, array_search('menu', $pathParts) + 1);

if ($method === 'GET') {
    if (empty($pathParts[0])) {
        // GET /api/menu
        echo json_encode($dataService->getAllMenuItems());
    } elseif ($pathParts[0] === 'categories') {
        // GET /api/menu/categories
        echo json_encode($dataService->getCategories());
    } elseif ($pathParts[0] === 'category' && !empty($pathParts[1])) {
        // GET /api/menu/category/{category}
        $category = urldecode($pathParts[1]);
        echo json_encode($dataService->getMenuItemsByCategory($category));
    } elseif (is_numeric($pathParts[0])) {
        // GET /api/menu/{id}
        $id = (int)$pathParts[0];
        $item = $dataService->getMenuItem($id);
        if ($item) {
            echo json_encode($item);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Menu item not found']);
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

