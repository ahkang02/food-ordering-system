# Copy this file to terraform.tfvars and fill in your values
# terraform.tfvars is in .gitignore and should not be committed

aws_region = "us-east-1"
environment = "production"
project_name = "food-ordering"

vpc_cidr = "10.0.0.0/16"

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
db_name = "foodordering"
db_username = "admin"
db_password = ""

# EC2 Configuration
instance_type = "t3.micro"
min_size = 2
max_size = 4
desired_capacity = 2

# S3 Configuration
s3_bucket_name = "bucket-food-ordering-123456"

# Application Type
application_type = "dotnet" # or "php"

