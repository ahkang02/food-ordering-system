# OpenTofu Infrastructure for Food Ordering System

This OpenTofu (Terraform-compatible) configuration provisions a complete AWS infrastructure for the food ordering system, suitable for AWS Learner Lab.

## Architecture

- **VPC** with 2 public and 2 private subnets across 2 availability zones
- **NAT Gateways** with Elastic IPs in public subnets
- **Application Load Balancer** in public subnets
- **EC2 Auto Scaling Group** in public subnets (2-4 instances)
- **RDS MySQL** in private subnets
- **S3 Bucket** for deployment artifacts
- **CloudWatch** for monitoring and logging

## Prerequisites

1. AWS CLI configured with credentials
2. OpenTofu >= 1.6 installed (or Terraform >= 1.0)
3. GitHub Secrets configured (see below)

## Setup

1. **Copy example variables file:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Edit terraform.tfvars** with your values:
```hcl
aws_region = "us-east-1"
db_username = "admin"
db_password = "your-secure-password"
s3_bucket_name = "your-unique-bucket-name"
application_type = "dotnet" # or "php"
```

3. **Initialize OpenTofu:**
```bash
cd terraform
tofu init
```

4. **Review the plan:**
```bash
tofu plan
```

5. **Apply the infrastructure:**
```bash
tofu apply
```

## GitHub Secrets Required

Add these secrets to your GitHub repository:

- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `S3_BUCKET_NAME` - S3 bucket name (from Terraform output)
- `ASG_NAME` - Auto Scaling Group name (from Terraform output)
- `ALB_DNS_NAME` - ALB DNS name (from Terraform output)
- `DB_ENDPOINT` - RDS endpoint (from Terraform output)
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password

## Outputs

After applying, OpenTofu will output:

- `alb_dns_name` - Use this to access your application
- `rds_endpoint` - Database endpoint (sensitive)
- `s3_bucket_name` - S3 bucket for deployments
- `vpc_id` - VPC ID

## Module Structure

- `modules/vpc` - VPC, subnets, NAT gateways, route tables
- `modules/rds` - RDS MySQL instance in private subnets
- `modules/alb` - Application Load Balancer
- `modules/ec2` - EC2 Auto Scaling Group with launch template
- `modules/s3` - S3 bucket for deployments
- `modules/cloudwatch` - CloudWatch alarms and log groups

## Notes for AWS Learner Lab

- Some IAM permissions may be restricted
- Ensure you're within resource limits
- Elastic IPs are provisioned for NAT Gateways (required for ALB)
- RDS is placed in private subnets for security

## Destroying Infrastructure

```bash
tofu destroy
```

**Warning:** This will delete all resources including RDS data!

