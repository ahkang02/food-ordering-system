# Food Ordering System - .NET Core 9 Full-Stack

A full-stack food ordering system built with .NET Core 9 Razor Pages, using Entity Framework Core for database access.

## Features

- 🍕 Menu display with category filtering
- 🛒 Shopping cart functionality
- 💳 Checkout process (fake payment)
- 📦 Order confirmation
- 🗄️ Database integration (MySQL/PostgreSQL)

## Prerequisites

- .NET 9 SDK
- MySQL or PostgreSQL database (local or RDS)
- For EC2 deployment: Ubuntu/Linux with .NET 9 runtime

## Setup

### 1. Database Configuration

Update `appsettings.json` with your database connection string:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=your-rds-endpoint.region.rds.amazonaws.com;Database=foodordering;User Id=admin;Password=your-password;"
  }
}
```

**For MySQL:**
```
Server=host;Database=foodordering;User Id=user;Password=pass;
```

**For PostgreSQL:**
```
Host=host;Database=foodordering;Username=user;Password=pass;
```

### 2. Database Migration

The application will automatically create the database schema on first run using `EnsureCreated()`. 

Alternatively, you can use Entity Framework migrations:

```bash
# Install EF tools (if not already installed)
dotnet tool install --global dotnet-ef

# Create migration
dotnet ef migrations add InitialCreate

# Apply migration
dotnet ef database update
```

Or run the SQL script manually:
- `database-schema.sql` for MySQL
- `database-schema-postgresql.sql` for PostgreSQL

### 3. Run the Application

```bash
cd dotnet-food-ordering
dotnet restore
dotnet run
```

Access at: http://localhost:5000

## Project Structure

```
dotnet-food-ordering/
├── Pages/              # Razor Pages (CSHTML)
│   ├── Index.cshtml    # Menu page
│   ├── Cart.cshtml     # Shopping cart
│   ├── Checkout.cshtml # Checkout form
│   └── OrderConfirmation.cshtml
├── Models/             # Data models
├── Data/               # DbContext
├── Controllers/        # API controllers
├── wwwroot/           # Static files (CSS, JS)
└── appsettings.json   # Configuration
```

## Pages

1. **Index (/)**: Menu display with category filters
2. **Cart (/Cart)**: Shopping cart with quantity controls
3. **Checkout (/Checkout)**: Order form with delivery information
4. **OrderConfirmation**: Order confirmation page

## API Endpoints

- `GET /api/menu` - Get all menu items
- `GET /api/menu/{id}` - Get menu item by ID
- `POST /api/orders` - Create a new order

## EC2 Deployment

1. **SSH into your EC2 instance**

2. **Install .NET 9 Runtime:**
```bash
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 9.0
export PATH=$PATH:$HOME/.dotnet
```

3. **Set up RDS connection:**
   - Create RDS instance (MySQL or PostgreSQL)
   - Update `appsettings.json` with RDS endpoint
   - Ensure security group allows connection from EC2

4. **Upload project files** to EC2

5. **Build and publish:**
```bash
cd dotnet-food-ordering
dotnet publish -c Release -o ./publish
```

6. **Run the application:**
```bash
cd publish
dotnet FoodOrdering.dll --urls "http://0.0.0.0:5000"
```

7. **Use systemd for service management:**

Create `/etc/systemd/system/foodordering.service`:
```ini
[Unit]
Description=Food Ordering API
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/dotnet /path/to/publish/FoodOrdering.dll --urls "http://0.0.0.0:5000"
Restart=always
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable foodordering
sudo systemctl start foodordering
```

8. **Configure security group** to allow inbound traffic on port 5000

9. **Optional: Use Nginx as reverse proxy** for port 80/443

## Database Schema

The database includes:
- `menu_items` - Menu items table
- `orders` - Orders table
- `order_items` - Order items table

See `database-schema.sql` or `database-schema-postgresql.sql` for full schema.
