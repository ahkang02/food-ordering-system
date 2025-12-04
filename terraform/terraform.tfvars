# Copy this file to terraform.tfvars and fill in your values
# terraform.tfvars is in .gitignore and should not be committed

aws_region   = "us-east-1"
environment  = "production"
project_name = "food-ordering"

vpc_cidr = "10.0.0.0/16"

# Database Configuration (Minimum cost)
db_instance_class    = "db.t3.micro" # Smallest RDS instance
db_allocated_storage = 20            # Minimum allowed for gp3

# EC2 Configuration (Minimum cost for learner lab)
instance_type    = "t2.micro" # Cheapest instance type (free tier eligible)
min_size         = 1          # Minimum 1 instance
max_size         = 2          # Maximum 2 instances
desired_capacity = 1          # Start with just 1 instance

# S3 Configuration
s3_bucket_name = "bucket-food-ordering-123456"

# Application Type
application_type = "php" # or "dotnet"
