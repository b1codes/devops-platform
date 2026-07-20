# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

#### Terraform Modules

- `modules/aws/b1c-secure-bucket` — Opinionated S3 bucket with SSE encryption
  (SSE-S3 default, SSE-KMS optional), all public-access blocks, versioning
  enabled by default, noncurrent version lifecycle expiration, and an optional
  bucket policy for OIDC-federated role access.

- `modules/aws/b1c-serverless-api` — Lambda function wired to an HTTP API Gateway
  v2 with a `$default` route, IAM execution role, CloudWatch log group with
  configurable retention, and optional extra IAM policy attachments. Auth-free
  by design; consumers layer authorization in a wrapper module.

- `modules/aws/b1c-aurora-cluster` — Aurora Serverless v2 cluster with
  `serverlessv2_scaling_configuration`, KMS-encrypted storage, automated
  backups, deletion protection toggle, subnet group, and security group.
  Does not create the VPC; VPC and subnet IDs are inputs.

- `modules/gcp/b1c-secure-bucket` — Opinionated GCS bucket with encryption,
  versioning, public access prevention, and optional Workload Identity
  Federation IAM binding.

- `modules/gcp/b1c-serverless-api` — Cloud Run v2 service with a dedicated
  runtime service account and configurable autoscaling.

- `modules/gcp/b1c-relational-db` — Cloud SQL instance with private IP,
  CMEK-optional encryption, and automated backups.

#### Reusable GitHub Actions Workflows

- `.github/workflows/aws-lambda-deploy.yml` — Packages Python or Node source
  into a ZIP, authenticates to AWS via OIDC, and calls
  `aws lambda update-function-code`. Inputs: `function_name`, `aws_region`,
  `runtime` (`python`|`node`), `source_dir`, optional `runtime_version` and
  `dependency_install_command`.

- `.github/workflows/aws-static-site.yml` — Builds a static site, syncs to
  S3 with `--delete`, and creates a CloudFront invalidation. Inputs:
  `build_command`, `build_output_dir`, `bucket_name`,
  `cloudfront_distribution_id`, `aws_region`, optional `node_version` and
  `wait_for_invalidation`.

- `.github/workflows/gcp-cloudrun-deploy.yml` — Deploys a Cloud Run service
  from source via Workload Identity Federation.

- `.github/workflows/gcp-static-site.yml` — Builds a frontend, syncs to
  GCS, and invalidates Cloud CDN.

- `.github/workflows/terraform-plan-cost.yml` — Runs `terraform plan` and
  `infracost breakdown`, then posts a cost diff comment on the pull request.
  PR-only; does not run on push to `main`.

- `.github/workflows/ci.yml` — Internal CI for this repo. Runs
  `terraform fmt -check`, `terraform validate`, `tflint`, and `actionlint`
  against all modules and workflows.

#### Examples

- `examples/lambda-python/` — Minimal Python 3.12 Lambda example using
  `b1c-serverless-api`. Includes a caller workflow that calls
  `aws-lambda-deploy.yml`.

- `examples/static-site/` — S3 + CloudFront static site example using
  `b1c-secure-bucket` with Origin Access Control. Includes a caller workflow
  that calls `aws-static-site.yml`.

#### Documentation

- `docs/CONSUMER-QUICKSTART.md` — End-to-end walkthrough for deploying a
  Lambda from scratch, including OIDC setup, Terraform apply, and
  troubleshooting for 5 common errors.

- `docs/ARCHITECTURE.md` — Mermaid diagrams showing the deployment flow
  (consumer repo to AWS via OIDC) and the Terraform module layering.
  Narrative on the Golden Path methodology.

- `docs/PREREQUISITES.md` — Detailed setup instructions for the four
  external dependencies: AWS OIDC provider, GitHub Actions IAM role,
  Terraform state bucket, and DynamoDB lock table.

#### Hardening

- `.pre-commit-config.yaml` — Pre-commit hooks for file hygiene, Terraform
  formatting/validation/linting/docs/security, secret scanning (gitleaks),
  and local guards that enforce no `backend {}` in modules and that all
  reusable workflow refs are pinned to 40-char SHAs.

- `.terraform-docs.yml` — terraform-docs configuration for auto-generating
  module README tables in `inject` mode.

- `.tflint.hcl` — tflint configuration with the AWS plugin and five core
  Terraform rules.

- `RELEASE-CHECKLIST.md` — Human checklist for cutting a release, covering
  CI, documentation, security, and the tagging procedure.

---

## [0.1.0] — TBD

> This release has not yet been cut. The content above will be moved here
> with the exact date when `v0.1.0` is tagged. See `RELEASE-CHECKLIST.md`
> for the pre-release verification procedure.

---

[Unreleased]: https://github.com/B1Codes/devops-platform/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/B1Codes/devops-platform/releases/tag/v0.1.0
