output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_eip.app.public_ip
}

output "ec2_instance_id" {
  description = "Instance ID of EC2"
  value       = aws_instance.app.id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.deployments.bucket
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}"
}
