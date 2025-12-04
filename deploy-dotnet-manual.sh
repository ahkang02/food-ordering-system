#!/bin/bash
# =============================================================================
# Manual .NET/C# Application Deployment Script for EC2
# =============================================================================
# This script sets up the complete .NET food ordering application on an EC2 instance
# Run this after SSH'ing into your EC2 instance
#
# Prerequisites:
# 1. Upload dotnet-food-ordering published files to S3 bucket as dotnet-published.zip
# 2. Have RDS endpoint, database name, username, and password ready
# 3. EC2 instance should have IAM role with S3 read access
#
# Usage:
#   chmod +x deploy-dotnet-manual.sh
#   sudo ./deploy-dotnet-manual.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# =============================================================================
S3_BUCKET_NAME="bucket-food-ordering-123456"  # Your S3 bucket name
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
$PKG_MGR -y update

# Install essential tools
$PKG_MGR -y install wget curl unzip tar gzip

# Install AWS CLI if not present
if ! command -v aws > /dev/null 2>&1; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install MariaDB client for database operations
echo "Installing MariaDB client..."
$PKG_MGR -y install mariadb105-server

# Secure MariaDB installation (non-interactive)
echo "Securing MariaDB installation..."
# Start MariaDB service temporarily for secure installation
systemctl start mariadb || true
# Run mysql_secure_installation non-interactively
mysql -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root';" 2>/dev/null || true
mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
# Stop local MariaDB as we're using RDS
systemctl stop mariadb || true
systemctl disable mariadb || true

# =============================================================================
# INSTALL .NET RUNTIME AND NGINX
# =============================================================================
echo "Step 2: Installing .NET 8 Runtime and Nginx..."

# Install .NET 8 ASP.NET Core Runtime
$PKG_MGR -y install aspnetcore-runtime-8.0

# Install Nginx as reverse proxy
$PKG_MGR -y install nginx

# Verify installations
dotnet --version
nginx -v

# =============================================================================
# PREPARE APPLICATION DIRECTORY
# =============================================================================
echo "Step 3: Preparing application directory..."

APP_DIR="/var/www/foodordering"
mkdir -p "$APP_DIR"

# Set ownership to ec2-user (or current user)
chown -R ec2-user:ec2-user "$APP_DIR"

# =============================================================================
# DOWNLOAD APPLICATION FROM S3
# =============================================================================
echo "Step 4: Downloading .NET application from S3..."

cd /tmp

# Try to get the latest deployment package
LATEST_DEPLOYMENT=$(aws s3 ls s3://${S3_BUCKET_NAME}/dotnet-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}' || true)

if [ -n "$LATEST_DEPLOYMENT" ]; then
    echo "Found latest deployment: $LATEST_DEPLOYMENT"
    aws s3 cp "s3://${S3_BUCKET_NAME}/${LATEST_DEPLOYMENT}" ./deployment-package.zip
    PACKAGE_FILE="deployment-package.zip"
else
    echo "No deployment found in dotnet-deployments/, trying generic artifact..."
    aws s3 cp "s3://${S3_BUCKET_NAME}/dotnet-published.zip" ./dotnet-published.zip
    PACKAGE_FILE="dotnet-published.zip"
fi

# =============================================================================
# EXTRACT APPLICATION FILES
# =============================================================================
echo "Step 5: Extracting application files..."

# Extract application (will overwrite existing files)
unzip -o "/tmp/${PACKAGE_FILE}" -d ${APP_DIR}

# Set ownership
chown -R ec2-user:ec2-user ${APP_DIR}

# Make the executable file executable (if it exists)
if [ -f "${APP_DIR}/FoodOrdering" ]; then
    chmod +x "${APP_DIR}/FoodOrdering"
fi

# Verify extraction
if [ ! -f "${APP_DIR}/FoodOrdering.dll" ]; then
    echo "ERROR: FoodOrdering.dll not found after extraction!"
    exit 1
fi

echo "Application files extracted successfully"
ls -la ${APP_DIR}

# =============================================================================
# INITIALIZE DATABASE SCHEMA
# =============================================================================
echo "Step 6: Initializing database schema..."

# Check if database schema file exists
if [ -f "${APP_DIR}/database-schema.sql" ]; then
    echo "Applying database schema..."
    mysql -h ${DB_ENDPOINT} -u ${DB_USERNAME} -p${DB_PASSWORD} < ${APP_DIR}/database-schema.sql
    echo "Database schema applied successfully"
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
Environment=ConnectionStrings__DefaultConnection="Server=${DB_ENDPOINT};Database=${DB_NAME};User=${DB_USERNAME};Password=${DB_PASSWORD};"

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

# Enable and start Nginx
systemctl enable nginx
systemctl restart nginx

# Wait a moment for services to start
sleep 3

# Check service statuses
echo "Checking .NET application status..."
systemctl status foodordering --no-pager

echo "Checking Nginx status..."
systemctl status nginx --no-pager

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
mysql -h ${DB_ENDPOINT} -u ${DB_USERNAME} -p${DB_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
fi

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================
echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Application Directory: ${APP_DIR}"
echo "Database Endpoint: ${DB_ENDPOINT}"
echo "Log File: ${LOG_FILE}"
echo ""
echo "Next Steps:"
echo "1. Check application in browser: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"
echo "2. Review logs if needed:"
echo "   - Deployment log: tail -f ${LOG_FILE}"
echo "   - Application log: journalctl -u foodordering -f"
echo "   - Nginx error log: tail -f /var/log/nginx/error.log"
echo "   - Nginx access log: tail -f /var/log/nginx/access_log"
echo ""
echo "Useful commands:"
echo "  - Restart .NET app: sudo systemctl restart foodordering"
echo "  - Check .NET app status: sudo systemctl status foodordering"
echo "  - View .NET app logs: sudo journalctl -u foodordering -n 100"
echo "  - Restart Nginx: sudo systemctl restart nginx"
echo "  - Check Nginx status: sudo systemctl status nginx"
echo "  - Test Nginx config: sudo nginx -t"
echo "=========================================="
