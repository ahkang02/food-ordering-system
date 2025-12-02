# Manual EC2 Deployment Guide - .NET/C# Application

This guide walks you through manually deploying the .NET/C# food ordering application to an EC2 instance.

## Prerequisites

Before you begin, ensure you have:

1. ✅ **EC2 Instance Running** - Amazon Linux 2023 recommended
2. ✅ **RDS Database** - MySQL instance created and accessible
3. ✅ **S3 Bucket** - For storing application files
4. ✅ **Security Groups** - Properly configured (see below)
5. ✅ **SSH Access** - Key pair to connect to EC2
6. ✅ **IAM Role** - EC2 instance profile with S3 read access
7. ✅ **.NET 8 SDK** - On your local machine for building the application

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

### Step 1: Build and Package Your Application

On your local machine:

```bash
# Navigate to the .NET application directory
cd /Users/zhihong/food-ordering-system/dotnet-food-ordering

# Clean previous builds
dotnet clean

# Restore dependencies
dotnet restore

# Publish the application for Linux x64
dotnet publish -c Release -r linux-x64 --self-contained false -o ./publish

# Verify the publish directory
ls -la ./publish/
# Should contain: FoodOrdering.dll, appsettings.json, wwwroot/, etc.

# Copy database schema to publish directory
cp database-schema.sql ./publish/

# Create a zip file of the published application
cd publish
zip -r ../dotnet-published.zip .
cd ..

# Verify the zip
unzip -l dotnet-published.zip | head -20
```

### Step 2: Upload to S3

```bash
# Set your bucket name
export S3_BUCKET="bucket-food-ordering-123456"

# Upload the package
aws s3 cp dotnet-published.zip s3://${S3_BUCKET}/dotnet-published.zip

# Or upload with timestamp for versioning
aws s3 cp dotnet-published.zip s3://${S3_BUCKET}/dotnet-deployments/dotnet-$(date +%Y%m%d-%H%M%S).zip

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
aws s3 cp s3://${S3_BUCKET}/deploy-dotnet-manual.sh ./deploy-dotnet-manual.sh

# OR create it manually using the provided script
# (Copy the content from deploy-dotnet-manual.sh)

# Make it executable
chmod +x deploy-dotnet-manual.sh

# Edit the configuration section with your values
sudo nano deploy-dotnet-manual.sh
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
sudo ./deploy-dotnet-manual.sh
```

The script will:
1. Install all required packages (.NET 8 Runtime, Nginx, MySQL client, AWS CLI)
2. Download application from S3
3. Extract files to `/var/www/foodordering`
4. Initialize database schema
5. Create systemd service for the .NET application
6. Configure Nginx as reverse proxy
7. Start all services
8. Verify deployment

### Step 6: Verify Deployment

After the script completes, verify the deployment:

```bash
# Check .NET application is running
sudo systemctl status foodordering

# Check Nginx is running
sudo systemctl status nginx

# Test local application
curl http://localhost:5000/

# Test through Nginx
curl http://localhost/

# View application logs
sudo journalctl -u foodordering -n 50

# View Nginx logs
sudo tail -f /var/log/nginx/error.log
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

# Install .NET 8 ASP.NET Core Runtime
sudo dnf -y install aspnetcore-runtime-8.0

# Install Nginx
sudo dnf -y install nginx

# Install MySQL client
sudo dnf -y install mysql

# Install AWS CLI (if not present)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installations
dotnet --version
nginx -v
```

### 2. Prepare Application Directory

```bash
# Create application directory
sudo mkdir -p /var/www/foodordering
sudo chown -R ec2-user:ec2-user /var/www/foodordering
```

### 3. Download Application

```bash
# Set your bucket name
export S3_BUCKET="bucket-food-ordering-123456"

# Download from S3
cd /tmp
aws s3 cp s3://${S3_BUCKET}/dotnet-published.zip ./dotnet-published.zip

# Extract to application directory
sudo unzip -o dotnet-published.zip -d /var/www/foodordering/
sudo chown -R ec2-user:ec2-user /var/www/foodordering/

# Make executable (if needed)
sudo chmod +x /var/www/foodordering/FoodOrdering
```

### 4. Initialize Database

```bash
# Apply database schema
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p < /var/www/foodordering/database-schema.sql
```

### 5. Create Systemd Service

```bash
# Create service file
sudo bash -c 'cat > /etc/systemd/system/foodordering.service <<EOF
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
EOF'

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable foodordering
sudo systemctl start foodordering

# Check status
sudo systemctl status foodordering
```

### 6. Configure Nginx

```bash
# Create Nginx configuration
sudo bash -c 'cat > /etc/nginx/conf.d/foodordering.conf <<EOF
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
EOF'

# Remove default config
sudo rm -f /etc/nginx/conf.d/default.conf

# Test configuration
sudo nginx -t

# Enable and start Nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx
```

### 7. Configure SELinux (if enabled)

```bash
# Check if SELinux is enabled
getenforce

# If enabled, configure it
sudo setsebool -P httpd_can_network_connect 1
sudo chcon -R -t httpd_sys_content_t /var/www/foodordering
```

## Troubleshooting

### .NET Application Won't Start

```bash
# Check service status
sudo systemctl status foodordering

# View detailed logs
sudo journalctl -u foodordering -n 100 --no-pager

# Check if port 5000 is in use
sudo netstat -tulpn | grep :5000

# Test .NET runtime
dotnet --info

# Manually run the application to see errors
cd /var/www/foodordering
dotnet FoodOrdering.dll
```

### Nginx Issues

```bash
# Test Nginx configuration
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/error.log

# Check if Nginx is running
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx
```

### Database Connection Issues

```bash
# Test database connectivity
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Check connection string in service file
sudo cat /etc/systemd/system/foodordering.service | grep ConnectionStrings

# View application logs for database errors
sudo journalctl -u foodordering | grep -i "database\|mysql\|connection"
```

### Application Not Loading

```bash
# Check if .NET app is responding
curl http://localhost:5000/

# Check if Nginx is proxying correctly
curl http://localhost/

# View all logs
sudo journalctl -u foodordering -f &
sudo tail -f /var/log/nginx/error.log
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
# 1. Build and publish new version locally
cd /Users/zhihong/food-ordering-system/dotnet-food-ordering
dotnet publish -c Release -r linux-x64 --self-contained false -o ./publish
cd publish
zip -r ../dotnet-published.zip .

# 2. Upload to S3 with timestamp
aws s3 cp ../dotnet-published.zip s3://${S3_BUCKET}/dotnet-deployments/dotnet-$(date +%Y%m%d-%H%M%S).zip

# 3. SSH to EC2
ssh -i your-key.pem ec2-user@<EC2_IP>

# 4. Stop the application
sudo systemctl stop foodordering

# 5. Download and extract new version
cd /tmp
aws s3 cp s3://${S3_BUCKET}/dotnet-deployments/dotnet-YYYYMMDD-HHMMSS.zip ./update.zip
sudo unzip -o update.zip -d /var/www/foodordering/
sudo chown -R ec2-user:ec2-user /var/www/foodordering/

# 6. Start the application
sudo systemctl start foodordering

# 7. Check status
sudo systemctl status foodordering
```

## Useful Commands

### Service Management
```bash
# Restart .NET application
sudo systemctl restart foodordering

# Stop .NET application
sudo systemctl stop foodordering

# View .NET app status
sudo systemctl status foodordering

# Restart Nginx
sudo systemctl restart nginx

# View Nginx status
sudo systemctl status nginx
```

### Log Monitoring
```bash
# .NET application logs (real-time)
sudo journalctl -u foodordering -f

# .NET application logs (last 100 lines)
sudo journalctl -u foodordering -n 100

# Nginx error log
sudo tail -f /var/log/nginx/error.log

# Nginx access log
sudo tail -f /var/log/nginx/access.log

# Deployment log (if using script)
sudo tail -f /var/log/manual-deployment.log
```

### Application Management
```bash
# Check .NET processes
ps aux | grep dotnet

# Check listening ports
sudo netstat -tulpn | grep -E ':(80|5000)'

# Test application endpoint
curl -v http://localhost:5000/

# Check disk space
df -h

# Check application directory size
du -sh /var/www/foodordering/
```

### Database Operations
```bash
# Connect to database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p

# Run migrations (if using EF Core)
cd /var/www/foodordering
dotnet ef database update

# Export database
mysqldump -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering > backup.sql

# Import database
mysql -h your-rds-endpoint.rds.amazonaws.com -u admin -p foodordering < backup.sql
```

## Performance Tuning

### Nginx Configuration

Edit `/etc/nginx/nginx.conf` for production:

```nginx
worker_processes auto;
worker_connections 1024;

http {
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;
    
    # Client body size limit
    client_max_body_size 10M;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
```

### .NET Application Configuration

Edit `/etc/systemd/system/foodordering.service`:

```ini
# Add environment variables for performance
Environment=DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
Environment=DOTNET_RUNNING_IN_CONTAINER=false
Environment=DOTNET_EnableDiagnostics=0

# Adjust memory limits if needed
MemoryLimit=512M
```

## Best Practices

1. **Always backup** before making changes
2. **Use version-controlled deployments** - timestamp your S3 uploads
3. **Monitor logs** regularly for errors
4. **Keep packages updated** - run `sudo dnf update` regularly
5. **Use environment variables** for sensitive data
6. **Test locally first** before deploying to production
7. **Document any manual changes** you make to the server
8. **Set up health checks** for the application
9. **Configure log rotation** to prevent disk space issues
10. **Use HTTPS** in production (configure SSL/TLS)

## Next Steps

After successful deployment:

1. Set up SSL/TLS certificate (use AWS Certificate Manager + ALB)
2. Configure CloudWatch monitoring
3. Set up automated backups for RDS
4. Implement log rotation and aggregation
5. Configure auto-scaling if needed
6. Set up a CI/CD pipeline (GitHub Actions)
7. Implement health check endpoints
8. Configure application insights/monitoring
9. Set up alerts for application errors
10. Document your deployment process

## Additional Resources

- [ASP.NET Core deployment documentation](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/)
- [Nginx reverse proxy guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Systemd service documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [AWS EC2 best practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)
