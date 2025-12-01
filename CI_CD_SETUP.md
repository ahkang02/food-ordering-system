# CI/CD Setup Guide

This guide explains how to set up CI/CD for the Food Ordering System using GitHub Actions and Terraform.

## Overview

The CI/CD pipeline includes:
1. **OpenTofu** - Infrastructure as Code (IaC) for AWS resources (Terraform-compatible)
2. **GitHub Actions** - Automated deployment workflows and CI pipeline
3. **AWS Resources** - VPC, EC2, RDS, ALB, S3, CloudWatch

## Prerequisites

1. AWS Account with Learner Lab access
2. GitHub Repository
3. AWS CLI configured locally (for initial setup)
4. OpenTofu installed locally (or Terraform)

## Step 1: Initial Infrastructure Setup

### 1.1 Configure OpenTofu Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region = "us-east-1"
db_username = "admin"
db_password = "your-secure-password"
s3_bucket_name = "your-unique-bucket-name-12345"
application_type = "dotnet"  # or "php"
```

### 1.2 Initialize and Apply OpenTofu

```bash
tofu init
tofu plan
tofu apply
```

### 1.3 Save OpenTofu Outputs

After applying, save these outputs:
```bash
tofu output -json > tofu-outputs.json
```

## Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `S3_BUCKET_NAME` | S3 bucket name | `food-ordering-deployments-12345` |
| `ASG_NAME` | Auto Scaling Group name | `food-ordering-production-asg` |
| `ALB_DNS_NAME` | ALB DNS name | `food-ordering-production-alb-123456789.us-east-1.elb.amazonaws.com` |
| `DB_ENDPOINT` | RDS endpoint | `food-ordering-production-db.xxxxx.us-east-1.rds.amazonaws.com` |
| `DB_USERNAME` | Database username | `admin` |
| `DB_PASSWORD` | Database password | `your-secure-password` |

## Step 3: GitHub Actions Workflows

### 3.1 CI Pipeline

The `ci.yml` workflow runs automatically on:
- Pull requests to main/master
- Pushes to main/master

It validates:
- .NET code compilation and tests
- PHP syntax validation
- Infrastructure (OpenTofu) validation
- Frontend code (if exists)
- Security scanning

### 3.2 Infrastructure Deployment

The `terraform-deploy.yml` workflow can be triggered manually:

1. Go to Actions tab
2. Select "Deploy Infrastructure with OpenTofu"
3. Click "Run workflow"
4. Choose action: `plan`, `apply`, or `destroy`

### 3.2 Application Deployment

#### For .NET Application:

The `dotnet-deploy.yml` workflow triggers on:
- Push to `main`/`master` branch when `dotnet-food-ordering/**` changes
- Manual trigger via workflow_dispatch

#### For PHP Application:

The `php-deploy.yml` workflow triggers on:
- Push to `main`/`master` branch when `php-food-ordering/**` changes
- Manual trigger via workflow_dispatch

## Step 4: Deployment Flow

### Infrastructure (First Time)

1. **OpenTofu Apply** - Creates all AWS resources
2. **Save Outputs** - Note ALB DNS, RDS endpoint, etc.
3. **Update GitHub Secrets** - Add all required secrets

### Application Deployment

1. **Code Push** - Developer pushes code to repository
2. **GitHub Actions Triggered** - Workflow runs automatically
3. **Build** - Application is built (.NET) or packaged (PHP)
4. **Upload to S3** - Deployment package uploaded to S3
5. **Deploy to EC2** - SSM commands deploy to all EC2 instances
6. **Health Check** - Verifies deployment success

## Step 5: Accessing Your Application

After deployment, access your application via the ALB DNS name:

```
http://food-ordering-production-alb-123456789.us-east-1.elb.amazonaws.com
```

For .NET: Direct access to the application
For PHP: Access via `/api/menu` endpoint

## Monitoring

### CloudWatch

- **Log Groups**: `/aws/ec2/food-ordering-production`
- **Alarms**: 
  - ALB response time
  - ALB unhealthy hosts
  - ASG CPU utilization

### View Logs

```bash
aws logs tail /aws/ec2/food-ordering-production --follow
```

## Troubleshooting

### Deployment Fails

1. Check GitHub Actions logs
2. Verify all secrets are set correctly
3. Check EC2 instance logs via SSM:
   ```bash
   aws ssm start-session --target <instance-id>
   ```

### Application Not Accessible

1. Check ALB target group health
2. Verify security groups allow traffic
3. Check EC2 instance status in Auto Scaling Group

### Database Connection Issues

1. Verify RDS is in private subnet
2. Check security group allows EC2 → RDS (port 3306)
3. Verify database credentials in GitHub secrets

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
tofu destroy
```

Or use GitHub Actions workflow with `destroy` action.

## Notes for AWS Learner Lab

- Some IAM permissions may be restricted
- Ensure you're within resource quotas
- Elastic IPs are required for NAT Gateways
- RDS must be in private subnets
- ALB requires public subnets

## Security Best Practices

1. **Never commit** `terraform.tfvars` or secrets
2. **Use GitHub Secrets** for all sensitive data
3. **Rotate credentials** regularly
4. **Enable MFA** on AWS account
5. **Use least privilege** IAM policies
6. **Enable CloudWatch logging** for audit trails

