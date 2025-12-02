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

# 5. Delete NAT Gateways (must be before EIP release)
echo "Checking NAT Gateways..."
NAT_GW_IDS=$(aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=food-ordering-production-nat-*" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null)
if [ -n "$NAT_GW_IDS" ]; then
    for NAT_ID in $NAT_GW_IDS; do
        echo "Deleting NAT Gateway: $NAT_ID"
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" 2>/dev/null || echo "Could not delete NAT Gateway $NAT_ID"
    done
    
    echo "Waiting for NAT Gateways to be deleted (this may take a few minutes)..."
    sleep 30
    while aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_IDS --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null | grep -q "nat-"; do
        echo -n "."
        sleep 10
    done
    echo " NAT Gateways deleted."
else
    echo "NAT Gateways not found."
fi

# 6. Release Elastic IPs (must be after NAT Gateway deletion)
echo "Checking Elastic IPs..."
EIP_ALLOC_IDS=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=food-ordering-production-eip-*" --query "Addresses[].AllocationId" --output text 2>/dev/null)
if [ -n "$EIP_ALLOC_IDS" ]; then
    for ALLOC_ID in $EIP_ALLOC_IDS; do
        echo "Releasing Elastic IP: $ALLOC_ID"
        aws ec2 release-address --allocation-id "$ALLOC_ID" 2>/dev/null || echo "Could not release EIP $ALLOC_ID (may still be associated)"
    done
else
    echo "No tagged Elastic IPs found."
fi

# Also check for untagged EIPs associated with our project
echo "Checking for untagged Elastic IPs..."
UNTAGGED_EIPS=$(aws ec2 describe-addresses --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null)
if [ -n "$UNTAGGED_EIPS" ]; then
    echo "Found unassociated EIPs (potential orphans): $UNTAGGED_EIPS"
    echo "To release them manually, run: aws ec2 release-address --allocation-id <ALLOC_ID>"
fi

# 7. Delete RDS Instance
echo "Checking RDS Instance..."
RDS_EXISTS=$(aws rds describe-db-instances --db-instance-identifier food-ordering-production-db --query "DBInstances[0].DBInstanceIdentifier" --output text 2>/dev/null)
if [ -n "$RDS_EXISTS" ] && [ "$RDS_EXISTS" != "None" ]; then
    echo "Deleting RDS Instance: food-ordering-production-db"
    aws rds delete-db-instance --db-instance-identifier food-ordering-production-db --skip-final-snapshot --delete-automated-backups 2>/dev/null
    
    echo "Waiting for RDS deletion (this may take 5-10 minutes)..."
    while aws rds describe-db-instances --db-instance-identifier food-ordering-production-db --query "DBInstances[0].DBInstanceIdentifier" --output text 2>/dev/null | grep -q "food-ordering-production-db"; do
        echo -n "."
        sleep 15
    done
    echo " RDS deleted."
else
    echo "RDS Instance not found."
fi

# 8. Delete RDS Security Group
echo "Checking RDS Security Group..."
RDS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=food-ordering-production-rds-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
if [ -n "$RDS_SG_ID" ] && [ "$RDS_SG_ID" != "None" ]; then
    echo "Deleting RDS Security Group: $RDS_SG_ID"
    aws ec2 delete-security-group --group-id "$RDS_SG_ID" 2>/dev/null || echo "Could not delete RDS SG (may still be in use)"
else
    echo "RDS Security Group not found."
fi

# 9. Delete DB Subnet Group (must be after RDS deletion)
echo "Checking DB Subnet Group..."
DB_SUBNET_GROUP=$(aws rds describe-db-subnet-groups --db-subnet-group-name food-ordering-production-db-subnet-group --query "DBSubnetGroups[0].DBSubnetGroupName" --output text 2>/dev/null)
if [ -n "$DB_SUBNET_GROUP" ] && [ "$DB_SUBNET_GROUP" != "None" ]; then
    echo "Deleting DB Subnet Group: food-ordering-production-db-subnet-group"
    aws rds delete-db-subnet-group --db-subnet-group-name food-ordering-production-db-subnet-group 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "DB Subnet Group deleted."
    else
        echo "DB Subnet Group deletion failed (may still be in use)."
    fi
else
    echo "DB Subnet Group not found."
fi

# 10. Delete Security Groups (Best effort, might fail if still in use)
echo "Checking Security Groups..."
SGS=("food-ordering-production-ec2-sg" "food-ordering-production-alb-sg" "food-ordering-production-default-sg")
for SG_NAME in "${SGS[@]}"; do
    SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
    if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
        echo "Deleting Security Group: $SG_NAME ($SG_ID)"
        aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || echo "Could not delete SG $SG_NAME (likely still in use)"
    fi
done

# 11. Delete CloudWatch Log Group
echo "Checking Log Group..."
aws logs delete-log-group --log-group-name /aws/ec2/food-ordering-production 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Log Group deleted."
else
    echo "Log Group not found."
fi

# 12. Delete S3 Bucket
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

# 13. Delete VPC (this will auto-delete IGW, route tables, subnets, and release EIPs)
echo "Checking VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=food-ordering-production-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null)
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "Found VPC: $VPC_ID"
    
    # First, detach and delete Internet Gateway
    echo "Checking Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)
    if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
        echo "Detaching and deleting Internet Gateway: $IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || echo "Could not detach IGW"
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null || echo "Could not delete IGW"
    fi
    
    # Delete subnets
    echo "Checking Subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text 2>/dev/null)
    if [ -n "$SUBNET_IDS" ]; then
        for SUBNET_ID in $SUBNET_IDS; do
            echo "Deleting Subnet: $SUBNET_ID"
            aws ec2 delete-subnet --subnet-id "$SUBNET_ID" 2>/dev/null || echo "Could not delete subnet $SUBNET_ID (may still be in use)"
        done
    fi
    
    # Delete route tables (except main)
    echo "Checking Route Tables..."
    RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null)
    if [ -n "$RT_IDS" ]; then
        for RT_ID in $RT_IDS; do
            echo "Deleting Route Table: $RT_ID"
            aws ec2 delete-route-table --route-table-id "$RT_ID" 2>/dev/null || echo "Could not delete route table $RT_ID"
        done
    fi
    
    # Finally delete VPC
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "VPC deleted successfully."
    else
        echo "VPC deletion failed (may have dependencies still attached)."
        echo "Check for remaining ENIs: aws ec2 describe-network-interfaces --filters \"Name=vpc-id,Values=$VPC_ID\""
    fi
else
    echo "VPC not found."
fi

# Final check for any remaining Elastic IPs
echo "Final check for remaining Elastic IPs..."
REMAINING_EIPS=$(aws ec2 describe-addresses --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null)
if [ -n "$REMAINING_EIPS" ]; then
    echo "⚠️  Found remaining unassociated EIPs: $REMAINING_EIPS"
    echo "These should have been released with VPC deletion."
    echo "To manually release: aws ec2 release-address --allocation-id <ALLOC_ID>"
else
    echo "✓ No remaining unassociated Elastic IPs found."
fi

echo "---------------------------------------------------"
echo "Cleanup complete!"
echo "You can now run 'terraform apply' again."
