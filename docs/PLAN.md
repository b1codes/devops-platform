# PLAN.md: B1Codes DevOps Platform (The Engine)

> Implementation roadmap for [`SPEC.md`](./SPEC.md).
> Audience: B1Codes maintainers and external open-source consumers.
> Tracking philosophy: check off tasks as they land; keep phases independently shippable so the repo is always portfolio-presentable.

---

## Guiding Principles

- **Portable by default.** Anything required from the private `llc-infra-core` Brain layer (OIDC role ARN, remote state bucket, AWS Organization) is documented as an *external prerequisite* with a generic equivalent, so outside users can adopt the engine without B1Codes' private infra.
- **Modules first, workflows second.** Reusable workflows depend on the Terraform modules behaving predictably, so modules ship before workflows that call them.
- **Pin everything.** GitHub Actions pinned to commit SHAs, Terraform providers pinned with `~>`, and Lambda runtimes pinned to explicit versions.

---

## Phase 0 — Repo Foundation

**Goal:** Make the repo clearly explain what it is and what it requires, so a stranger can evaluate it in under two minutes.

- [ ] Expand `README.md` with: mission, architecture diagram, quickstart for *consumers*, and an explicit "What you need before using this" section.
- [ ] Add `CONTRIBUTING.md` covering branch model, commit conventions, and the "never hardcode" / "pin SHAs" rules from SPEC §5.
- [ ] Add `SECURITY.md` with a vulnerability disclosure channel (portfolio signal that this is real).
- [ ] Add `docs/PREREQUISITES.md` documenting the external dependencies:
  - An OIDC identity provider for `token.actions.githubusercontent.com` in the target AWS account.
  - An IAM role (referenced as `GitHubActionsRole`) trusted to the consumer's GitHub org/repo.
  - An S3 bucket + DynamoDB table for Terraform remote state.
  - A note: "B1Codes' internal implementation lives in `llc-infra-core`; any functionally-equivalent setup works."
- [ ] Create `.editorconfig`, `.gitignore` (terraform + node + python), and a `.tool-versions` or `mise.toml` declaring Terraform / Node / Python versions.

---

## Phase 1 — Core Terraform Modules (`/modules`)

**Goal:** Three reusable building blocks, each documented and demonstrable on its own.

For *every* module: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (pinned provider), `README.md` (auto-generatable via terraform-docs), and an `examples/basic/main.tf`.

### 1.1 `b1c-secure-bucket`
- [ ] S3 bucket with default encryption (SSE-S3 minimum, SSE-KMS optional via variable).
- [ ] Block all public access (4 sub-settings).
- [ ] Versioning enabled by default; lifecycle rule for noncurrent expiration.
- [ ] Optional bucket policy stanza that trusts an OIDC role ARN passed in as `var.oidc_principal_arn`.
- [ ] Outputs: `bucket_arn`, `bucket_id`, `bucket_regional_domain_name`.

### 1.2 `b1c-serverless-api`
- [ ] IAM execution role with `AWSLambdaBasicExecutionRole` + optional `var.extra_policy_arns`.
- [ ] Lambda function (runtime + handler + memory + timeout as variables; sensible defaults).
- [ ] HTTP API Gateway v2 with a `$default` route to the Lambda.
- [ ] CloudWatch log group with `var.log_retention_days` (default 14).
- [ ] Outputs: `function_arn`, `function_name`, `api_endpoint`, `execution_role_arn`.
- [ ] **Note:** This is the generic primitive. The private `tier1-serverless` module will wrap this and layer on Auth0 + DynamoDB.

### 1.3 `b1c-aurora-cluster`
- [ ] Aurora Serverless v2 cluster (`engine_mode = "provisioned"`, `serverlessv2_scaling_configuration` block).
- [ ] Subnet group + security group taking VPC/subnet IDs as inputs (module does not create the VPC).
- [ ] KMS-encrypted storage, automated backups, deletion protection toggle.
- [ ] Multi-tenant-friendly: outputs include `cluster_endpoint`, `reader_endpoint`, `cluster_resource_id` (for IAM auth).
- [ ] Document min/max ACU defaults explicitly in README (cost transparency).

---

## Phase 2 — Reusable GitHub Actions Workflows (`.github/workflows/`)

**Goal:** A consuming repo can deploy a Lambda or static site by adding a 10-line caller workflow.

- [ ] `aws-lambda-deploy.yml` (reusable; `workflow_call`):
  - Inputs: `function_name`, `aws_region`, `runtime`, `source_dir`, `role_to_assume`.
  - Steps: checkout → setup runtime → install/build → zip → `aws-actions/configure-aws-credentials` via OIDC → `aws lambda update-function-code`.
  - Supports Python and Node via a `runtime` input switch.
- [ ] `aws-static-site.yml`:
  - Inputs: `build_command`, `build_output_dir`, `bucket_name`, `cloudfront_distribution_id`, `role_to_assume`.
  - Steps: checkout → setup Node → build → `aws s3 sync --delete` → CloudFront invalidation.
- [ ] `terraform-plan-cost.yml`:
  - Inputs: `working_directory`, `tf_version`, `role_to_assume`, `infracost_api_key` (secret).
  - Steps: setup Terraform → `terraform init/validate/plan` → `infracost breakdown` → PR comment with the diff.
  - PR-only; safe on forks (no secrets exposure path).
- [ ] Pin every `uses:` reference to a commit SHA, with the human-readable tag in a trailing comment.
- [ ] Add a `.github/workflows/ci.yml` for *this* repo: `terraform fmt -check`, `terraform validate` against each module, `tflint`, `actionlint`.

---

## Phase 3 — Examples & Consumer Story

**Goal:** Anyone can fork this repo and ship a real Lambda within an hour.

- [ ] `examples/lambda-python/` — minimal `main.tf` instantiating `b1c-serverless-api` + a caller GitHub Actions workflow file.
- [ ] `examples/static-site/` — instantiation of `b1c-secure-bucket` + CloudFront wiring + caller workflow.
- [ ] `docs/CONSUMER-QUICKSTART.md` walking through the prerequisites, the OIDC trust setup, and a first successful deploy.
- [ ] A short architecture diagram in `docs/` (Mermaid is fine; renders on GitHub).

---

## Phase 4 — Hardening, Versioning, Public Release

**Goal:** Tag a `v0.1.0` that is honest, portable, and presentable.

- [ ] Adopt SemVer for module + workflow releases; document the policy in `CONTRIBUTING.md`.
- [ ] Add `terraform-docs` generation to CI; fail if module READMEs are stale.
- [ ] Add `tfsec` or `checkov` scan to module CI.
- [ ] Add `pre-commit` config with `terraform_fmt`, `terraform_validate`, `actionlint`.
- [ ] Verify the repo builds from a clean clone with zero hardcoded account IDs, secrets, or B1Codes-specific assumptions.
- [ ] Cut `v0.1.0` tag and write release notes.

---

## Out of Scope (Explicitly)

- AWS Organizations management — lives in the Brain (`llc-infra-core`).
- Per-application Terraform code or `tfvars` — lives in app repos or the private monorepo.
- Auth0 / Cognito specifics — that opinion belongs in the private `tier1-serverless` wrapper.
- Cost dashboards or FinOps tooling beyond the per-PR `infracost` comment.
