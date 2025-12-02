#!/bin/bash
set -euxo pipefail

# Remediation script to run on an EC2 instance (via SSH or SSM) to restore the FoodOrdering app
# Usage: copy to instance and run as root or via sudo.

if command -v dnf >/dev/null 2>&1; then
  PKG_MGR=dnf
else
  PKG_MGR=yum
fi

echo "Installing network tools (wget, curl, unzip)"
$PKG_MGR -y install wget curl unzip tar gzip || $PKG_MGR -y --allowerasing install wget curl unzip tar gzip || $PKG_MGR -y --skip-broken install wget curl unzip tar gzip || true

echo "Installing dotnet (channel 9)"
DOTNET_DIR=/opt/dotnet
mkdir -p "$DOTNET_DIR"
curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 9.0 --install-dir "$DOTNET_DIR"
echo "export PATH=$DOTNET_DIR:\$PATH" > /etc/profile.d/dotnet.sh
export PATH=$DOTNET_DIR:$PATH

APP_DIR=/opt/foodordering
TMP_ZIP=/tmp/foodordering.zip

echo "Attempting to fetch artifact"
if command -v aws >/dev/null 2>&1; then
  aws s3 cp s3://$1/foodordering-published.zip "$TMP_ZIP" || true
fi
if [ ! -f "$TMP_ZIP" ]; then
  # If no S3 bucket or awscli, try HTTP using bucket name passed as $1
  if [ -n "$1" ]; then
    curl -fsSL --retry 5 "https://s3.amazonaws.com/$1/foodordering-published.zip" -o "$TMP_ZIP" || true
  fi
fi

mkdir -p "$APP_DIR"
if [ -f "$TMP_ZIP" ]; then
  unzip -o "$TMP_ZIP" -d "$APP_DIR"
fi

echo "Ensure systemd unit exists and restart service"
if [ ! -f /etc/systemd/system/foodordering.service ]; then
  cat >/etc/systemd/system/foodordering.service <<'EOF'
[Unit]
Description=Food Ordering API
After=network.target

[Service]
WorkingDirectory=/opt/foodordering
ExecStart=/opt/dotnet/dotnet /opt/foodordering/FoodOrdering.dll
Restart=on-failure
User=ec2-user
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable --now foodordering.service || systemctl start foodordering.service || true

echo "Remediation complete. Check service status:"
systemctl status foodordering.service --no-pager
journalctl -u foodordering.service -n 200 --no-pager || true
