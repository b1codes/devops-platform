terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Minimal example: deploys a Lambda function (from a local directory) behind
# an HTTP API Gateway. The API is unauthenticated — add an authorizer in
# your wrapper module if you need JWT/Cognito/Auth0 protection.
#
# IMPORTANT: Create a file at ./src/index.py with a handler before running
# terraform apply. Example handler:
#
#   def handler(event, context):
#       return {"statusCode": 200, "body": "Hello, World!"}

module "my_api" {
  source = "../../"

  function_name = "my-app-api-dev"
  runtime       = "python3.12"
  handler       = "index.handler"
  source_dir    = "${path.module}/src"

  environment_variables = {
    ENVIRONMENT = "dev"
  }

  tags = {
    Environment = "dev"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "api_endpoint" {
  description = "Invoke URL for the deployed API."
  value       = module.my_api.api_endpoint
}

output "function_name" {
  description = "Name of the deployed Lambda function."
  value       = module.my_api.function_name
}
