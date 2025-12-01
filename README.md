# Food Ordering System

A complete food ordering system with .NET Core 9 and PHP implementations, including full CI/CD pipeline and AWS infrastructure.

## Project Structure

```
food-ordering-system/
├── dotnet-food-ordering/     # .NET Core 9 full-stack application
├── php-food-ordering/        # PHP REST API
├── frontend/                 # Frontend web application
├── terraform/                # Infrastructure as Code (OpenTofu)
├── .github/                  # GitHub Actions workflows
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- .NET 9 SDK (for .NET application)
- PHP 7.4+ (for PHP application)
- OpenTofu 1.6+ or Terraform 1.0+ (for infrastructure)
- AWS Account with Learner Lab access

### Local Development

#### .NET Application

```bash
cd dotnet-food-ordering
dotnet restore
dotnet run
```

Access at: http://localhost:5000

#### PHP Application

```bash
cd php-food-ordering
php -S localhost:8000 -t .
```

Access at: http://localhost:8000/api/menu

#### Frontend

```bash
cd frontend
python3 -m http.server 8080
```

Access at: http://localhost:8080

### Infrastructure Deployment

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
tofu init
tofu plan
tofu apply
```

## Features

- 🍕 Menu browsing with category filters
- 🛒 Shopping cart functionality
- 💳 Checkout process (fake payment)
- 📦 Order confirmation
- 🗄️ Database integration (MySQL/PostgreSQL)
- ☁️ AWS infrastructure (VPC, EC2, RDS, ALB, S3, CloudWatch)
- 🚀 CI/CD pipeline with GitHub Actions
- 📊 CloudWatch monitoring

## Documentation

- [CI/CD Setup Guide](CI_CD_SETUP.md) - Complete CI/CD setup instructions
- [Infrastructure Summary](INFRASTRUCTURE_SUMMARY.md) - AWS infrastructure overview
- [Deployment Explained](DEPLOYMENT_EXPLAINED.md) - Deployment approach details
- [OpenTofu Setup](TOFU_SETUP.md) - OpenTofu installation and usage
- [Artifacts Documentation](.github/workflows/ARTIFACTS.md) - Artifact management

## GitHub Actions Workflows

- **CI Pipeline** (`.github/workflows/ci.yml`) - Validates code on PR/push
- **Infrastructure** (`.github/workflows/terraform-deploy.yml`) - Deploys AWS infrastructure
- **.NET Deployment** (`.github/workflows/dotnet-deploy.yml`) - Deploys .NET application
- **PHP Deployment** (`.github/workflows/php-deploy.yml`) - Deploys PHP application

## AWS Infrastructure

- VPC with 2 public and 2 private subnets
- Application Load Balancer
- EC2 Auto Scaling Group (2-4 instances)
- RDS MySQL in private subnets
- S3 bucket for deployments
- CloudWatch for monitoring

## License

Free to use and modify for your projects.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request
