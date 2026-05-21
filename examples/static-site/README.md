# Example: Static Site (S3 + CloudFront)

This example deploys a static website to AWS using:

- `b1c-secure-bucket` for a private, encrypted S3 origin.
- `aws_cloudfront_distribution` with an Origin Access Control (OAC) for
  secure, HTTPS-only delivery.
- The `aws-static-site.yml` reusable workflow for zero-credential CI deployments.

A `random_id` suffix is added to the bucket name to avoid S3 global name
collisions when multiple consumers try this example simultaneously.

---

## What this example creates

| Resource | Description |
|---|---|
| `b1c-secure-bucket` | Private S3 bucket with SSE encryption, versioning, public-access blocks |
| `aws_cloudfront_origin_access_control` | OAC scoping CloudFront's access to this bucket only |
| `aws_cloudfront_distribution` | HTTPS-only distribution with default cache behavior |
| `aws_s3_bucket_policy` | Bucket policy allowing CloudFront service principal read via `AWS:SourceArn` |

Outputs: `cloudfront_domain`, `cloudfront_distribution_id`, `bucket_name`.

---

## Prerequisites

Complete all steps in [docs/PREREQUISITES.md](../../docs/PREREQUISITES.md)
before running `terraform apply`. You will need:

- An AWS account with the GitHub Actions OIDC identity provider configured.
- An IAM role with `s3:PutObject`, `s3:DeleteObject`, and
  `cloudfront:CreateInvalidation` permissions for the CI workflow.
- A Terraform remote state backend (S3 bucket + DynamoDB table).

---

## Deploy

### 1. Configure remote state

Add a `terraform.tf` (or `backend.tf`) file in this directory:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-tf-state-bucket>"
    key            = "examples/static-site/terraform.tfstate"
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

Note the outputs:

```text
cloudfront_domain          = "d1234abcd.cloudfront.net"
cloudfront_distribution_id = "E1ABCDEF12345"
bucket_name                = "example-static-site-a1b2c3d4"
```

### 3. Configure GitHub Actions

In your GitHub repository settings, add:

**Secret:**

```text
Name:  AWS_DEPLOY_ROLE_ARN
Value: arn:aws:iam::<account-id>:role/GitHubActionsRole
```

**Variables:**

```text
Name:  STATIC_SITE_BUCKET_NAME
Value: <bucket_name output from terraform apply>

Name:  STATIC_SITE_DISTRIBUTION_ID
Value: <cloudfront_distribution_id output from terraform apply>
```

### 4. Trigger the deploy workflow

Push a change to `site/index.html` on the `main` branch. The workflow will
sync the `site/` directory to S3 and invalidate the CloudFront cache.

### 5. Verify

Open `https://<cloudfront_domain>` in a browser. You should see the "Hello
from devops-platform" landing page.

DNS propagation and the first CloudFront cache warm-up can take 1-2 minutes.

---

## Clean up

```bash
terraform destroy
```

Note: `force_destroy` is set to `false` in the module by default, which means
Terraform will refuse to destroy a non-empty bucket. Empty the bucket first:

```bash
aws s3 rm s3://<bucket_name> --recursive
terraform destroy
```
