#!/bin/bash

# Update system
yum update -y

# Install common tools
yum install -y aws-cli unzip curl wget

if [ "${application_type}" = "dotnet" ]; then
    # Install .NET 9
    wget https://dot.net/v1/dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --channel 9.0
    export PATH=$PATH:$HOME/.dotnet

    # Create application directory
    mkdir -p /opt/food-ordering
    cd /opt/food-ordering

    # Download latest deployment from S3
    LATEST_DEPLOYMENT=$(aws s3 ls s3://${s3_bucket_name}/dotnet-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}')
    if [ ! -z "$LATEST_DEPLOYMENT" ]; then
        aws s3 cp s3://${s3_bucket_name}/$LATEST_DEPLOYMENT ./deployment-package.zip
        unzip -o deployment-package.zip -d ./current
    fi

    # Create systemd service
    cat > /etc/systemd/system/foodordering.service <<EOF
[Unit]
Description=Food Ordering API
After=network.target

[Service]
Type=notify
ExecStart=/root/.dotnet/dotnet /opt/food-ordering/current/FoodOrdering.dll --urls "http://0.0.0.0:80"
Restart=always
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ConnectionStrings__DefaultConnection="Server=${db_endpoint};Database=${db_name};User Id=${db_username};Password=${db_password};"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable foodordering
    systemctl start foodordering

elif [ "${application_type}" = "php" ]; then
    # Install PHP and Apache
    yum install -y php php-mysql php-json httpd

    # Create application directory
    mkdir -p /var/www/html/php-food-ordering
    cd /var/www/html/php-food-ordering

    # Download latest deployment from S3
    LATEST_DEPLOYMENT=$(aws s3 ls s3://${s3_bucket_name}/php-deployments/ --recursive | sort | tail -n 1 | awk '{print $4}')
    if [ ! -z "$LATEST_DEPLOYMENT" ]; then
        aws s3 cp s3://${s3_bucket_name}/$LATEST_DEPLOYMENT ./deployment-package.zip
        unzip -o deployment-package.zip
    fi

    # Configure PHP database connection
    cat > /var/www/html/php-food-ordering/api/db_config.php <<'PHPEOF'
<?php
$_ENV['DB_HOST'] = '${db_endpoint}';
$_ENV['DB_NAME'] = '${db_name}';
$_ENV['DB_USER'] = '${db_username}';
$_ENV['DB_PASS'] = '${db_password}';
?>
PHPEOF

    # Set permissions
    chown -R apache:apache /var/www/html/php-food-ordering
    chmod -R 755 /var/www/html/php-food-ordering

    # Configure Apache
    cat > /etc/httpd/conf.d/foodordering.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html/php-food-ordering
    
    <Directory /var/www/html/php-food-ordering>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

    systemctl enable httpd
    systemctl start httpd
fi

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/${application_type}-food-ordering",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "FoodOrdering/${application_type}",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ]
            }
        }
    }
}
EOF

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

