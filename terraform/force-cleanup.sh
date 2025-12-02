#!/bin/bash
# Force cleanup of resources that might be orphaned and blocking Terraform
# Usage: ./force-cleanup.sh

echo "Starting force cleanup of orphaned resources..."

# 1. Delete Load Balancer
echo "Checking ALB..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names food-ordering-production-alb --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    echo "Deleting ALB: $ALB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
    echo "Waiting for ALB deletion..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN"
else
    echo "ALB not found."
fi

# 2. Delete Target Group
echo "Checking Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names food-ordering-production-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
else
    echo "Target Group not found."
fi

# 3. Delete RDS Instance
echo "Checking RDS Instance..."
aws rds delete-db-instance --db-instance-identifier food-ordering-production-db --skip-final-snapshot --delete-automated-backups 2>/dev/null
if [ $? -eq 0 ]; then
    echo "RDS deletion triggered."
else
    echo "RDS Instance not found or already deleting."
fi

# 4. Delete DB Subnet Group
echo "Checking DB Subnet Group..."
aws rds delete-db-subnet-group --db-subnet-group-name food-ordering-production-db-subnet-group 2>/dev/null
if [ $? -eq 0 ]; then
    echo "DB Subnet Group deleted."
else
    echo "DB Subnet Group not found or in use (wait for RDS deletion)."
fi

# 5. Delete CloudWatch Log Group
echo "Checking Log Group..."
aws logs delete-log-group --log-group-name /aws/ec2/food-ordering-production 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Log Group deleted."
else
    echo "Log Group not found."
fi

# 6. Delete S3 Bucket
echo "Checking S3 Bucket..."
# Note: Replace with your actual bucket name if different
BUCKET_NAME="bucket-food-ordering-123456" 
aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null
if [ $? -eq 0 ]; then
    echo "S3 Bucket deleted."
else
    echo "S3 Bucket not found."
fi

echo "---------------------------------------------------"
echo "Cleanup commands issued."
echo "Note: RDS deletion is asynchronous and may take several minutes."
echo "If 'terraform apply' still fails on DB Subnet Group, wait a few minutes and try again."
