terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # bucket         = "your-terraform-state-bucket"
    # key            = "env/dev/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-lock-table"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}
