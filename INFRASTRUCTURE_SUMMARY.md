# Infrastructure Summary

Complete CI/CD setup for Food Ordering System with AWS infrastructure.

## What's Included

### GitHub Actions Workflows

1. **`.github/workflows/dotnet-deploy.yml`**
   - Builds and deploys .NET Core 9 application
   - Uploads to S3
   - Deploys to EC2 via SSM
   - Health check validation

2. **`.github/workflows/php-deploy.yml`**
   - Packages PHP application
   - Uploads to S3
   - Deploys to EC2 via SSM
   - Health check validation

3. **`.github/workflows/terraform-deploy.yml`**
   - Terraform plan/apply/destroy
   - Infrastructure validation
   - Automated on push to main

### OpenTofu Infrastructure

#### Modules Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables
├── modules/
│   ├── vpc/                   # VPC, subnets, NAT gateways
│   ├── rds/                   # RDS MySQL in private subnets
│   ├── alb/                   # Application Load Balancer
│   ├── ec2/                   # EC2 Auto Scaling Group
│   ├── s3/                    # S3 bucket for deployments
│   └── cloudwatch/            # CloudWatch alarms & logs
```

**Note:** Uses OpenTofu (Terraform-compatible) for infrastructure management.

#### Infrastructure Components

1. **VPC Module**
   - VPC with DNS support
   - 2 Public subnets (across 2 AZs)
   - 2 Private subnets (across 2 AZs)
   - Internet Gateway
   - 2 NAT Gateways with Elastic IPs
   - Route tables and associations

2. **RDS Module**
   - MySQL 8.0 instance
   - Placed in private subnets
   - Security group for EC2 access
   - Automated backups enabled

3. **ALB Module**
   - Application Load Balancer
   - Target group with health checks
   - HTTP listener (port 80)
   - Security group for public access

4. **EC2 Module**
   - Auto Scaling Group (2-4 instances)
   - Launch template with user data
   - IAM role for S3/SSM/CloudWatch access
   - Security group for ALB traffic
   - Supports both .NET and PHP

5. **S3 Module**
   - Deployment bucket
   - Versioning enabled
   - Encryption at rest
   - Lifecycle policies

6. **CloudWatch Module**
   - Log groups
   - Alarms for ALB metrics
   - Alarms for ASG CPU

## Quick Start

### 1. Initial Setup

```bash
# Configure OpenTofu
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy infrastructure
tofu init
tofu plan
tofu apply
```

### 2. Configure GitHub Secrets

Add these to GitHub → Settings → Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET_NAME` (from terraform output)
- `ASG_NAME` (from terraform output)
- `ALB_DNS_NAME` (from terraform output)
- `DB_ENDPOINT` (from terraform output)
- `DB_USERNAME`
- `DB_PASSWORD`

### 3. Deploy Application

Push code to trigger GitHub Actions, or manually run workflow.

## Architecture Diagram

```
Internet
   │
   ▼
[Application Load Balancer] (Public Subnets)
   │
   ├───► [EC2 Instance 1] (Public Subnet 1)
   │         │
   │         └───► [RDS MySQL] (Private Subnet 1)
   │
   └───► [EC2 Instance 2] (Public Subnet 2)
             │
             └───► [RDS MySQL] (Private Subnet 2)

[S3 Bucket] ──► Deployment Artifacts
[CloudWatch] ──► Monitoring & Logs
```

## Key Features

✅ **High Availability**: Multi-AZ deployment
✅ **Auto Scaling**: EC2 instances scale based on demand
✅ **Security**: RDS in private subnets, security groups
✅ **Monitoring**: CloudWatch alarms and logs
✅ **CI/CD**: Automated deployments via GitHub Actions
✅ **Infrastructure as Code**: Terraform modules
✅ **Elastic IPs**: For NAT Gateways (required for ALB)

## File Structure

```
.
├── .github/
│   └── workflows/
│       ├── dotnet-deploy.yml
│       ├── php-deploy.yml
│       └── terraform-deploy.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/
│       ├── rds/
│       ├── alb/
│       ├── ec2/
│       ├── s3/
│       └── cloudwatch/
├── dotnet-food-ordering/
├── php-food-ordering/
└── CI_CD_SETUP.md
```

## Notes

- **AWS Learner Lab**: Some IAM restrictions may apply
- **Elastic IPs**: Required for NAT Gateways (ALB requirement)
- **Database**: RDS in private subnets for security
- **Deployments**: Stored in S3, deployed via SSM
- **Monitoring**: CloudWatch for logs and metrics

## Next Steps

1. Review `CI_CD_SETUP.md` for detailed setup instructions
2. Configure GitHub Secrets
3. Run Terraform to provision infrastructure
4. Push code to trigger deployments
5. Access application via ALB DNS name

