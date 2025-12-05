#!/bin/bash
# =============================================================================
# Manual .NET/C# Application Deployment Script for EC2
# =============================================================================
# This script sets up the complete .NET food ordering application on an EC2 instance
# Run this after SSH'ing into your EC2 instance
#
# Prerequisites:
# 1. Have RDS endpoint, database name, username, and password ready
# 2. EC2 instance should have internet access for git clone
#
# Usage:
#   chmod +x deploy-dotnet-manual.sh
#   sudo ./deploy-dotnet-manual.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# =============================================================================
GIT_REPO_URL="https://github.com/ahkang02/food-ordering-system.git"  # Git repo URL
DB_ENDPOINT="your-rds-endpoint.rds.amazonaws.com"  # RDS endpoint
DB_NAME="foodordering"
DB_USERNAME="admin"
DB_PASSWORD="your-secure-password"  # Your RDS password

# =============================================================================
# LOGGING SETUP
# =============================================================================
LOG_FILE="/var/log/manual-deployment.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=========================================="
echo ".NET Deployment started at $(date)"
echo "=========================================="

# =============================================================================
# DETECT PACKAGE MANAGER
# =============================================================================
if command -v dnf > /dev/null 2>&1; then
    PKG_MGR=dnf
else
    PKG_MGR=yum
fi

echo "Using package manager: $PKG_MGR"

# =============================================================================
# INSTALL SYSTEM PACKAGES
# =============================================================================
echo "Step 1: Installing system packages..."
$PKG_MGR -y update || true

# Install essential tools
$PKG_MGR -y install wget curl unzip tar gzip git

# Install MariaDB client for database operations
echo "Installing MariaDB client..."
$PKG_MGR -y install mariadb105-server || $PKG_MGR -y install mariadb-server || $PKG_MGR -y install mysql-server || true

# Start MariaDB briefly to ensure mysql client works
systemctl start mariadb || systemctl start mysql || true
# Stop it since we're using RDS
systemctl stop mariadb || systemctl stop mysql || true
systemctl disable mariadb || systemctl disable mysql || true

# =============================================================================
# INSTALL .NET RUNTIME AND NGINX
# =============================================================================
echo "Step 2: Installing .NET 8 Runtime and Nginx..."

# Install .NET 8 ASP.NET Core Runtime
$PKG_MGR -y install aspnetcore-runtime-8.0 || {
    echo "aspnetcore-runtime-8.0 not found in repos, trying alternative installation..."
    # Alternative: Install from Microsoft repo
    rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm || true
    $PKG_MGR -y install aspnetcore-runtime-8.0
}

# Install Nginx as reverse proxy
$PKG_MGR -y install nginx

# Verify installations
dotnet --version || echo "dotnet not installed correctly"
nginx -v || echo "nginx not installed correctly"

# =============================================================================
# CLONE APPLICATION FROM GIT
# =============================================================================
echo "Step 3: Cloning application from Git..."

cd /tmp

# Remove any previous clone
rm -rf food-ordering-system

# Clone the repository
echo "Cloning from: $GIT_REPO_URL"
git clone "$GIT_REPO_URL" food-ordering-system

# Verify clone
if [ ! -d "food-ordering-system/dotnet-food-ordering" ]; then
    echo "ERROR: git clone failed or dotnet-food-ordering directory not found!"
    exit 1
fi

echo "Git clone successful"
ls -la food-ordering-system/

# =============================================================================
# BUILD AND PUBLISH .NET APPLICATION
# =============================================================================
echo "Step 4: Building and publishing .NET application..."

# Install .NET SDK for building (if not present)
if ! command -v dotnet > /dev/null 2>&1 || ! dotnet --list-sdks | grep -q "8.0"; then
    echo "Installing .NET 8 SDK for building..."
    $PKG_MGR -y install dotnet-sdk-8.0 || {
        rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm || true
        $PKG_MGR -y install dotnet-sdk-8.0
    }
fi

cd food-ordering-system/dotnet-food-ordering

# Restore dependencies
echo "Restoring dependencies..."
dotnet restore

# Build and publish
echo "Publishing application..."
dotnet publish -c Release -o /tmp/dotnet-publish

# Verify build
if [ ! -f "/tmp/dotnet-publish/FoodOrdering.dll" ]; then
    echo "ERROR: FoodOrdering.dll not found after build!"
    exit 1
fi

echo "Build successful"
ls -la /tmp/dotnet-publish/

# =============================================================================
# DEPLOY APPLICATION FILES
# =============================================================================
echo "Step 5: Deploying application files..."

APP_DIR="/var/www/foodordering"
mkdir -p "$APP_DIR"

# Copy published files to application directory
cp -r /tmp/dotnet-publish/* "$APP_DIR/"

# Copy database schema
cp /tmp/food-ordering-system/dotnet-food-ordering/database-schema.sql "$APP_DIR/" 2>/dev/null || true

# Copy migration script
mkdir -p "$APP_DIR/scripts"
cp /tmp/food-ordering-system/scripts/migrate-dotnet-db.sh "$APP_DIR/scripts/" 2>/dev/null || true
chmod +x "$APP_DIR/scripts/"*.sh 2>/dev/null || true

# Set ownership
chown -R ec2-user:ec2-user "$APP_DIR"

# Make the executable file executable (if it exists)
if [ -f "${APP_DIR}/FoodOrdering" ]; then
    chmod +x "${APP_DIR}/FoodOrdering"
fi

echo "Application files deployed successfully"
ls -la ${APP_DIR}

# =============================================================================
# INITIALIZE DATABASE SCHEMA
# =============================================================================
echo "Step 6: Initializing database schema..."

# Parse endpoint for host and port
DB_HOST="${DB_ENDPOINT%%:*}"
DB_PORT="${DB_ENDPOINT##*:}"
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="3306"
fi

# Check if database schema file exists
if [ -f "${APP_DIR}/database-schema.sql" ]; then
    echo "Testing database connection..."
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "Database connection successful!"
        
        # Create database if it doesn't exist
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
        
        # Check if tables already exist
        TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D "${DB_NAME}" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME}';" 2>/dev/null || echo "0")
        
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo "Database already has $TABLE_COUNT tables. Skipping schema import."
        else
            echo "Applying database schema..."
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "${DB_NAME}" < ${APP_DIR}/database-schema.sql
            echo "Database schema applied successfully"
        fi
    else
        echo "WARNING: Could not connect to database. Schema not applied."
        echo "You may need to run the migration manually later."
    fi
else
    echo "WARNING: database-schema.sql not found. You may need to apply it manually."
fi

# =============================================================================
# CREATE SYSTEMD SERVICE
# =============================================================================
echo "Step 7: Creating systemd service for .NET application..."

cat > /etc/systemd/system/foodordering.service <<EOF
[Unit]
Description=Food Ordering .NET Application
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/dotnet ${APP_DIR}/FoodOrdering.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=foodordering
User=ec2-user
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000
Environment=ConnectionStrings__DefaultConnection="Server=${DB_HOST};Port=${DB_PORT};Database=${DB_NAME};User=${DB_USERNAME};Password=${DB_PASSWORD};"

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service created"

# =============================================================================
# CONFIGURE NGINX REVERSE PROXY
# =============================================================================
echo "Step 8: Configuring Nginx reverse proxy..."

# Create Nginx configuration for the application
cat > /etc/nginx/conf.d/foodordering.conf <<'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

# Remove default nginx config to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

echo "Nginx configuration created"

# =============================================================================
# CONFIGURE SELINUX (if enabled)
# =============================================================================
if command -v getenforce > /dev/null 2>&1; then
    if [ "$(getenforce)" != "Disabled" ]; then
        echo "Step 9: Configuring SELinux..."
        
        # Allow Nginx to connect to network
        setsebool -P httpd_can_network_connect 1
        
        # Set context for application directory
        chcon -R -t httpd_sys_content_t ${APP_DIR}
    fi
fi

# =============================================================================
# START SERVICES
# =============================================================================
echo "Step 10: Starting services..."

# Reload systemd to recognize new service
systemctl daemon-reload

# Enable and start .NET application
systemctl enable foodordering
systemctl start foodordering

# Enable and restart Nginx
systemctl enable nginx
systemctl restart nginx

# Wait a moment for services to start
sleep 3

# Check service statuses
echo "Checking .NET application status..."
systemctl status foodordering --no-pager || true

echo "Checking Nginx status..."
systemctl status nginx --no-pager || true

# =============================================================================
# VERIFY DEPLOYMENT
# =============================================================================
echo "Step 11: Verifying deployment..."

# Test .NET application is running
sleep 2
APP_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/ || echo "000")

if [ "$APP_HTTP_CODE" = "200" ] || [ "$APP_HTTP_CODE" = "302" ]; then
    echo "✓ .NET application is responding (HTTP $APP_HTTP_CODE)"
else
    echo "✗ .NET application returned HTTP $APP_HTTP_CODE"
    echo "Check application logs: journalctl -u foodordering -n 50"
fi

# Test Nginx reverse proxy
NGINX_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")

if [ "$NGINX_HTTP_CODE" = "200" ] || [ "$NGINX_HTTP_CODE" = "302" ]; then
    echo "✓ Nginx is responding correctly (HTTP $NGINX_HTTP_CODE)"
else
    echo "✗ Nginx returned HTTP $NGINX_HTTP_CODE"
    echo "Check Nginx logs: tail -f /var/log/nginx/error.log"
fi

# Test database connection
echo "Testing database connection..."
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
fi

# =============================================================================
# CLEANUP
# =============================================================================
echo "Step 12: Cleaning up..."
rm -rf /tmp/food-ordering-system
rm -rf /tmp/dotnet-publish

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================
echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Application Directory: ${APP_DIR}"
echo "Git Repository: ${GIT_REPO_URL}"
echo "Database Endpoint: ${DB_ENDPOINT}"
echo "Log File: ${LOG_FILE}"
echo ""
echo "Next Steps:"
echo "1. Check application in browser: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<EC2_PUBLIC_IP>')/"
echo "2. Review logs if needed:"
echo "   - Deployment log: tail -f ${LOG_FILE}"
echo "   - Application log: journalctl -u foodordering -f"
echo "   - Nginx error log: tail -f /var/log/nginx/error.log"
echo "   - Nginx access log: tail -f /var/log/nginx/access.log"
echo ""
echo "Useful commands:"
echo "  - Restart .NET app: sudo systemctl restart foodordering"
echo "  - Check .NET app status: sudo systemctl status foodordering"
echo "  - View .NET app logs: sudo journalctl -u foodordering -n 100"
echo "  - Restart Nginx: sudo systemctl restart nginx"
echo "  - Check Nginx status: sudo systemctl status nginx"
echo "  - Test Nginx config: sudo nginx -t"
echo "=========================================="
