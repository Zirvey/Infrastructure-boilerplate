# VPC Module

Creates a VPC with public and private subnets across multiple availability zones.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  environment          = "dev"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_cidr | CIDR block for VPC | `string` | - |
| availability_zones | List of AZs | `list(string)` | - |
| public_subnet_cidrs | CIDR blocks for public subnets | `list(string)` | - |
| private_subnet_cidrs | CIDR blocks for private subnets | `list(string)` | - |
| environment | Environment name | `string` | - |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| public_subnet_ids | IDs of public subnets |
| private_subnet_ids | IDs of private subnets |
