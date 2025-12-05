#!/bin/bash
# =============================================================================
# Manual PHP Application Deployment Script for EC2
# =============================================================================
# This script sets up the complete PHP food ordering application on an EC2 instance
# Run this after SSH'ing into your EC2 instance
#
# Prerequisites:
# 1. Have RDS endpoint, database name, username, and password ready
# 2. EC2 instance should have internet access for git clone
#
# Usage:
#   chmod +x deploy-php-manual.sh
#   sudo ./deploy-php-manual.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# =============================================================================
GIT_REPO_URL="https://github.com/ahkang02/food-ordering-system.git"  # Git repo URL
DB_ENDPOINT="food-ordering-production-db.cpxf6cp2lxyo.us-east-1.rds.amazonaws.com"  # RDS endpoint
DB_NAME="foodordering"
DB_USERNAME="admin"
DB_PASSWORD="Admin1234!!"  # Your RDS password

# =============================================================================
# LOGGING SETUP
# =============================================================================
LOG_FILE="/var/log/manual-deployment.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=========================================="
echo "Deployment started at $(date)"
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

# Install MySQL client for database operations
echo "Installing MariaDB client..."
$PKG_MGR -y install mariadb105-server || $PKG_MGR -y install mariadb-server || $PKG_MGR -y install mysql-server || true

# Start MariaDB briefly to ensure mysql client works
systemctl start mariadb || systemctl start mysql || true
# Stop it since we're using RDS
systemctl stop mariadb || systemctl stop mysql || true
systemctl disable mariadb || systemctl disable mysql || true

# =============================================================================
# INSTALL PHP AND APACHE
# =============================================================================
echo "Step 2: Installing PHP and Apache..."

# Install Apache
$PKG_MGR -y install httpd

# Install PHP and required extensions
echo "Installing PHP and extensions..."
$PKG_MGR -y install php php-cli php-mysqlnd php-pdo php-mbstring php-json php-xml || true

# Verify installations
php --version || echo "PHP not installed correctly"
httpd -v || echo "Apache not installed correctly"

# =============================================================================
# CONFIGURE APACHE
# =============================================================================
echo "Step 3: Configuring Apache..."

# Set document root
DOCROOT=/var/www/html

# Backup default Apache config if it exists
if [ -f /etc/httpd/conf/httpd.conf ]; then
    cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup
fi

# Create a separate config file for the food ordering app (better practice)
cat > /etc/httpd/conf.d/foodordering.conf <<'APACHE_EOF'
# Food Ordering Application Configuration
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
APACHE_EOF

echo "Apache configured for mod_rewrite and .htaccess support"

# =============================================================================
# CLONE APPLICATION FROM GIT
# =============================================================================
echo "Step 4: Cloning application from Git..."

cd /tmp

# Remove any previous clone
rm -rf food-ordering-system

# Clone the repository
echo "Cloning from: $GIT_REPO_URL"
git clone "$GIT_REPO_URL" food-ordering-system

# Verify clone
if [ ! -d "food-ordering-system/php-food-ordering" ]; then
    echo "ERROR: git clone failed or php-food-ordering directory not found!"
    exit 1
fi

echo "Git clone successful"
ls -la food-ordering-system/

# =============================================================================
# DEPLOY APPLICATION FILES
# =============================================================================
echo "Step 5: Deploying application files..."

# Clear existing content (keep Apache default if any)
rm -rf ${DOCROOT}/*

# Copy PHP application files to document root
cp -r food-ordering-system/php-food-ordering/* ${DOCROOT}/

# Also copy the scripts directory for migrations
mkdir -p ${DOCROOT}/scripts
cp food-ordering-system/scripts/migrate-php-db.sh ${DOCROOT}/scripts/
chmod +x ${DOCROOT}/scripts/migrate-php-db.sh

# Verify extraction
if [ ! -f "${DOCROOT}/index.php" ]; then
    echo "ERROR: index.php not found after deployment!"
    exit 1
fi

echo "Application files deployed successfully"
ls -la ${DOCROOT}

# =============================================================================
# CONFIGURE DATABASE CONNECTION
# =============================================================================
echo "Step 6: Configuring database connection..."

# Create api directory if it doesn't exist
mkdir -p ${DOCROOT}/api

# Create database configuration file
cat > ${DOCROOT}/api/db_config.php <<PHPEOF
<?php
// Database configuration - Auto-generated by deployment script
// Generated at: $(date)
\$_ENV['DB_HOST'] = '${DB_ENDPOINT}';
\$_ENV['DB_NAME'] = '${DB_NAME}';
\$_ENV['DB_USER'] = '${DB_USERNAME}';
\$_ENV['DB_PASS'] = '${DB_PASSWORD}';
?>
PHPEOF

echo "Database configuration created"

# =============================================================================
# INITIALIZE DATABASE SCHEMA
# =============================================================================
echo "Step 7: Initializing database schema..."

# Parse endpoint for host and port
DB_HOST="${DB_ENDPOINT%%:*}"
DB_PORT="${DB_ENDPOINT##*:}"
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="3306"
fi

# Check if database schema file exists
if [ -f "${DOCROOT}/database-schema.sql" ]; then
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
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "${DB_NAME}" < ${DOCROOT}/database-schema.sql
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
# SET PERMISSIONS
# =============================================================================
echo "Step 8: Setting file permissions..."

# Set ownership to Apache user
chown -R apache:apache ${DOCROOT}

# Set appropriate permissions
find ${DOCROOT} -type d -exec chmod 755 {} \;
find ${DOCROOT} -type f -exec chmod 644 {} \;

# Make sure scripts are executable
chmod +x ${DOCROOT}/scripts/*.sh 2>/dev/null || true

# Make sure .htaccess is readable
if [ -f "${DOCROOT}/.htaccess" ]; then
    chmod 644 ${DOCROOT}/.htaccess
    echo ".htaccess file found and permissions set"
else
    echo "WARNING: .htaccess file not found!"
fi

# =============================================================================
# CONFIGURE SELINUX (if enabled)
# =============================================================================
if command -v getenforce > /dev/null 2>&1; then
    if [ "$(getenforce)" != "Disabled" ]; then
        echo "Step 9: Configuring SELinux..."
        chcon -R -t httpd_sys_content_t ${DOCROOT}
        chcon -R -t httpd_sys_rw_content_t ${DOCROOT}/api
        setsebool -P httpd_can_network_connect_db 1
        setsebool -P httpd_can_network_connect 1
    fi
fi

# =============================================================================
# START SERVICES
# =============================================================================
echo "Step 10: Starting Apache web server..."

# Enable Apache to start on boot
systemctl enable httpd

# Start (or restart) Apache to load new config
systemctl restart httpd

# Check status
systemctl status httpd --no-pager || true

# =============================================================================
# VERIFY DEPLOYMENT
# =============================================================================
echo "Step 11: Verifying deployment..."

# Test local web server
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Web server is responding correctly (HTTP $HTTP_CODE)"
else
    echo "✗ Web server returned HTTP $HTTP_CODE"
    echo "Check Apache logs: tail -f /var/log/httpd/error_log"
fi

# Test PHP
php -r "echo 'PHP is working\n';" || echo "PHP test failed"

# Test database connection
php -r "
\$host = '${DB_HOST}';
\$port = '${DB_PORT}';
\$db = '${DB_NAME}';
\$user = '${DB_USERNAME}';
\$pass = '${DB_PASSWORD}';
try {
    \$pdo = new PDO(\"mysql:host=\$host;port=\$port;dbname=\$db\", \$user, \$pass);
    echo \"✓ Database connection successful\n\";
} catch (PDOException \$e) {
    echo \"✗ Database connection failed: \" . \$e->getMessage() . \"\n\";
}
" || echo "Database connection test failed"

# =============================================================================
# CLEANUP
# =============================================================================
echo "Step 12: Cleaning up..."
rm -rf /tmp/food-ordering-system

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================
echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Document Root: ${DOCROOT}"
echo "Git Repository: ${GIT_REPO_URL}"
echo "Database Endpoint: ${DB_ENDPOINT}"
echo "Log File: ${LOG_FILE}"
echo ""
echo "Next Steps:"
echo "1. Check application in browser: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<EC2_PUBLIC_IP>')/"
echo "2. Review logs if needed:"
echo "   - Deployment log: tail -f ${LOG_FILE}"
echo "   - Apache error log: tail -f /var/log/httpd/error_log"
echo "   - Apache access log: tail -f /var/log/httpd/access_log"
echo ""
echo "Useful commands:"
echo "  - Restart Apache: sudo systemctl restart httpd"
echo "  - Check Apache status: sudo systemctl status httpd"
echo "  - Run migration manually: sudo ${DOCROOT}/scripts/migrate-php-db.sh '${DB_ENDPOINT}' '${DB_USERNAME}' '<PASSWORD>'"
echo "=========================================="
