# Manual EC2 Deployment Guide - .NET/C# Application

This guide walks you through manually deploying the .NET/C# food ordering application to an EC2 instance using git clone.

## Prerequisites

Before you begin, ensure you have:

1. ✅ **EC2 Instance Running** - Amazon Linux 2023 recommended
2. ✅ **RDS Database** - MySQL instance created and accessible
3. ✅ **Security Groups** - Properly configured (see below)
4. ✅ **SSH Access** - Key pair to connect to EC2

## Security Group Requirements

### EC2 Security Group
- **Inbound Rules:**
  - Port 22 (SSH) from your IP
  - Port 80 (HTTP) from 0.0.0.0/0 or ALB security group
  - Port 443 (HTTPS) from 0.0.0.0/0 or ALB security group (optional)
- **Outbound Rules:**
  - All traffic to 0.0.0.0/0

### RDS Security Group
- **Inbound Rules:**
  - Port 3306 (MySQL) from EC2 security group

## Quick Deployment (Recommended)

### Step 1: Connect to EC2 Instance

```bash
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

### Step 2: Clone Repository and Run Script

```bash
# Install git if not present
sudo dnf install -y git

# Clone the repository
cd /tmp
git clone https://github.com/ahkang02/food-ordering-system.git
cd food-ordering-system

# Edit the deployment script with your database credentials
nano deploy-dotnet-manual.sh
```

**Update these variables in the script:**
```bash
GIT_REPO_URL="https://github.com/ahkang02/food-ordering-system.git"
DB_ENDPOINT="your-rds-endpoint.rds.amazonaws.com"
DB_NAME="foodordering"
DB_USERNAME="admin"
DB_PASSWORD="your-secure-password"
```

### Step 3: Run the Deployment

```bash
chmod +x deploy-dotnet-manual.sh
sudo ./deploy-dotnet-manual.sh
```

The script will:
1. Install all required packages (.NET 8 SDK/Runtime, Nginx, MySQL client, Git)
2. Clone the application from Git
3. Build and publish the .NET application
4. Deploy files to `/var/www/foodordering`
5. Initialize database schema
6. Create systemd service for the .NET application
7. Configure Nginx as reverse proxy
8. Start all services
9. Verify deployment

### Step 4: Access Your Application

Open a browser and navigate to:
```
http://<EC2_PUBLIC_IP>/
```

## Manual Deployment (Without Script)

If you prefer to deploy step-by-step:

### 1. Install Required Packages

```bash
# Update system
sudo dnf -y update

# Install .NET 8 SDK and Runtime
sudo dnf -y install dotnet-sdk-8.0 aspnetcore-runtime-8.0

# Install Nginx
sudo dnf -y install nginx

# Install MySQL client
sudo dnf -y install mariadb105-server

# Install Git
sudo dnf -y install git

# Verify installations
dotnet --version
nginx -v
```

### 2. Clone and Build Application

```bash
# Clone repository
cd /tmp
git clone https://github.com/ahkang02/food-ordering-system.git
cd food-ordering-system/dotnet-food-ordering

# Restore dependencies
dotnet restore

# Publish the application
dotnet publish -c Release -o /tmp/dotnet-publish
```

### 3. Deploy Application

```bash
# Create application directory
sudo mkdir -p /var/www/foodordering
sudo chown -R ec2-user:ec2-user /var/www/foodordering

# Copy published files
cp -r /tmp/dotnet-publish/* /var/www/foodordering/

# Copy database schema
cp database-schema.sql /var/www/foodordering/
```

### 4. Initialize Database

```bash
# Connect to RDS and apply schema
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering < /var/www/foodordering/database-schema.sql
```

### 5. Create Systemd Service

```bash
sudo tee /etc/systemd/system/foodordering.service << 'EOF'
[Unit]
Description=Food Ordering .NET Application
After=network.target

[Service]
WorkingDirectory=/var/www/foodordering
ExecStart=/usr/bin/dotnet /var/www/foodordering/FoodOrdering.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=foodordering
User=ec2-user
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000
Environment=ConnectionStrings__DefaultConnection="Server=your-rds-endpoint.rds.amazonaws.com;Database=foodordering;User=admin;Password=your-password;"

[Install]
WantedBy=multi-user.target
EOF

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable foodordering
sudo systemctl start foodordering

# Check status
sudo systemctl status foodordering
```

### 6. Configure Nginx

```bash
sudo tee /etc/nginx/conf.d/foodordering.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default config
sudo rm -f /etc/nginx/conf.d/default.conf

# Test and restart
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```

## Troubleshooting

### .NET Application Won't Start

```bash
# Check service status
sudo systemctl status foodordering

# View detailed logs
sudo journalctl -u foodordering -n 100 --no-pager

# Manually run to see errors
cd /var/www/foodordering
dotnet FoodOrdering.dll
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```

### Database Connection Issues

```bash
# Test connectivity
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Check connection string in service
sudo cat /etc/systemd/system/foodordering.service | grep ConnectionStrings
```

## Updating the Application

```bash
# SSH to EC2
ssh -i your-key.pem ec2-user@<EC2_IP>

# Stop application
sudo systemctl stop foodordering

# Clone and rebuild
cd /tmp
rm -rf food-ordering-system
git clone https://github.com/ahkang02/food-ordering-system.git
cd food-ordering-system/dotnet-food-ordering
dotnet publish -c Release -o /tmp/dotnet-publish

# Deploy
cp -r /tmp/dotnet-publish/* /var/www/foodordering/

# Restart
sudo systemctl start foodordering
sudo systemctl status foodordering
```

## Useful Commands

### Service Management
```bash
# Restart .NET application
sudo systemctl restart foodordering

# View .NET app logs
sudo journalctl -u foodordering -f

# Restart Nginx
sudo systemctl restart nginx
```

### Log Monitoring
```bash
# .NET application logs
sudo journalctl -u foodordering -n 100

# Nginx error log
sudo tail -f /var/log/nginx/error.log

# Nginx access log
sudo tail -f /var/log/nginx/access.log
```

### Database Operations
```bash
# Connect to database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Export database
mysqldump -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering > backup.sql

# Import database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering < backup.sql
```

## Best Practices

1. **Always backup** before making changes
2. **Monitor logs** regularly for errors
3. **Keep packages updated** - run `sudo dnf update` regularly
4. **Use environment variables** for sensitive data
5. **Test locally first** before deploying to production
6. **Document any manual changes** you make to the server
