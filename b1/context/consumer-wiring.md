# Consumer wiring patterns

How a downstream repository consumes the devops-platform engine. Two integration surfaces: Terraform modules (by Git source) and reusable GitHub Actions workflows (by `workflow_call`).

## Terraform module by Git source

Always pin `?ref=` to a tag or SHA — never `main`. Tag bumps are tracked in `CHANGELOG.md`. Full README + variables for each module lives at `modules/<name>/README.md` (terraform-docs-generated).

### `b1c-secure-bucket` — minimum viable

```hcl
module "site_bucket" {
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-secure-bucket?ref=v0.1.0"

  bucket_name        = "example-static-site-${random_id.suffix.hex}"
  versioning_enabled = true

  tags = {
    Project     = "example-static-site"
    ManagedBy   = "Terraform"
    Environment = "demo"
  }
}
```

### `b1c-serverless-api` — minimum viable

```hcl
module "api" {
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"

  function_name = "example-python-api"
  runtime       = "python3.12"
  handler       = "index.handler"
  source_dir    = "${path.module}/src"

  memory_mb          = 256
  timeout_seconds    = 30
  log_retention_days = 14

  tags = { Project = "...", ManagedBy = "Terraform", Environment = "demo" }
}
```

This module is **auth-free** — consumers layer authorization in a wrapper (Auth0, Cognito, any JWKS-compatible IdP). See [[footguns]].

### `b1c-aurora-cluster` — minimum viable

Aurora Serverless v2, KMS-encrypted storage, automated backups, deletion-protection toggle. **Does not create the VPC** — VPC and subnet IDs are inputs. See `modules/aws/b1c-aurora-cluster/README.md` for the full input table.

### GCP modules — minimum viable

Same pattern, `modules/gcp/` prefix. See each module's README for the full input table:

```hcl
module "site_bucket" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-secure-bucket?ref=v0.1.0"

  project_id  = "my-gcp-project"
  bucket_name = "example-static-site-${random_id.suffix.hex}"

  labels = { project = "example-static-site", managed_by = "terraform", environment = "demo" }
}
```

`gcp/b1c-serverless-api` (Cloud Run) and `gcp/b1c-relational-db` (Cloud SQL) follow the same shape — see [[footguns]] for the GCP-specific differences (labels vs. tags, container image vs. zip, no compute-autoscaling parity for Cloud SQL).

## Reusable workflow via `workflow_call`

Each workflow lives at `.github/workflows/<name>.yml` and is documented in that file's header comment. Minimum-viable caller shape:

```yaml
jobs:
  deploy:
    uses: B1Codes/devops-platform/.github/workflows/aws-lambda-deploy.yml@<sha>
    permissions:
      id-token: write
      contents: read
    with:
      function_name: example-python-api
      aws_region:    us-east-1
      runtime:       python
      runtime_version: "3.12"
      source_dir:    src
    secrets:
      role_to_assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

`id-token: write` is required so the workflow can mint an OIDC token; without it role assumption fails with an opaque error.

Quick reference for the five workflows:

| Workflow | Purpose | Required inputs |
|---|---|---|
| `aws-lambda-deploy.yml` | Package + deploy Lambda via OIDC | `function_name`, `aws_region`, `runtime` (`python`/`node`), `source_dir` |
| `aws-static-site.yml` | Build, S3 sync `--delete`, CloudFront invalidation | `build_command`, `build_output_dir`, `bucket_name`, `cloudfront_distribution_id`, `aws_region` |
| `gcp-cloudrun-deploy.yml` | Deploy to Cloud Run from source via WIF | `service_name`, `gcp_project_id`, `gcp_region`, `source_dir` |
| `gcp-static-site.yml` | Build, GCS sync, Cloud CDN invalidation | `build_command`, `build_output_dir`, `bucket_name`, `backend_bucket_name`, `gcp_project_id` |
| `terraform-plan-cost.yml` | `terraform plan` + Infracost diff on PRs | PR-only — see [[footguns]] |

For exhaustive input lists, read the `inputs:` block at the top of each workflow file.

## State backend

Engine modules do not declare `backend {}` (see [[conventions]] rule 1). The consumer's root configuration owns state — typically S3 + DynamoDB lock:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-state-bucket>"
    key            = "<path/to/your/app>.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<your-lock-table>"
    encrypt        = true
  }
}
```

Bucket, lock table, region — all consumer-owned. Setup instructions: `docs/PREREQUISITES.md`.
