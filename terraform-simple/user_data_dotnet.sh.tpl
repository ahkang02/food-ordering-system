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

# Install packages individually to avoid conflicts
$PKG_MGR -y install wget unzip tar gzip || true
$PKG_MGR -y install amazon-ssm-agent || true
$PKG_MGR -y install aspnetcore-runtime-8.0 --allowerasing || $PKG_MGR -y install aspnetcore-runtime-8.0 || true
$PKG_MGR -y install nginx --allowerasing || $PKG_MGR -y install nginx || true

systemctl enable --now amazon-ssm-agent || true
systemctl enable --now nginx || true

# =============================================================================
# PREPARE APPLICATION DIRECTORY
# =============================================================================
echo "Preparing application directory..."

APP_DIR="/var/www/foodordering"
mkdir -p "$APP_DIR"
chown -R ec2-user:ec2-user "$APP_DIR"

# =============================================================================
# DEPLOY APPLICATION FROM S3
# =============================================================================
echo "Checking for latest deployment in S3..."

S3_BUCKET="${s3_bucket_name}"
LATEST_PACKAGE="s3://$S3_BUCKET/dotnet-deployments/latest.zip"

if aws s3 ls "$LATEST_PACKAGE" > /dev/null 2>&1; then
    echo "Found latest.zip in S3, deploying application..."
    
    # Download and extract
    aws s3 cp "$LATEST_PACKAGE" /tmp/latest.zip
    unzip -o /tmp/latest.zip -d "$APP_DIR"
    rm -f /tmp/latest.zip
    
    chown -R ec2-user:ec2-user "$APP_DIR"
    chmod +x "$APP_DIR/FoodOrdering" 2>/dev/null || true
    
    echo "Application deployed from S3!"
else
    echo "No latest.zip found in S3 - creating placeholder..."
    
    # Create minimal placeholder
    cat > "$APP_DIR/Program.cs" <<'DOTNET_EOF'
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Content(@"
<!DOCTYPE html>
<html>
<head>
    <title>Food Ordering System</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
        .container { background: white; padding: 40px; border-radius: 8px; max-width: 600px; margin: 0 auto; }
        .status { color: #FF9800; font-weight: bold; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>🍕 Food Ordering System (.NET)</h1>
        <p class='status'>⏳ Waiting for First Deployment</p>
        <p>Run the <strong>Deploy .NET Application</strong> workflow to deploy.</p>
    </div>
</body>
</html>
", "text/html"));

app.Run();
DOTNET_EOF

    cat > "$APP_DIR/FoodOrdering.csproj" <<'CSPROJ_EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <NullableP>enable</NullableP>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
CSPROJ_EOF

    # Build the placeholder app
    cd "$APP_DIR"
    dotnet build -c Release -o . 2>/dev/null || echo "Build skipped"
    chown -R ec2-user:ec2-user "$APP_DIR"
fi

# =============================================================================
# CREATE SYSTEMD SERVICE
# =============================================================================
echo "Creating systemd service..."
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
