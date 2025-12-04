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
install_if_missing httpd httpd || install_if_missing apache2 apache2 || true

# Install MySQL/MariaDB client for database migrations
echo "Installing MySQL client..."
$PKG_MGR -y install mariadb105 || $PKG_MGR -y install mysql || $PKG_MGR -y install mariadb || true

# Set document root
DOCROOT=/var/www/html
mkdir -p "$DOCROOT"
mkdir -p "$DOCROOT/api"
mkdir -p "$DOCROOT/scripts"

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
# START WEB SERVER
# =============================================================================
echo "Starting Apache web server..."

# Start web server
systemctl enable --now httpd || systemctl enable --now apache2 || true

echo "user-data script finished"

