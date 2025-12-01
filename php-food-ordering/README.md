# Food Ordering System - PHP with Database

A simple food ordering API built with vanilla PHP, using MySQL database.

## Features

- Menu browsing (all items, by category, by ID)
- Shopping cart functionality
- Order placement
- Order status tracking
- Database integration (MySQL)

## Prerequisites

- PHP 7.4 or higher
- MySQL/MariaDB database (local or RDS)
- PDO extension enabled
- Apache with mod_rewrite (or Nginx)

## Setup

### 1. Database Setup

Run the database schema script:

```bash
mysql -u root -p < database-schema.sql
```

Or connect to your RDS instance and run the SQL script.

### 2. Database Configuration

Update `api/db_service.php` with your database credentials:

```php
$host = getenv('DB_HOST') ?: 'your-rds-endpoint.region.rds.amazonaws.com';
$dbname = getenv('DB_NAME') ?: 'foodordering';
$username = getenv('DB_USER') ?: 'admin';
$password = getenv('DB_PASS') ?: 'your-password';
```

Or set environment variables:
```bash
export DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
export DB_NAME=foodordering
export DB_USER=admin
export DB_PASS=your-password
```

### 3. Run Locally

**Using PHP Built-in Server:**
```bash
cd php-food-ordering
php -S localhost:8000 -t .
```

**Using Apache:**
- Place in `/var/www/html/php-food-ordering`
- Ensure mod_rewrite is enabled
- Access via `http://localhost/php-food-ordering/api/menu`

## API Endpoints

### Menu
- `GET /api/menu` - Get all menu items
- `GET /api/menu/{id}` - Get menu item by ID
- `GET /api/menu/category/{category}` - Get menu items by category
- `GET /api/menu/categories` - Get all categories

### Orders
- `POST /api/orders` - Create a new order
- `GET /api/orders` - Get all orders
- `GET /api/orders/{id}` - Get order by ID
- `PATCH /api/orders/{id}/status` - Update order status

## Example Request

Create an order:
```bash
curl -X POST http://localhost:8000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "cartItems": [
      {"menuItemId": 1, "quantity": 2},
      {"menuItemId": 6, "quantity": 1}
    ],
    "customerName": "John Doe",
    "customerPhone": "123-456-7890",
    "deliveryAddress": "123 Main St"
  }'
```

## EC2 Deployment

### Option 1: Apache

1. **SSH into your EC2 instance**

2. **Install Apache and PHP:**
```bash
sudo apt update
sudo apt install apache2 php php-mysql php-json -y
```

3. **Upload project files** to `/var/www/html/php-food-ordering`

4. **Set proper permissions:**
```bash
sudo chown -R www-data:www-data /var/www/html/php-food-ordering
sudo chmod -R 755 /var/www/html/php-food-ordering
```

5. **Enable mod_rewrite:**
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

6. **Configure database connection** in `api/db_service.php` or use environment variables

7. **Set up RDS:**
   - Create RDS MySQL instance
   - Run `database-schema.sql` on RDS
   - Update security group to allow EC2 connection
   - Update `db_service.php` with RDS endpoint

8. **Configure security group** to allow inbound traffic on port 80/443

### Option 2: Nginx + PHP-FPM

1. **Install Nginx and PHP-FPM:**
```bash
sudo apt update
sudo apt install nginx php-fpm php-mysql php-json -y
```

2. **Configure Nginx:**
Create `/etc/nginx/sites-available/foodordering`:
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/html/php-food-ordering;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
}
```

3. **Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/foodordering /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Database Schema

The database includes:
- `menu_items` - Menu items table
- `orders` - Orders table  
- `order_items` - Order items table

See `database-schema.sql` for full schema.

## RDS Configuration

1. **Create RDS MySQL instance** in AWS Console
2. **Configure security group** to allow inbound MySQL (port 3306) from your EC2 security group
3. **Run database schema:**
```bash
mysql -h your-rds-endpoint.region.rds.amazonaws.com -u admin -p < database-schema.sql
```
4. **Update `db_service.php`** with RDS endpoint and credentials

## Security Notes

- Use environment variables for database credentials
- Enable SSL/TLS for database connections
- Use prepared statements (already implemented)
- Consider adding authentication for production
- Implement rate limiting
- Use HTTPS for API endpoints
