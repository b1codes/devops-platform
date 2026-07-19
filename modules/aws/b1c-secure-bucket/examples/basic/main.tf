terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Minimal example: creates a private, encrypted, versioned S3 bucket.
# No backend{} block here — configure remote state in your root module.
module "my_bucket" {
  source = "../../"

  bucket_name = "my-org-my-app-artifacts-dev"

  tags = {
    Environment = "dev"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "bucket_arn" {
  description = "ARN of the created bucket."
  value       = module.my_bucket.bucket_arn
}

output "bucket_id" {
  description = "Name of the created bucket."
  value       = module.my_bucket.bucket_id
}
