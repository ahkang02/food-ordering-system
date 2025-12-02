Reprovisioning and remediation notes for EC2 FoodOrdering instances

1) Update your Launch Template / Auto Scaling Group user-data

- Edit `terraform/modules/ec2/user_data.sh.tpl` to use the new, robust user-data (already updated in this repo).
- Re-apply Terraform (or update your launch template in the console) so the ASG uses the corrected user-data.

2) Replace/terminate the failing instance

- If using Auto Scaling Group, terminate the failing instance in the EC2 console — the ASG will launch a replacement using the updated launch template.
- If using a stand-alone instance, stop and start (or create a new instance with the updated user-data) depending on your provisioning method.

3) In-place remediation (if you prefer to fix the existing instance)

- Copy `scripts/remediate_ec2_instance.sh` to the instance and run with sudo, or run via SSM Run Command.
- Example (SSH):
  sudo su -
  curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/remediate_ec2_instance.sh -o /tmp/remediate_ec2_instance.sh
  chmod +x /tmp/remediate_ec2_instance.sh
  sudo /tmp/remediate_ec2_instance.sh <s3-bucket-name>

- Example (SSM Run Command): Use the "Run a command" document to execute the script on the instance.

4) Verify the service

- After reprovisioning or remediation, check:
  sudo systemctl status foodordering.service
  sudo journalctl -u foodordering.service -n 200 --no-pager
  curl -f http://localhost:5000/ (or the configured listen endpoint)
