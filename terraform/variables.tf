variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "food-ordering"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "foodordering"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Cheapest, free tier eligible
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1 # Minimum for cost savings
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 2 # Reduced for cost savings
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 1 # Start with 1 instance
}

variable "s3_bucket_name" {
  description = "S3 bucket name for deployments"
  type        = string
}

variable "application_type" {
  description = "Application type: 'dotnet' or 'php'"
  type        = string
  default     = "dotnet"
  validation {
    condition     = contains(["dotnet", "php"], var.application_type)
    error_message = "Application type must be either 'dotnet' or 'php'."
  }
}

