# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  # Allow access from VPC default security group
  ingress {
    description     = "MySQL/Aurora from VPC default SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.vpc_security_group_ids
  }

  # Allow access from EC2 security group
  dynamic "ingress" {
    for_each = var.ec2_security_group_id != "" ? [1] : []
    content {
      description     = "MySQL/Aurora from EC2"
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [var.ec2_security_group_id]
    }
  }

  # Allow public access if enabled
  dynamic "ingress" {
    for_each = var.publicly_accessible ? [1] : []
    content {
      description = "MySQL/Aurora from allowed CIDR blocks"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  # Sandbox/Learner Lab optimizations
  multi_az                = false # Single AZ for cost savings
  backup_retention_period = 0     # Disable automated backups
  # backup_window         = "03:00-04:00" # Not needed when backups disabled
  # maintenance_window    = "mon:04:00-mon:05:00" # Optional

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Disable CloudWatch logs for cost savings (optional)
  # enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

