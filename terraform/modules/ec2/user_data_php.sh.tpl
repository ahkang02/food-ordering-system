#!/bin/bash
set -euxo pipefail

# Verbose logging for debugging: capture stdout/stderr to /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1
echo "user-data started at $(date -u +%FT%TZ)"
trap 'echo "user-data exited with $?" >> /var/log/user-data.log' EXIT

# PHP-only cloud-init / user-data script for Amazon Linux 2023
# Template variables injected by Terraform: ${application_type}, ${db_endpoint}, ${db_name}, ${db_username}, ${db_password}, ${s3_bucket_name}

if command -v dnf >/dev/null 2>&1; then
  PKG_MGR=dnf
else
  PKG_MGR=yum
fi

# Refresh metadata (best-effort)
$PKG_MGR -y makecache || true

# Helper: install a package only if binary doesn't exist
install_if_missing() {
    local binary="$1" pkg="$2"
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "Installing $pkg because $binary not found"
        $PKG_MGR -y install "$pkg" || $PKG_MGR -y --allowerasing install "$pkg" || $PKG_MGR -y --skip-broken install "$pkg" || true
    else
        echo "$binary already present, skipping $pkg"
    fi
}

# Ensure basic tooling exists without forcing package replacements
install_if_missing wget wget
install_if_missing unzip unzip
install_if_missing tar tar
install_if_missing gzip gzip
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found, attempting to install curl"
    $PKG_MGR -y install curl || $PKG_MGR -y --allowerasing install curl || $PKG_MGR -y --skip-broken install curl || true
else
    echo "curl present"
fi

# Ensure SSM agent is present and running
if ! systemctl list-units --full -all | grep -q amazon-ssm-agent; then
    echo "amazon-ssm-agent not detected; attempting to install"
    $PKG_MGR -y install amazon-ssm-agent || true
fi
systemctl enable --now amazon-ssm-agent || true

# =============================================================================
# INSTALL PHP AND APACHE
# =============================================================================
echo "Installing PHP and Apache..."

# Install PHP + Apache
install_if_missing php php
install_if_missing php-mysqlnd php-mysqlnd
install_if_missing php-pdo php-pdo
install_if_missing httpd httpd || install_if_missing apache2 apache2 || true

# Install MySQL/MariaDB client for database migrations
# Install MySQL/MariaDB client and server for database migrations
echo "Installing MariaDB server and client..."
# Install mariadb105-server explicitly as requested to ensure all tools are present
$PKG_MGR -y install mariadb105-server || $PKG_MGR -y install mariadb-server || $PKG_MGR -y install mysql-server || true

# Start MariaDB service (client might need socket or config present)
systemctl enable --now mariadb || systemctl enable --now mysql || true

# Secure installation (optional but good practice, though we mostly need the client)
# We just need it running so the 'mysql' command works reliably if it depends on local configs

# Set document root
DOCROOT=/var/www/html
mkdir -p "$DOCROOT"
mkdir -p "$DOCROOT/api"
mkdir -p "$DOCROOT/scripts"

# =============================================================================
# CREATE MIGRATION SCRIPT (embedded so it exists at boot time)
# =============================================================================
echo "Creating embedded migration script..."
cat > "$DOCROOT/scripts/migrate-php-db.sh" << 'MIGRATE_SCRIPT_EOF'
#!/bin/bash
set -e

echo "=== PHP Database Migration Script ==="

# Accept command-line arguments OR environment variables
if [ -n "$1" ]; then
    DB_ENDPOINT="$1"
fi
if [ -n "$2" ]; then
    DB_USERNAME="$2"
fi
if [ -n "$3" ]; then
    DB_PASSWORD="$3"
fi

# Check required variables
if [ -z "$DB_ENDPOINT" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required database credentials not set"
    echo "Usage: $0 <DB_ENDPOINT> <DB_USERNAME> <DB_PASSWORD>"
    exit 1
fi

DB_NAME="foodordering"
SCHEMA_FILE="/var/www/html/database-schema.sql"

echo "Database: $DB_NAME"
echo "Endpoint: $DB_ENDPOINT"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Warning: Schema file not found at $SCHEMA_FILE"
    echo "Skipping schema import - will be done after deployment"
    exit 0
fi

# Parse endpoint
DB_HOST="$${DB_ENDPOINT%%:*}"
DB_PORT="$${DB_ENDPOINT##*:}"
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="3306"
fi

echo "Host: $DB_HOST, Port: $DB_PORT"

# Test database connection
echo "Testing database connection..."
if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "Error: Cannot connect to database"
    exit 1
fi

echo "Connection successful!"

# Create database if it doesn't exist
echo "Creating database if not exists..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Check if tables already exist
TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D "$DB_NAME" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';")

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "Database already has $TABLE_COUNT tables. Skipping schema import."
else
    echo "Importing schema from $SCHEMA_FILE..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < "$SCHEMA_FILE"
    echo "Schema imported successfully!"
fi

echo "=== Migration completed ==="
MIGRATE_SCRIPT_EOF

chmod +x "$DOCROOT/scripts/migrate-php-db.sh"
echo "Migration script created at $DOCROOT/scripts/migrate-php-db.sh"

# =============================================================================
# DEPLOY APPLICATION FROM S3
# =============================================================================
echo "Checking for latest deployment in S3..."

S3_BUCKET="${s3_bucket_name}"
LATEST_PACKAGE="s3://$S3_BUCKET/php-deployments/latest.zip"

if aws s3 ls "$LATEST_PACKAGE" > /dev/null 2>&1; then
    echo "Found latest.zip in S3, deploying application..."
    
    # Download and extract
    aws s3 cp "$LATEST_PACKAGE" /tmp/latest.zip
    unzip -o /tmp/latest.zip -d "$DOCROOT"
    rm -f /tmp/latest.zip
    
    # Configure database credentials
    if [ -f "$DOCROOT/api/db_config.php" ]; then
        echo "Configuring database connection..."
        sed -i "s|__DB_ENDPOINT__|${db_endpoint}|g" "$DOCROOT/api/db_config.php"
        sed -i "s|__DB_NAME__|${db_name}|g" "$DOCROOT/api/db_config.php"
        sed -i "s|__DB_USERNAME__|${db_username}|g" "$DOCROOT/api/db_config.php"
        sed -i "s|__DB_PASSWORD__|${db_password}|g" "$DOCROOT/api/db_config.php"
    fi
    
    echo "Application deployed from S3!"
else
    echo "No latest.zip found in S3 - creating placeholder page..."
    cat > "$DOCROOT/index.php" <<'PLACEHOLDER_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Food Ordering System</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
        .container { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; line-height: 1.6; }
        .status { color: #FF9800; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🍕 Food Ordering System</h1>
        <p class="status">⏳ Waiting for First Deployment</p>
        <p>Infrastructure is ready. Run the <strong>Deploy PHP Application</strong> workflow to deploy.</p>
        <hr>
        <p><small>Server Time: <?php echo date('Y-m-d H:i:s'); ?></small></p>
    </div>
</body>
</html>
PLACEHOLDER_EOF
fi

# =============================================================================
# SET PERMISSIONS
# =============================================================================
echo "Setting permissions..."

chown -R apache:apache "$DOCROOT" || chown -R www-data:www-data "$DOCROOT" || true
chmod -R 755 "$DOCROOT"

# =============================================================================
# CONFIGURE APACHE FOR URL REWRITING
# =============================================================================
echo "Configuring Apache for mod_rewrite..."

# Enable mod_rewrite (Amazon Linux 2023 / RHEL)
if [ -f /etc/httpd/conf.modules.d/00-base.conf ]; then
    # mod_rewrite should already be enabled, but ensure it
    grep -q "LoadModule rewrite_module" /etc/httpd/conf.modules.d/00-base.conf || \
        echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /etc/httpd/conf.modules.d/00-base.conf
fi

# Configure AllowOverride for .htaccess
cat > /etc/httpd/conf.d/foodordering.conf << 'APACHE_CONF'
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
APACHE_CONF

echo "Apache configured for URL rewriting"

# =============================================================================
# START WEB SERVER
# =============================================================================
echo "Starting Apache web server..."

# Start web server
systemctl enable --now httpd || systemctl enable --now apache2 || true

echo "user-data script finished"

