# Manual EC2 Deployment Guide

This guide walks you through manually deploying the PHP food ordering application to an EC2 instance.

## Prerequisites

Before you begin, ensure you have:

1. ✅ **EC2 Instance Running** - Amazon Linux 2023 recommended
2. ✅ **RDS Database** - MySQL instance created and accessible
3. ✅ **S3 Bucket** - For storing application files
4. ✅ **Security Groups** - Properly configured (see below)
5. ✅ **SSH Access** - Key pair to connect to EC2
6. ✅ **IAM Role** - EC2 instance profile with S3 read access

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

## Step-by-Step Deployment

### Step 1: Prepare Your Application Package

On your local machine, create a deployment package:

```bash
# Navigate to the PHP application directory
cd /Users/zhihong/food-ordering-system/php-food-ordering

# Create a zip file of all application files
zip -r php-published.zip . -x "*.git*" -x "*.DS_Store"

# Verify the zip contains the necessary files
unzip -l php-published.zip | grep -E "(index.php|database-schema.sql|api/)"
```

### Step 2: Upload to S3

```bash
# Set your bucket name
export S3_BUCKET="bucket-food-ordering-123456"

# Upload the package
aws s3 cp php-published.zip s3://${S3_BUCKET}/php-published.zip

# Verify upload
aws s3 ls s3://${S3_BUCKET}/
```

### Step 3: Connect to EC2 Instance

```bash
# Replace with your key file and instance IP
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

### Step 4: Download and Run Deployment Script

On the EC2 instance:

```bash
# Download the deployment script from S3 (if you uploaded it)
aws s3 cp s3://${S3_BUCKET}/deploy-php-manual.sh ./deploy-php-manual.sh

# OR create it manually using the provided script
# (Copy the content from deploy-php-manual.sh)

# Make it executable
chmod +x deploy-php-manual.sh

# Edit the configuration section with your values
sudo nano deploy-php-manual.sh
```

**Update these variables in the script:**
```bash
S3_BUCKET_NAME="your-bucket-name"
DB_ENDPOINT="your-rds-endpoint.rds.amazonaws.com"
DB_NAME="foodordering"
DB_USERNAME="admin"
DB_PASSWORD="your-secure-password"
```

### Step 5: Run the Deployment

```bash
# Run the script with sudo
sudo ./deploy-php-manual.sh
```

The script will:
1. Install all required packages (PHP, Apache, MySQL client, AWS CLI)
2. Configure Apache web server
3. Download application from S3
4. Extract files to `/var/www/html`
5. Configure database connection
6. Initialize database schema
7. Set proper permissions
8. Start Apache service
9. Verify deployment

### Step 6: Verify Deployment

After the script completes, verify the deployment:

```bash
# Check Apache is running
sudo systemctl status httpd

# Test local web server
curl http://localhost/

# Check application files
ls -la /var/www/html/

# View Apache logs
sudo tail -f /var/log/httpd/error_log
```

### Step 7: Access Your Application

Open a browser and navigate to:
```
http://<EC2_PUBLIC_IP>/
```

## Manual Deployment (Without Script)

If you prefer to deploy manually without the script, follow these steps:

### 1. Install Required Packages

```bash
# Update system
sudo dnf -y update

# Install Apache
sudo dnf -y install httpd

# Install PHP and extensions
sudo dnf -y install php php-cli php-mysqlnd php-pdo php-mbstring php-json php-xml

# Install MySQL client
sudo dnf -y install mysql

# Install AWS CLI (if not present)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configure Apache

```bash
# Enable .htaccess support
sudo bash -c 'cat >> /etc/httpd/conf/httpd.conf <<EOF

<Directory "/var/www/html">
    AllowOverride All
    Require all granted
</Directory>
EOF'
```

### 3. Download Application

```bash
# Set your bucket name
export S3_BUCKET="bucket-food-ordering-123456"

# Download from S3
cd /tmp
aws s3 cp s3://${S3_BUCKET}/php-published.zip ./php-published.zip

# Extract to web root
sudo rm -rf /var/www/html/*
sudo unzip -o php-published.zip -d /var/www/html/
```

### 4. Configure Database Connection

```bash
# Create database config file
sudo bash -c 'cat > /var/www/html/api/db_config.php <<EOF
<?php
\$_ENV["DB_HOST"] = "your-rds-endpoint.rds.amazonaws.com";
\$_ENV["DB_NAME"] = "foodordering";
\$_ENV["DB_USER"] = "admin";
\$_ENV["DB_PASS"] = "your-password";
?>
EOF'
```

### 5. Initialize Database

```bash
# Apply database schema
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p < /var/www/html/database-schema.sql
```

### 6. Set Permissions

```bash
# Set ownership
sudo chown -R apache:apache /var/www/html

# Set permissions
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Configure SELinux (if enabled)
sudo chcon -R -t httpd_sys_content_t /var/www/html
sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/api
sudo setsebool -P httpd_can_network_connect_db 1
sudo setsebool -P httpd_can_network_connect 1
```

### 7. Start Apache

```bash
# Enable and start Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# Check status
sudo systemctl status httpd
```

## Troubleshooting

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

### S3 Download Fails

```bash
# Check IAM role is attached to EC2
aws sts get-caller-identity

# Verify bucket access
aws s3 ls s3://your-bucket-name/

# Check bucket policy allows EC2 role to read
```

## Updating the Application

To update the application after initial deployment:

```bash
# 1. Upload new version to S3
aws s3 cp php-published.zip s3://${S3_BUCKET}/php-deployments/php-$(date +%Y%m%d-%H%M%S).zip

# 2. SSH to EC2
ssh -i your-key.pem ec2-user@<EC2_IP>

# 3. Download and extract new version
cd /tmp
aws s3 cp s3://${S3_BUCKET}/php-deployments/php-YYYYMMDD-HHMMSS.zip ./update.zip
sudo unzip -o update.zip -d /var/www/html/

# 4. Set permissions
sudo chown -R apache:apache /var/www/html
sudo find /var/www/html -type f -exec chmod 644 {} \;

# 5. Restart Apache
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

### File Management
```bash
# List web files
ls -la /var/www/html/

# Check disk space
df -h

# Find large files
sudo du -sh /var/www/html/*
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
2. **Use version-controlled deployments** - timestamp your S3 uploads
3. **Monitor logs** regularly for errors
4. **Keep packages updated** - run `sudo dnf update` regularly
5. **Use environment variables** for sensitive data instead of hardcoding
6. **Test locally first** before deploying to production
7. **Document any manual changes** you make to the server

## Next Steps

After successful deployment:

1. Set up SSL/TLS certificate (use AWS Certificate Manager + ALB)
2. Configure CloudWatch monitoring
3. Set up automated backups for RDS
4. Implement log rotation
5. Configure auto-scaling if needed
6. Set up a deployment pipeline (GitHub Actions)
