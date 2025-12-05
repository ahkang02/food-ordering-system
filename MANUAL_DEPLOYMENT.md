# Manual EC2 Deployment Guide

This guide walks you through manually deploying the PHP food ordering application to an EC2 instance using git clone.

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
nano deploy-php-manual.sh
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
chmod +x deploy-php-manual.sh
sudo ./deploy-php-manual.sh
```

The script will:
1. Install all required packages (PHP, Apache, MySQL client, Git)
2. Configure Apache with mod_rewrite for .htaccess support
3. Clone the application from Git
4. Deploy files to `/var/www/html`
5. Configure database connection
6. Initialize database schema
7. Set proper permissions
8. Restart Apache service
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

# Install Apache
sudo dnf -y install httpd

# Install PHP and extensions
sudo dnf -y install php php-cli php-mysqlnd php-pdo php-mbstring php-json php-xml

# Install MySQL client
sudo dnf -y install mariadb105-server

# Install Git
sudo dnf -y install git
```

### 2. Configure Apache

```bash
# Create config for .htaccess support
sudo tee /etc/httpd/conf.d/foodordering.conf << 'EOF'
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
```

### 3. Clone and Deploy Application

```bash
# Clone repository
cd /tmp
git clone https://github.com/ahkang02/food-ordering-system.git

# Deploy to web root
sudo rm -rf /var/www/html/*
sudo cp -r food-ordering-system/php-food-ordering/* /var/www/html/

# Copy migration script
sudo mkdir -p /var/www/html/scripts
sudo cp food-ordering-system/scripts/migrate-php-db.sh /var/www/html/scripts/
sudo chmod +x /var/www/html/scripts/migrate-php-db.sh
```

### 4. Configure Database Connection

```bash
# Create database config file
sudo tee /var/www/html/api/db_config.php << 'EOF'
<?php
$_ENV['DB_HOST'] = 'your-rds-endpoint.rds.amazonaws.com';
$_ENV['DB_NAME'] = 'foodordering';
$_ENV['DB_USER'] = 'admin';
$_ENV['DB_PASS'] = 'your-password';
?>
EOF
```

### 5. Initialize Database

```bash
# Run migration script
sudo /var/www/html/scripts/migrate-php-db.sh \
  "your-rds-endpoint.rds.amazonaws.com" \
  "admin" \
  "your-password"
```

### 6. Set Permissions

```bash
# Set ownership
sudo chown -R apache:apache /var/www/html

# Set permissions
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Verify .htaccess exists
ls -la /var/www/html/.htaccess
```

### 7. Start Apache

```bash
# Enable and restart Apache (restart ensures new config is loaded)
sudo systemctl enable httpd
sudo systemctl restart httpd

# Check status
sudo systemctl status httpd
```

## Troubleshooting

### "URL Not Found" Error (Routing Issues)

This usually means Apache isn't processing `.htaccess`:

```bash
# Verify .htaccess exists
ls -la /var/www/html/.htaccess

# Verify Apache config has AllowOverride All
cat /etc/httpd/conf.d/foodordering.conf

# Restart Apache to reload config
sudo systemctl restart httpd
```

### Apache Won't Start

```bash
# Check Apache configuration
sudo apachectl configtest

# View error logs
sudo tail -f /var/log/httpd/error_log

# Check if port 80 is already in use
sudo netstat -tulpn | grep :80
```

### Database Connection Issues

```bash
# Test database connectivity
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Check security group rules
# Ensure RDS security group allows inbound from EC2 security group on port 3306

# Verify database config
cat /var/www/html/api/db_config.php
```

### Application Not Loading

```bash
# Check PHP errors
sudo tail -f /var/log/httpd/error_log

# Test PHP is working
php -v
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php
curl http://localhost/info.php

# Check file permissions
ls -la /var/www/html/
```

## Updating the Application

To update the application after initial deployment:

```bash
# SSH to EC2
ssh -i your-key.pem ec2-user@<EC2_IP>

# Pull latest changes
cd /tmp
rm -rf food-ordering-system
git clone https://github.com/ahkang02/food-ordering-system.git

# Deploy updated files
sudo cp -r food-ordering-system/php-food-ordering/* /var/www/html/

# Set permissions
sudo chown -R apache:apache /var/www/html
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Restart Apache
sudo systemctl restart httpd
```

## Useful Commands

### Service Management
```bash
# Restart Apache
sudo systemctl restart httpd

# Stop Apache
sudo systemctl stop httpd

# View Apache status
sudo systemctl status httpd
```

### Log Monitoring
```bash
# Apache error log
sudo tail -f /var/log/httpd/error_log

# Apache access log
sudo tail -f /var/log/httpd/access_log

# Deployment log (if using script)
sudo tail -f /var/log/manual-deployment.log
```

### Database Operations
```bash
# Connect to database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Run migration script
sudo /var/www/html/scripts/migrate-php-db.sh "<ENDPOINT>" "<USER>" "<PASS>"

# Export database
mysqldump -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering > backup.sql

# Import database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering < backup.sql
```

## Best Practices

1. **Always backup** before making changes
2. **Monitor logs** regularly for errors
3. **Keep packages updated** - run `sudo dnf update` regularly
4. **Use environment variables** for sensitive data instead of hardcoding
5. **Test locally first** before deploying to production
6. **Document any manual changes** you make to the server
