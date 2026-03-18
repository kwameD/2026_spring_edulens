# Local data sources and provider configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"
    }
  }
  
  # Optional: Use S3 backend for state management
  # Uncomment and configure for team environments
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "edulense/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  provider = aws
}

data "aws_availability_zones" "available" {
  state = "available"
}
