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
# CREATE PLACEHOLDER APPLICATION
# =============================================================================
echo "Creating placeholder application..."

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
        .container { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; line-height: 1.6; }
        .status { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>🍕 Food Ordering System (.NET)</h1>
        <p class='status'>✓ Infrastructure Provisioned Successfully</p>
        <p>The server is ready and waiting for application deployment.</p>
        <p>To deploy the application, run the <strong>.NET Deploy</strong> workflow from GitHub Actions.</p>
        <hr>
        <p><small>Server Time: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + @"</small></p>
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
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
CSPROJ_EOF

# Build the placeholder app
cd "$APP_DIR"
dotnet build -c Release -o . 2>/dev/null || echo "Build skipped, will use systemd to manage"
chown -R ec2-user:ec2-user "$APP_DIR"

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
