<?php
// Simple debug page to check PHP configuration and database connection
// Access this at: http://your-ip/debug.php

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>PHP Debug Page</h1>";
echo "<hr>";

// PHP Info
echo "<h2>1. PHP Version</h2>";
echo "<p>PHP Version: " . phpversion() . "</p>";

// Required Extensions
echo "<h2>2. Required Extensions</h2>";
$extensions = ['pdo', 'pdo_mysql', 'mysqli', 'json', 'session'];
echo "<ul>";
foreach ($extensions as $ext) {
    $status = extension_loaded($ext) ? "✅ Loaded" : "❌ NOT LOADED";
    echo "<li><strong>$ext</strong>: $status</li>";
}
echo "</ul>";

// Check db_config.php
echo "<h2>3. Database Configuration</h2>";
if (file_exists(__DIR__ . '/api/db_config.php')) {
    echo "<p>✅ db_config.php exists</p>";
    require_once __DIR__ . '/api/db_config.php';
    
    $host = getenv('DB_HOST') ?: $_ENV['DB_HOST'] ?? 'NOT SET';
    $name = getenv('DB_NAME') ?: $_ENV['DB_NAME'] ?? 'NOT SET';
    $user = getenv('DB_USER') ?: $_ENV['DB_USER'] ?? 'NOT SET';
    $pass = getenv('DB_PASS') ? '***SET***' : 'NOT SET';
    
    echo "<ul>";
    echo "<li>DB_HOST: " . htmlspecialchars($host) . "</li>";
    echo "<li>DB_NAME: " . htmlspecialchars($name) . "</li>";
    echo "<li>DB_USER: " . htmlspecialchars($user) . "</li>";
    echo "<li>DB_PASS: $pass</li>";
    echo "</ul>";
    
    // Check if placeholders are still there
    if (strpos($host, '__DB_') !== false) {
        echo "<p>⚠️ <strong>WARNING: Database config still has placeholders! Deployment script didn't replace them.</strong></p>";
    }
} else {
    echo "<p>❌ db_config.php NOT FOUND</p>";
}

// Test Database Connection
echo "<h2>4. Database Connection Test</h2>";
try {
    $host = getenv('DB_HOST') ?: $_ENV['DB_HOST'] ?? '';
    $name = getenv('DB_NAME') ?: $_ENV['DB_NAME'] ?? '';
    $user = getenv('DB_USER') ?: $_ENV['DB_USER'] ?? '';
    $pass = getenv('DB_PASS') ?: $_ENV['DB_PASS'] ?? '';
    
    // Handle host:port format
    if (strpos($host, ':') !== false) {
        list($dbHost, $dbPort) = explode(':', $host);
    } else {
        $dbHost = $host;
        $dbPort = 3306;
    }
    
    echo "<p>Attempting connection to: $dbHost:$dbPort...</p>";
    
    $dsn = "mysql:host=$dbHost;port=$dbPort;dbname=$name;charset=utf8mb4";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "<p>✅ <strong>Database connection successful!</strong></p>";
    
    // Check tables
    $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    echo "<p>Tables in database: " . implode(', ', $tables) . "</p>";
    
} catch (PDOException $e) {
    echo "<p>❌ <strong>Database connection FAILED:</strong></p>";
    echo "<pre>" . htmlspecialchars($e->getMessage()) . "</pre>";
}

// Check file permissions
echo "<h2>5. File Permissions</h2>";
$files = [
    '/var/www/html/index.php',
    '/var/www/html/api/db_config.php',
    '/var/www/html/api/db_service.php',
];
echo "<ul>";
foreach ($files as $file) {
    if (file_exists($file)) {
        $perms = substr(sprintf('%o', fileperms($file)), -4);
        $owner = posix_getpwuid(fileowner($file))['name'] ?? fileowner($file);
        echo "<li>$file: $perms (owner: $owner) ✅</li>";
    } else {
        echo "<li>$file: ❌ NOT FOUND</li>";
    }
}
echo "</ul>";

// Apache user
echo "<h2>6. Web Server Info</h2>";
echo "<p>Running as user: " . (function_exists('posix_getpwuid') ? posix_getpwuid(posix_geteuid())['name'] : get_current_user()) . "</p>";
echo "<p>Document root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";

echo "<hr>";
echo "<p><em>Delete this file after debugging!</em></p>";
?>
