# ---------------------------------------------------------------------------
# examples/lambda-python/main.tf
#
# Instantiates the b1c-serverless-api module to deploy a minimal Python
# Lambda function behind an HTTP API Gateway.
#
# No backend{} block here — configure remote state in a terraform.tf file
# in your own repo pointing at your Terraform state bucket. See:
# docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

module "example_python_api" {
  source = "../../modules/aws/b1c-serverless-api"

  function_name = "example-python-api"
  runtime       = "python3.12"
  handler       = "index.handler"
  source_dir    = "${path.module}/src"

  memory_mb          = 256
  timeout_seconds    = 30
  log_retention_days = 14

  tags = {
    Project     = "example-lambda-python"
    ManagedBy   = "Terraform"
    Environment = "demo"
  }
}

output "api_endpoint" {
  description = "Invoke URL for the deployed HTTP API. Append a path to test (e.g. /hello)."
  value       = module.example_python_api.api_endpoint
}

output "function_arn" {
  description = "ARN of the deployed Lambda function."
  value       = module.example_python_api.function_arn
}
