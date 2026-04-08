# AWS Example

This example demonstrates deploying the infrastructure boilerplate to AWS.

## Prerequisites

- AWS account with appropriate IAM permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0

## Architecture

- VPC with public and private subnets (2 AZs)
- NAT Gateway for private subnet internet access
- EC2 instances in private subnets
- Application Load Balancer in public subnets
- RDS PostgreSQL in isolated subnets
- S3 buckets for application data

## Deploy

```bash
# Copy base Terraform
cp -r ../../terraform/environments/dev ./

# Customize variables
cat > variables.tfvars <<EOF
aws_region    = "us-east-1"
environment   = "dev"
project_name  = "my-aws-project"
instance_type = "t3.medium"
EOF

# Deploy
terraform init
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

## Outputs

```bash
terraform output
# vpc_id = "vpc-xxxxxxxxx"
# alb_dns = "my-alb-123456.us-east-1.elb.amazonaws.com"
# db_endpoint = "my-db.xxxxxx.us-east-1.rds.amazonaws.com:5432"
```

## Cost Estimate

| Resource | Monthly Cost (dev) |
|----------|-------------------|
| VPC + NAT GW | ~$45 |
| 2x t3.medium EC2 | ~$60 |
| ALB | ~$22 |
| RDS db.t3.small | ~$35 |
| S3 (50GB) | ~$1.15 |
| **Total** | **~$163/mo** |
