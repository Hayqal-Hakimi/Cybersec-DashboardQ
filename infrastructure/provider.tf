# Terraform and provider configuration for AWS Core Infrastructure
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Uncomment below to enable S3 backend for state management
  # backend "s3" {
  #   bucket         = "terraform-state-${var.project_name}"
  #   key            = "${var.environment}/terraform.tfstate"
  #   region         = var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# AWS provider configured with region and default tags
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.aws_region
    }
  }
}