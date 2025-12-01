# GitHub Actions Workflows

This directory contains CI/CD workflows for the Food Ordering System.

## Workflows

### 1. `ci.yml` - Continuous Integration

**Triggers:**
- Pull requests to main/master
- Pushes to main/master

**Jobs:**
- **dotnet-ci**: Builds and tests .NET application
- **php-ci**: Validates PHP syntax
- **infrastructure-ci**: Validates OpenTofu configuration
- **frontend-ci**: Lints frontend code (if exists)
- **security-scan**: Runs Trivy vulnerability scanner

**Purpose:** Validates code quality before merging/deploying.

### 2. `terraform-deploy.yml` - Infrastructure Deployment

**Triggers:**
- Manual workflow dispatch
- Push to main (when terraform/ changes)

**Actions:**
- `plan` - Preview infrastructure changes
- `apply` - Deploy infrastructure
- `destroy` - Remove infrastructure

**Purpose:** Manages AWS infrastructure using OpenTofu.

### 3. `dotnet-deploy.yml` - .NET Application Deployment

**Triggers:**
- Push to main/master (when dotnet-food-ordering/ changes)
- Manual workflow dispatch

**Steps:**
1. Build .NET application
2. Upload to S3
3. Deploy to EC2 via SSM
4. Health check

**Purpose:** Deploys .NET Core 9 application to EC2.

### 4. `php-deploy.yml` - PHP Application Deployment

**Triggers:**
- Push to main/master (when php-food-ordering/ changes)
- Manual workflow dispatch

**Steps:**
1. Package PHP application
2. Upload to S3
3. Deploy to EC2 via SSM
4. Health check

**Purpose:** Deploys PHP application to EC2.

## Required GitHub Secrets

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET_NAME`
- `ASG_NAME`
- `ALB_DNS_NAME`
- `DB_ENDPOINT`
- `DB_USERNAME`
- `DB_PASSWORD`

## Workflow Dependencies

```
CI Pipeline (ci.yml)
    ↓
Infrastructure (terraform-deploy.yml)
    ↓
Application Deployment (dotnet-deploy.yml / php-deploy.yml)
```

## Usage

### Run CI Checks
```bash
# Automatically runs on PR/push
# Or manually trigger from Actions tab
```

### Deploy Infrastructure
1. Go to Actions → "Deploy Infrastructure with OpenTofu"
2. Click "Run workflow"
3. Select action: plan/apply/destroy

### Deploy Application
```bash
# Automatically runs on push to main
# Or manually trigger from Actions tab
```

