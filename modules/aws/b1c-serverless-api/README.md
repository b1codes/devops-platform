# b1c-serverless-api

A generic, auth-free Lambda + HTTP API Gateway v2 module — the foundational primitive for serverless API deployments. Wrapper modules layer on authentication (Auth0, Cognito) and application-specific policies.

## Features

- **Lambda execution role** — creates an IAM role with `AWSLambdaBasicExecutionRole` and attaches any additional managed policies passed via `extra_policy_arns`.
- **Flexible source packaging** — provide either a pre-built zip path (`source_filename`) or a local directory to zip at plan time (`source_dir`). Exactly one must be set; a `precondition` enforces this.
- **CloudWatch log group** — pre-created with configurable retention so Lambda never auto-creates an unmanaged log group.
- **HTTP API Gateway v2** — `$default` route with `AWS_PROXY` integration to the Lambda function.
- **Auth-free by design** — the `$default` route uses `authorization_type = "NONE"`. Add JWT authorization in a wrapper module (see below).
- **Environment variables** — pass any map of key/value pairs via `environment_variables`.
- **Generic and tagless by default** — no hardcoded tags; merge your own via `var.tags`.

## Adding Authentication

This module is intentionally unauthenticated. To add JWT authorization (Auth0, Cognito, or any JWKS-compatible IdP):

1. Call this module to get the `api_id` and `function_arn` outputs.
2. In your wrapper module, create `aws_apigatewayv2_authorizer` (type `JWT`).
3. Create a new `aws_apigatewayv2_route` resource that overrides the `$default` route with `authorization_type = "JWT"` and `authorizer_id` set.

The private `llc-infra-core/modules/tier1-serverless` module demonstrates this pattern with Auth0.

## Usage

```hcl
module "my_api" {
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"

  function_name = "my-app-api-prod"
  runtime       = "python3.12"
  handler       = "index.handler"

  # Provide either source_filename (pre-built zip) OR source_dir (zipped at plan time)
  source_dir = "${path.module}/src"

  memory_mb       = 512
  timeout_seconds = 30

  extra_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
  ]

  environment_variables = {
    ENVIRONMENT = "prod"
    TABLE_NAME  = "my-app-table"
  }

  tags = {
    Environment = "prod"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "api_endpoint" {
  value = module.my_api.api_endpoint
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

## Source Packaging

| Scenario | Variable to set |
|----------|-----------------|
| You build and zip in CI before calling Terraform | `source_filename = "/path/to/function.zip"` |
| You want Terraform to zip a local directory at plan time | `source_dir = "${path.module}/src"` |

Setting both or neither results in a `precondition` error at plan time.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-generates the inputs/outputs tables between these markers. -->
<!-- Run: terraform-docs markdown table --output-file README.md . -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function (also used as prefix for API GW and log group). | `string` | — | yes |
| tags | Map of tags to merge into every taggable resource. | `map(string)` | `{}` | no |
| runtime | Lambda runtime identifier (e.g. python3.12, nodejs20.x). | `string` | `"python3.12"` | no |
| handler | Lambda handler in file.function notation. | `string` | `"index.handler"` | no |
| memory_mb | Memory in MB allocated to the Lambda function. | `number` | `256` | no |
| timeout_seconds | Maximum Lambda execution time in seconds. | `number` | `30` | no |
| log_retention_days | CloudWatch log retention in days (must be a CWL-allowed value). | `number` | `14` | no |
| source_filename | Path to a pre-built zip. Mutually exclusive with source_dir. | `string` | `null` | no |
| source_dir | Path to a directory to zip at plan time. Mutually exclusive with source_filename. | `string` | `null` | no |
| extra_policy_arns | Additional managed policy ARNs to attach to the execution role. | `list(string)` | `[]` | no |
| environment_variables | Runtime environment variables for the Lambda function. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_arn | ARN of the Lambda function. |
| function_name | Name of the Lambda function. |
| api_endpoint | Invoke URL of the API Gateway $default stage. |
| api_id | ID of the API Gateway v2 HTTP API. |
| execution_role_arn | ARN of the Lambda execution IAM role. |
| log_group_name | Name of the CloudWatch log group. |

<!-- END_TF_DOCS -->

## License

MIT
