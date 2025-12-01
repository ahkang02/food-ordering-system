# Food Ordering System - Setup Guide

## Overview

Two complete food ordering systems:
1. **.NET Core 9** - Full-stack Razor Pages application
2. **PHP** - RESTful API with database

Both systems:
- Connect to RDS database (MySQL or PostgreSQL)
- Simple flow: Menu → Cart → Checkout
- Fake checkout (no real payment processing)

## Quick Start

### .NET Core 9 Setup

1. **Configure database connection** in `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=your-rds-endpoint;Database=foodordering;User Id=user;Password=pass;"
  }
}
```

2. **Run migrations:**
```bash
cd dotnet-food-ordering
dotnet ef migrations add InitialCreate
dotnet ef database update
```

3. **Run application:**
```bash
dotnet run
```

4. **Access:** http://localhost:5000

### PHP Setup

1. **Create database:**
```bash
mysql -h your-rds-endpoint -u admin -p < php-food-ordering/database-schema.sql
```

2. **Configure database** in `api/db_service.php`:
```php
$host = 'your-rds-endpoint.region.rds.amazonaws.com';
$dbname = 'foodordering';
$username = 'admin';
$password = 'your-password';
```

3. **Run:**
```bash
cd php-food-ordering
php -S localhost:8000 -t .
```

4. **Access API:** http://localhost:8000/api/menu

## Database Setup

### For .NET (Entity Framework)

The app will auto-create the database on first run, or use migrations:

```bash
dotnet ef migrations add InitialCreate
dotnet ef database update
```

### For PHP (Manual SQL)

Run the SQL script:
```bash
mysql -h your-rds-endpoint -u admin -p < database-schema.sql
```

Or for PostgreSQL:
```bash
psql -h your-rds-endpoint -U admin -d foodordering -f database-schema-postgresql.sql
```

## RDS Configuration

1. **Create RDS instance** (MySQL or PostgreSQL)
2. **Configure security group:**
   - Allow inbound MySQL (3306) or PostgreSQL (5432) from EC2 security group
   - Allow inbound HTTP (80) or HTTPS (443) for web access
3. **Get endpoint:** `your-db.region.rds.amazonaws.com`
4. **Update connection strings** in both projects

## EC2 Deployment

### .NET Core 9

1. Install .NET 9 runtime on EC2
2. Upload project files
3. Update `appsettings.json` with RDS connection
4. Run migrations: `dotnet ef database update`
5. Publish: `dotnet publish -c Release`
6. Run: `dotnet FoodOrdering.dll --urls "http://0.0.0.0:5000"`

### PHP

1. Install PHP and Apache/Nginx on EC2
2. Upload project files
3. Update `api/db_service.php` with RDS connection
4. Run database schema SQL script
5. Configure web server
6. Access via EC2 public IP

## Project Structure

### .NET Core 9
```
dotnet-food-ordering/
├── Pages/              # Razor Pages (CSHTML)
│   ├── Index.cshtml     # Menu page
│   ├── Cart.cshtml      # Cart page
│   └── Checkout.cshtml  # Checkout page
├── Models/              # Data models
├── Data/                # DbContext
├── Controllers/         # API controllers
└── wwwroot/            # Static files
```

### PHP
```
php-food-ordering/
├── api/
│   ├── menu.php        # Menu endpoints
│   ├── orders.php      # Order endpoints
│   └── db_service.php  # Database service
└── database-schema.sql # Database schema
```

## Features

- ✅ Menu display with category filtering
- ✅ Add items to cart
- ✅ Update cart quantities
- ✅ Checkout with delivery information
- ✅ Order confirmation
- ✅ Database persistence
- ✅ RDS compatible

## Notes

- Checkout is **fake** - no real payment processing
- Cart uses browser sessionStorage (client-side)
- Orders are saved to database
- Both systems use the same database schema

