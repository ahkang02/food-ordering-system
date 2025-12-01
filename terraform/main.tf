terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "food-ordering/tofu.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Food-Ordering-System"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  environment          = var.environment
  project_name         = var.project_name
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  bucket_name   = var.s3_bucket_name
  environment   = var.environment
  project_name  = var.project_name
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  environment            = var.environment
  project_name           = var.project_name
  vpc_security_group_ids = [module.vpc.vpc_default_security_group_id]
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  environment       = var.environment
  project_name      = var.project_name
}

# EC2 Autoscaling Module
module "ec2" {
  source = "./modules/ec2"

  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_target_group_arn  = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  instance_type         = var.instance_type
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  environment           = var.environment
  project_name          = var.project_name
  s3_bucket_name        = module.s3.bucket_name
  db_endpoint           = module.rds.db_endpoint
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  application_type      = var.application_type # "dotnet" or "php"
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment  = var.environment
  project_name = var.project_name
  alb_arn      = module.alb.alb_arn
  asg_name     = module.ec2.asg_name
}

# Outputs
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Application Load Balancer DNS name"
}

output "rds_endpoint" {
  value       = module.rds.db_endpoint
  description = "RDS endpoint"
  sensitive   = true
}

output "s3_bucket_name" {
  value       = module.s3.bucket_name
  description = "S3 bucket name"
}

