# Example: Lambda Python API

This example deploys a minimal Python 3.12 Lambda function behind an HTTP API
Gateway v2 using the `b1c-serverless-api` module. It is the fastest path to
a working, OIDC-authenticated Lambda deployment with this platform.

---

## What this example does

1. Creates an IAM execution role for the Lambda function.
2. Packages `src/index.py` into a ZIP archive at plan time.
3. Deploys a Lambda function named `example-python-api`.
4. Creates an HTTP API Gateway v2 with a `$default` route that proxies all
   requests to the Lambda function.
5. Creates a CloudWatch log group with 14-day retention.
6. Exposes the API invoke URL as a Terraform output (`api_endpoint`).

The handler returns a JSON response containing the request path, HTTP method,
and a UTC timestamp — useful for verifying end-to-end connectivity.

---

## Prerequisites

Complete all steps in [docs/PREREQUISITES.md](../../docs/PREREQUISITES.md)
before running `terraform apply`. You will need:

- An AWS account with the OIDC identity provider configured for GitHub Actions.
- An IAM role (`GitHubActionsRole` or equivalent) that GitHub Actions can
  assume via OIDC and that has `lambda:UpdateFunctionCode` and
  `lambda:GetFunction` permissions.
- A Terraform remote state backend (S3 bucket + DynamoDB table).

---

## Deploy

### 1. Configure remote state

Add a `terraform.tf` file (or `backend.tf`) in this directory, referencing
your S3 state bucket:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-tf-state-bucket>"
    key            = "examples/lambda-python/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<your-tf-lock-table>"
    encrypt        = true
  }
}
```

### 2. Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

Note the `api_endpoint` output — you will use it in step 4.

### 3. Set the GitHub Actions secret

In your GitHub repository settings, add a repository secret:

```
Name:  AWS_DEPLOY_ROLE_ARN
Value: arn:aws:iam::<account-id>:role/GitHubActionsRole
```

### 4. Trigger the deploy workflow

Push a change to `src/index.py` on the `main` branch. The
`.github/workflows/deploy.yml` workflow will package and upload the function
code to AWS.

### 5. Verify

```bash
curl "$(terraform output -raw api_endpoint)/hello"
```

Expected response shape:

```json
{
  "message": "Hello from devops-platform example-python-api",
  "path": "/hello",
  "method": "GET",
  "timestamp": "2025-01-15T12:00:00Z"
}
```

---

## Clean up

```bash
terraform destroy
```
