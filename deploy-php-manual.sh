#!/bin/bash
# =============================================================================
# Manual PHP Application Deployment Script for EC2
# =============================================================================
# This script sets up the complete PHP food ordering application on an EC2 instance
# Run this after SSH'ing into your EC2 instance
#
# Prerequisites:
# 1. Upload php-food-ordering files to S3 bucket as php-published.zip
# 2. Have RDS endpoint, database name, username, and password ready
# 3. EC2 instance should have IAM role with S3 read access
#
# Usage:
#   chmod +x deploy-php-manual.sh
#   sudo ./deploy-php-manual.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# =============================================================================
S3_BUCKET_NAME="bucket-food-ordering-123456"  # Your S3 bucket name
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

# Install MySQL client for database operations
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
# INSTALL PHP AND APACHE
# =============================================================================
echo "Step 2: Installing PHP and Apache..."

# Install Apache
$PKG_MGR -y install httpd

# Install PHP and required extensions
echo "Installing PHP and extensions..."
$PKG_MGR -y install php php-cli php-mysqlnd php-pdo php-mbstring php-json php-xml

# Verify installations
php --version
httpd -v

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

# Enable mod_rewrite for .htaccess support
cat >> /etc/httpd/conf/httpd.conf <<'APACHE_EOF'

# Food Ordering Application Configuration
<Directory "/var/www/html">
    AllowOverride All
    Require all granted
</Directory>
APACHE_EOF

# =============================================================================
# DOWNLOAD APPLICATION FROM S3
# =============================================================================
echo "Step 4: Downloading application from S3..."

cd /tmp

# Try to get the latest deployment package
LATEST_DEPLOYMENT=$(aws s3 ls s3://${S3_BUCKET_NAME}/php-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}' || true)

if [ -n "$LATEST_DEPLOYMENT" ]; then
    echo "Found latest deployment: $LATEST_DEPLOYMENT"
    aws s3 cp "s3://${S3_BUCKET_NAME}/${LATEST_DEPLOYMENT}" ./deployment-package.zip
    PACKAGE_FILE="deployment-package.zip"
else
    echo "No deployment found in php-deployments/, trying generic artifact..."
    aws s3 cp "s3://${S3_BUCKET_NAME}/php-published.zip" ./php-published.zip
    PACKAGE_FILE="php-published.zip"
fi

# =============================================================================
# EXTRACT APPLICATION FILES
# =============================================================================
echo "Step 5: Extracting application files..."

# Extract application (will overwrite existing files)
unzip -o "/tmp/${PACKAGE_FILE}" -d ${DOCROOT}

# Verify extraction
if [ ! -f "${DOCROOT}/index.php" ]; then
    echo "ERROR: index.php not found after extraction!"
    exit 1
fi

echo "Application files extracted successfully"
ls -la ${DOCROOT}

# =============================================================================
# CONFIGURE DATABASE CONNECTION
# =============================================================================
echo "Step 6: Configuring database connection..."

S3_BUCKET_NAME="bucket-food-ordering-123456"  # Your S3 bucket name
DB_ENDPOINT="food-ordering-production-db.cpxf6cp2lxyo.us-east-1.rds.amazonaws.com"  # RDS endpoint
DB_NAME="foodordering"
DB_USERNAME="admin"
DB_PASSWORD="Admin1234!!"  # Your RDS password

# Create api directory if it doesn't exist
mkdir -p ${DOCROOT}/api

# Create database configuration file
cat > ${DOCROOT}/api/db_config.php <<PHPEOF
<?php
// Database configuration - Auto-generated by deployment script
\$_ENV['DB_HOST'] = 'food-ordering-production-db.cpxf6cp2lxyo.us-east-1.rds.amazonaws.com';
\$_ENV['DB_NAME'] = 'foodordering';
\$_ENV['DB_USER'] = 'admin';
\$_ENV['DB_PASS'] = 'Admin1234!!';
?>
PHPEOF

echo "Database configuration created"

# =============================================================================
# INITIALIZE DATABASE SCHEMA
# =============================================================================
echo "Step 7: Initializing database schema..."

# Check if database schema file exists
if [ -f "database-schema.sql" ]; then
    echo "Applying database schema..."
    mysql -h food-ordering-production-db.cpxf6cp2lxyo.us-east-1.rds.amazonaws.com -u admin -p Admin1234!! < ${DOCROOT}/database-schema.sql
    echo "Database schema applied successfully"
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

# Make sure .htaccess is readable
if [ -f "${DOCROOT}/.htaccess" ]; then
    chmod 644 ${DOCROOT}/.htaccess
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

# Start Apache
systemctl start httpd

# Check status
systemctl status httpd --no-pager

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
\$host = '${DB_ENDPOINT}';
\$db = '${DB_NAME}';
\$user = '${DB_USERNAME}';
\$pass = '${DB_PASSWORD}';
try {
    \$pdo = new PDO(\"mysql:host=\$host;dbname=\$db\", \$user, \$pass);
    echo \"✓ Database connection successful\n\";
} catch (PDOException \$e) {
    echo \"✗ Database connection failed: \" . \$e->getMessage() . \"\n\";
}
" || echo "Database connection test failed"

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================
echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETED"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Document Root: ${DOCROOT}"
echo "Database Endpoint: ${DB_ENDPOINT}"
echo "Log File: ${LOG_FILE}"
echo ""
echo "Next Steps:"
echo "1. Check application in browser: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"
echo "2. Review logs if needed:"
echo "   - Deployment log: tail -f ${LOG_FILE}"
echo "   - Apache error log: tail -f /var/log/httpd/error_log"
echo "   - Apache access log: tail -f /var/log/httpd/access_log"
echo ""
echo "Useful commands:"
echo "  - Restart Apache: sudo systemctl restart httpd"
echo "  - Check Apache status: sudo systemctl status httpd"
echo "  - View PHP info: echo '<?php phpinfo(); ?>' | sudo tee ${DOCROOT}/info.php"
echo "=========================================="
