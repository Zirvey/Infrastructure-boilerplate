# Terraform Guide

Complete reference for Terraform usage in this project.

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Backend Configuration](#backend-configuration)
- [Modules](#modules)
- [Environments](#environments)
- [Variables & Outputs](#variables--outputs)
- [State Management](#state-management)
- [Common Operations](#common-operations)
- [Best Practices](#best-practices)

---

## Overview

Terraform is used to provision cloud infrastructure (VPC, EC2, S3, RDS, IAM). This project uses:

- **AWS Provider** ~> 5.0
- **S3 Backend** with DynamoDB state locking
- **Modular architecture** — reusable modules in `terraform/modules/`
- **Environment isolation** — separate configs per environment

---

## Directory Structure

```
terraform/
├── modules/              # Reusable modules
│   └── vpc/              # VPC with public/private subnets
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── environments/         # Environment-specific configs
    ├── dev/
    │   ├── main.tf       # Provider + backend config
    │   ├── variables.tf  # Variable definitions
    │   ├── modules.tf    # Module invocations
    │   └── outputs.tf    # Output definitions
    ├── staging/
    └── prod/
```

---

## Backend Configuration

State is stored remotely in S3 with DynamoDB locking:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "env/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-lock-table"
}
```

**Setup the backend:**

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Modules

### VPC Module

Creates a multi-AZ VPC with public and private subnets.

**Inputs:**

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_cidr` | CIDR block for VPC | `string` | - | Yes |
| `availability_zones` | List of AZs | `list(string)` | - | Yes |
| `public_subnet_cidrs` | CIDR blocks for public subnets | `list(string)` | - | Yes |
| `private_subnet_cidrs` | CIDR blocks for private subnets | `list(string)` | - | Yes |
| `environment` | Environment name for tagging | `string` | - | Yes |

**Outputs:**

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the VPC |
| `public_subnet_ids` | IDs of public subnets |
| `private_subnet_ids` | IDs of private subnets |

**Usage:**

```hcl
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  environment          = var.environment
}
```

---

## Environments

Each environment has its own:

- **Backend configuration** (separate state file)
- **Variables** (different sizes, counts, regions)
- **Module composition** (prod may have extra modules)

| Environment | Instances | Purpose |
|-------------|-----------|---------|
| `dev` | Small | Development and testing |
| `staging` | Medium | Pre-production validation |
| `prod` | Large | Production workloads |

---

## Variables & Outputs

### Defining Variables

```hcl
# terraform/environments/dev/variables.tf
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
```

### Using Variables Files

```bash
# Create a variables file (do NOT commit sensitive values)
cat > terraform/environments/dev/variables.tfvars <<EOF
aws_region  = "us-east-1"
environment = "dev"
EOF

# Apply with variable file
terraform plan -var-file=variables.tfvars
```

### Outputs

```hcl
# terraform/environments/dev/outputs.tf
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}
```

---

## State Management

### Import Existing Resources

```bash
terraform import module.vpc.aws_vpc.this vpc-12345678
```

### Remove Resource from State

```bash
terraform state rm module.vpc.aws_vpc.this
```

### List State

```bash
terraform state list
```

### Show Specific Resource

```bash
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address == "module.vpc.aws_vpc.this")'
```

---

## Common Operations

### Using the Makefile

```bash
make tf-init       # Initialize
make tf-plan       # Preview changes
make tf-apply      # Apply changes
make tf-destroy    # Destroy (⚠️ irreversible)
make tf-output     # Show outputs
make tf-fmt        # Format code
make tf-validate   # Validate configs
```

### Manual Commands

```bash
cd terraform/environments/dev

terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
terraform destroy -var="environment=dev"
```

---

## Best Practices

1. **Always use remote state** — never local `.tfstate` files
2. **Pin provider versions** — `version = "~> 5.0"` not `>= 5.0`
3. **Use consistent tags** — `ManagedBy`, `Environment`, `Project`
4. **Avoid `count` with list indices** — use `for_each` for maps
5. **Separate state per environment** — different S3 keys
6. **Use workspaces sparingly** — prefer directory-based environments
7. **Run `terraform fmt` before committing** — enforced in CI
8. **Never store secrets in state** — use SOPS or Secrets Manager
9. **Review plan output carefully** — especially `forces replacement`
10. **Use `terraform validate` in CI** — catches syntax errors early
