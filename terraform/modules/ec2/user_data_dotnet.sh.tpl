#!/bin/bash
set -euxo pipefail

# Verbose logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "user-data started at $(date -u +%FT%TZ)"
trap 'echo "user-data exited with $?" >> /var/log/user-data.log' EXIT

# 1. Install Dependencies
if command -v dnf >/dev/null 2>&1; then
  PKG_MGR=dnf
else
  PKG_MGR=yum
fi

$PKG_MGR -y makecache || true
$PKG_MGR -y install wget unzip tar gzip curl amazon-ssm-agent aspnetcore-runtime-8.0 nginx || true
systemctl enable --now amazon-ssm-agent
systemctl enable --now nginx

# 3. Download Artifact
# Try to pick up latest package from s3 prefix dotnet-deployments, else fallback to generic artifact
APP_DIR="/var/www/foodordering"
mkdir -p "$APP_DIR"
chown -R ec2-user:ec2-user "$APP_DIR"

TMP_ZIP="/tmp/foodordering.zip"

if command -v aws >/dev/null 2>&1; then
    # List objects in dotnet-deployments/ prefix, sort, and pick the last one (latest)
    LATEST_DEPLOYMENT=$(aws s3 ls s3://${s3_bucket_name}/dotnet-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}' || true)
    
    if [ -n "$LATEST_DEPLOYMENT" ]; then
        echo "Found latest deployment: $LATEST_DEPLOYMENT"
        aws s3 cp "s3://${s3_bucket_name}/$${LATEST_DEPLOYMENT}" "$TMP_ZIP" || true
    else
        echo "No deployments found in dotnet-deployments/, falling back to dotnet-published.zip"
        aws s3 cp "s3://${s3_bucket_name}/dotnet-published.zip" "$TMP_ZIP" || true
    fi
fi

if [ -f "$TMP_ZIP" ]; then
    unzip -o "$TMP_ZIP" -d "$APP_DIR"
    chown -R ec2-user:ec2-user "$APP_DIR"
    chmod +x "$APP_DIR/FoodOrdering"
fi

# 4. Create Systemd Service
cat > /etc/systemd/system/foodordering.service <<EOF
[Unit]
Description=Food Ordering .NET App
After=network.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/dotnet $APP_DIR/FoodOrdering.dll
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=foodordering
User=ec2-user
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000
Environment=ConnectionStrings__DefaultConnection="Server=${db_endpoint};Database=${db_name};User=${db_username};Password=${db_password};"

[Install]
WantedBy=multi-user.target
EOF

systemctl enable foodordering
systemctl start foodordering

# 5. Configure Nginx Reverse Proxy
cat > /etc/nginx/conf.d/foodordering.conf <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

# Remove default nginx config if it exists to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf

# Reload Nginx
systemctl restart nginx

echo "user-data script finished"
