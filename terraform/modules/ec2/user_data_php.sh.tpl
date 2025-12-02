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

# Artifact fallback key (shell-only variable)
ARTIFACT_KEY=php-published.zip
ARTIFACT_S3="s3://${s3_bucket_name}/$${ARTIFACT_KEY}"
ARTIFACT_HTTP="https://s3.amazonaws.com/${s3_bucket_name}/$${ARTIFACT_KEY}"

TMP_ZIP=/tmp/foodordering.zip
fetch_artifact() {
    # Try aws cli first (instance role), fall back to HTTP
    if command -v aws >/dev/null 2>&1; then
        set +e
        aws s3 cp "$ARTIFACT_S3" "$TMP_ZIP"
        RES=$?
        set -e
        if [ $RES -eq 0 ] && [ -s "$TMP_ZIP" ]; then
            echo "Downloaded artifact from S3"
            return 0
        fi
        echo "aws s3 cp failed or artifact empty (exit $RES), falling back to HTTP"
    fi
    curl -fsSL --retry 5 "$ARTIFACT_HTTP" -o "$TMP_ZIP" || return 1
}


# PHP deployment
DOCROOT=/var/www/html
mkdir -p "$DOCROOT"
cd "$DOCROOT"

# Try to pick up latest package from s3 prefix php-deployments, else fallback to generic php artifact
if command -v aws >/dev/null 2>&1; then
    LATEST_DEPLOYMENT=$(aws s3 ls s3://${s3_bucket_name}/php-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}' || true)
    if [ -n "$LATEST_DEPLOYMENT" ]; then
        aws s3 cp "s3://${s3_bucket_name}/$${LATEST_DEPLOYMENT}" ./deployment-package.zip || true
        if [ -f ./deployment-package.zip ]; then
            unzip -o ./deployment-package.zip -d "$DOCROOT"
        fi
    fi
fi

# Fallback: try generic artifact key
if [ ! -f "$DOCROOT/index.php" ]; then
    if fetch_artifact; then
        unzip -o "$TMP_ZIP" -d "$DOCROOT"
    fi
fi

# Install PHP + Apache if missing (adjust package names if your AMI differs)
install_if_missing php php
install_if_missing httpd httpd || install_if_missing apache2 apache2 || true

# Configure DB settings
cat > $${DOCROOT}/api/db_config.php <<'PHPEOF'
<?php
$_ENV['DB_HOST'] = '${db_endpoint}';
$_ENV['DB_NAME'] = '${db_name}';
$_ENV['DB_USER'] = '${db_username}';
$_ENV['DB_PASS'] = '${db_password}';
?>
PHPEOF

chown -R apache:apache "$DOCROOT" || chown -R www-data:www-data "$DOCROOT" || true
chmod -R 755 "$DOCROOT"

# Start web server
systemctl enable --now httpd || systemctl enable --now apache2 || true

echo "user-data script finished"

