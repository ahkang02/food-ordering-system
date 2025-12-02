#!/bin/bash
# Force cleanup of resources that might be orphaned and blocking Terraform
# Usage: ./force-cleanup.sh

echo "Starting comprehensive force cleanup..."

# 1. Delete Auto Scaling Group (Critical first step to terminate instances)
echo "Checking Auto Scaling Group..."
ASG_NAME="food-ordering-production-asg"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null | grep -q "$ASG_NAME"
if [ $? -eq 0 ]; then
    echo "Deleting ASG: $ASG_NAME"
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --force-delete
    echo "Waiting for ASG deletion (this may take a few minutes)..."
    while aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" --query "AutoScalingGroups[0].AutoScalingGroupName" --output text 2>/dev/null | grep -q "$ASG_NAME"; do
        echo -n "."
        sleep 10
    done
    echo " ASG deleted."
else
    echo "ASG not found."
fi

# 2. Delete Launch Template
echo "Checking Launch Templates..."
LT_ID=$(aws ec2 describe-launch-templates --filters "Name=launch-template-name,Values=food-ordering-production-*" --query "LaunchTemplates[0].LaunchTemplateId" --output text 2>/dev/null)
if [ -n "$LT_ID" ] && [ "$LT_ID" != "None" ]; then
    echo "Deleting Launch Template: $LT_ID"
    aws ec2 delete-launch-template --launch-template-id "$LT_ID"
else
    echo "Launch Template not found."
fi

# 3. Delete Load Balancer
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

# 4. Delete Target Group
echo "Checking Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names food-ordering-production-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "Found Target Group: $TG_ARN"
    
    # Check if TG is used by any LBs (Listeners) - Double check
    LB_ARNS=$(aws elbv2 describe-target-groups --target-group-arns "$TG_ARN" --query "TargetGroups[0].LoadBalancerArns" --output text 2>/dev/null)
    if [ -n "$LB_ARNS" ] && [ "$LB_ARNS" != "None" ]; then
        echo "Target Group is used by Load Balancers: $LB_ARNS"
        for LB_ARN in $LB_ARNS; do
            echo "Deleting dependent Load Balancer: $LB_ARN"
            aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN"
            aws elbv2 wait load-balancers-deleted --load-balancer-arns "$LB_ARN"
        done
    fi

    echo "Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
else
    echo "Target Group not found."
fi

# 5. Delete RDS Instance
echo "Checking RDS Instance..."
aws rds delete-db-instance --db-instance-identifier food-ordering-production-db --skip-final-snapshot --delete-automated-backups 2>/dev/null
if [ $? -eq 0 ]; then
    echo "RDS deletion triggered."
else
    echo "RDS Instance not found or already deleting."
fi

# 6. Delete DB Subnet Group
echo "Checking DB Subnet Group..."
aws rds delete-db-subnet-group --db-subnet-group-name food-ordering-production-db-subnet-group 2>/dev/null
if [ $? -eq 0 ]; then
    echo "DB Subnet Group deleted."
else
    echo "DB Subnet Group not found or in use (wait for RDS deletion)."
fi

# 7. Delete Security Groups (Best effort, might fail if still in use)
echo "Checking Security Groups..."
SGS=("food-ordering-production-ec2-sg" "food-ordering-production-alb-sg" "food-ordering-production-default-sg")
for SG_NAME in "${SGS[@]}"; do
    SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
    if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
        echo "Deleting Security Group: $SG_NAME ($SG_ID)"
        aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || echo "Could not delete SG $SG_NAME (likely still in use)"
    fi
done

# 8. Delete CloudWatch Log Group
echo "Checking Log Group..."
aws logs delete-log-group --log-group-name /aws/ec2/food-ordering-production 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Log Group deleted."
else
    echo "Log Group not found."
fi

# 9. Delete S3 Bucket
echo "Checking S3 Bucket..."
BUCKET_NAME="bucket-food-ordering-123456" 
aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null
if [ $? -eq 0 ]; then
    echo "S3 Bucket deleted."
else
    echo "S3 Bucket not found."
fi

echo "---------------------------------------------------"
echo "Comprehensive cleanup commands issued."
echo "Note: RDS deletion is asynchronous and may take several minutes."
echo "Note: Security Groups might fail to delete if ENIs are still lingering (e.g. from deleting Load Balancers)."
