terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote state in S3 so the laptop and GitHub Actions share one source of
  # truth. use_lockfile takes a lock object in the same bucket (Terraform
  # 1.11+), so there's no separate DynamoDB lock table to manage.
  # The bucket is created once during bootstrap (see README); backend config
  # can't use variables, so the name is a literal here.
  backend "s3" {
    bucket       = "portfolio-counter-tfstate-aps1"
    key          = "counter/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
