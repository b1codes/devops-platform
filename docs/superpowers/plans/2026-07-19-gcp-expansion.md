# GCP Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GCP-backed mirror of every existing AWS Terraform module and deploy workflow in `devops-platform`, under a symmetric `modules/aws/` + `modules/gcp/` layout, per the approved design in `docs/superpowers/specs/2026-07-19-gcp-expansion-design.md`.

**Architecture:** Move the three existing AWS modules under `modules/aws/`. Add three new GCP modules under `modules/gcp/` (`b1c-secure-bucket` → GCS, `b1c-serverless-api` → Cloud Run, `b1c-relational-db` → Cloud SQL), each with the same file shape as its AWS sibling (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`, `examples/basic/main.tf`). Add two new reusable workflows (`gcp-cloudrun-deploy.yml`, `gcp-static-site.yml`) and two new top-level examples (`examples/gcp-cloudrun-python/`, `examples/gcp-static-site/`). Finish with a documentation pass across `README.md`, `docs/ARCHITECTURE.md`, `CLAUDE.md`, `b1/context/*.md`, `RELEASE-CHECKLIST.md`, and `CHANGELOG.md`.

**Tech Stack:** Terraform 1.9.5 (`hashicorp/google ~> 6.0`), tflint (`tflint-ruleset-google`), GitHub Actions reusable workflows, `google-github-actions/auth` (Workload Identity Federation), Cloud Run buildpacks source deploy.

There is no automated test suite in this repo. The verification loop for every task is: `terraform init -backend=false && terraform validate`, `tflint`, `terraform fmt -check -recursive`, and (for workflows) `actionlint`. These are the same checks CI runs — passing them locally is the "test cycle" for this codebase.

## Global Constraints

- No `backend {}` block anywhere under `modules/` (enforced by the `no-backend-in-modules` pre-commit hook).
- No hardcoded account IDs, project IDs, ARNs, bucket names, or region strings in module bodies — everything is a variable.
- Every `uses:` reference in `.github/workflows/` must be pinned to a full 40-character commit SHA with the human-readable tag in a trailing comment (`workflows-pinned-to-sha` hook). Caller workflows under `examples/*/.github/workflows/` are exempt.
- Every module under `modules/` ships a `README.md` and an `examples/basic/main.tf` (module documentation contract).
- GCP auth is Workload Identity Federation only — no workflow accepts a static service-account JSON key (`credentials_json:`).
- GCP resource "tags" are called labels: lowercase keys/values only, validated in every module that accepts `var.labels`.
- `terraform fmt -recursive` must show zero diff at the end of every task.
- Provider version pin: `hashicorp/google ~> 6.0` — **verify this is still the current major version before Task 3**; adjust if a newer major has since shipped.

---

### Task 1: Restructure AWS modules under `modules/aws/`

**Files:**
- Move: `modules/b1c-secure-bucket/` → `modules/aws/b1c-secure-bucket/`
- Move: `modules/b1c-serverless-api/` → `modules/aws/b1c-serverless-api/`
- Move: `modules/b1c-aurora-cluster/` → `modules/aws/b1c-aurora-cluster/`
- Modify: `.github/dependabot.yml`, `.github/workflows/ci.yml`, `.terraform-docs.yml`, `CHANGELOG.md`, `RELEASE-CHECKLIST.md`, `docs/CONSUMER-QUICKSTART.md`, `docs/ARCHITECTURE.md`, `examples/static-site/main.tf`, `examples/lambda-python/main.tf`, `CLAUDE.md`, `b1/context/consumer-wiring.md`, `modules/aws/b1c-secure-bucket/README.md`, `modules/aws/b1c-serverless-api/README.md`, `modules/aws/b1c-aurora-cluster/README.md`

**Interfaces:**
- Produces: the path prefix `modules/aws/` that Tasks 3-9 assume exists before adding `modules/gcp/` alongside it.

This task is a pure path rename — no `.tf` content changes. The "test" is a repo-wide grep proving no stale references remain, plus `terraform validate` on all three moved modules to confirm the move broke nothing.

- [ ] **Step 1: Move the three module directories**

```bash
git mv modules/b1c-secure-bucket modules/aws/b1c-secure-bucket
git mv modules/b1c-serverless-api modules/aws/b1c-serverless-api
git mv modules/b1c-aurora-cluster modules/aws/b1c-aurora-cluster
```

- [ ] **Step 2: Fix path references — CI and Dependabot config**

In `.github/workflows/ci.yml`, both the `terraform-validate` and `tflint` job matrices currently read:

```yaml
        include:
          - module: modules/b1c-secure-bucket
          - module: modules/b1c-serverless-api
          - module: modules/b1c-aurora-cluster
```

Replace both occurrences (there are two identical blocks, one per job) with:

```yaml
        include:
          - module: modules/aws/b1c-secure-bucket
          - module: modules/aws/b1c-serverless-api
          - module: modules/aws/b1c-aurora-cluster
```

In `.github/dependabot.yml`, update the three Terraform module entries:

```yaml
  # ── Terraform — b1c-secure-bucket ───────────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/aws/b1c-secure-bucket"
```

```yaml
  # ── Terraform — b1c-serverless-api ──────────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/aws/b1c-serverless-api"
```

```yaml
  # ── Terraform — b1c-aurora-cluster ──────────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/aws/b1c-aurora-cluster"
```

- [ ] **Step 3: Fix path references — terraform-docs and release checklist**

In `.terraform-docs.yml`, the comment example:

```yaml
#   terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-secure-bucket
```

In `RELEASE-CHECKLIST.md`, the three `terraform-docs` command lines:

```bash
terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-secure-bucket
terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-serverless-api
terraform-docs markdown table --config .terraform-docs.yml modules/aws/b1c-aurora-cluster
```

- [ ] **Step 4: Fix path references — CHANGELOG**

In `CHANGELOG.md`, update the three `[Unreleased]` bullets from `modules/b1c-*` to `modules/aws/b1c-*`:

```markdown
- `modules/aws/b1c-secure-bucket` — Opinionated S3 bucket with SSE encryption
- `modules/aws/b1c-serverless-api` — Lambda function wired to an HTTP API Gateway
- `modules/aws/b1c-aurora-cluster` — Aurora Serverless v2 cluster with
```

(Keep whatever text follows each dash unchanged — only the path token changes.)

- [ ] **Step 5: Fix path references — consumer-facing docs**

In `docs/CONSUMER-QUICKSTART.md`, line 51:

```hcl
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"
```

In `modules/aws/b1c-secure-bucket/README.md` (usage example, outside the `BEGIN_TF_DOCS` markers):

```hcl
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-secure-bucket?ref=v0.1.0"
```

In `modules/aws/b1c-serverless-api/README.md`:

```hcl
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"
```

In `modules/aws/b1c-aurora-cluster/README.md`:

```hcl
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-aurora-cluster?ref=v0.1.0"
```

- [ ] **Step 6: Fix path references — docs/ARCHITECTURE.md diagram**

In `docs/ARCHITECTURE.md`, Diagram 2's node labels change from:

```
        M1["modules/b1c-secure-bucket"]
        M2["modules/b1c-serverless-api"]
        M3["modules/b1c-aurora-cluster"]
```

to:

```
        M1["modules/aws/b1c-secure-bucket"]
        M2["modules/aws/b1c-serverless-api"]
        M3["modules/aws/b1c-aurora-cluster"]
```

And its five edge labels change from:

```
    E1 -->|"source = ../../modules/b1c-serverless-api"| M2
    E2 -->|"source = ../../modules/b1c-secure-bucket"| M1
    A1 -->|"source = github.com/B1Codes/devops-platform//modules/b1c-serverless-api?ref=v0.1.0"| M2
    A1 -->|"source = github.com/B1Codes/devops-platform//modules/b1c-secure-bucket?ref=v0.1.0"| M1
    A2 -->|"source = github.com/B1Codes/devops-platform//modules/b1c-aurora-cluster?ref=v0.1.0"| M3
```

to:

```
    E1 -->|"source = ../../modules/aws/b1c-serverless-api"| M2
    E2 -->|"source = ../../modules/aws/b1c-secure-bucket"| M1
    A1 -->|"source = github.com/B1Codes/devops-platform//modules/aws/b1c-serverless-api?ref=v0.1.0"| M2
    A1 -->|"source = github.com/B1Codes/devops-platform//modules/aws/b1c-secure-bucket?ref=v0.1.0"| M1
    A2 -->|"source = github.com/B1Codes/devops-platform//modules/aws/b1c-aurora-cluster?ref=v0.1.0"| M3
```

- [ ] **Step 7: Fix path references — example `.tf` files**

In `examples/static-site/main.tf`:

```hcl
  source = "../../modules/aws/b1c-secure-bucket"
```

In `examples/lambda-python/main.tf`:

```hcl
  source = "../../modules/aws/b1c-serverless-api"
```

- [ ] **Step 8: Fix path references — this repo's own CLAUDE.md and b1/context**

In `CLAUDE.md` (repo root), the "Repository context" section currently reads:

```markdown
- **Generic Terraform modules** under `modules/` (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-aurora-cluster`) consumed via `source = "github.com/B1Codes/devops-platform//modules/<name>?ref=<tag>"`.
```

Change to:

```markdown
- **Generic Terraform modules** under `modules/aws/` (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-aurora-cluster`) consumed via `source = "github.com/B1Codes/devops-platform//modules/aws/<name>?ref=<tag>"`.
```

In `b1/context/consumer-wiring.md`, update the three module source/path references (the `b1c-secure-bucket` usage block's `source =` line, the `b1c-serverless-api` usage block's `source =` line, and the `b1c-aurora-cluster` section's `modules/b1c-aurora-cluster/README.md` pointer) the same way — prefix `modules/` with `modules/aws/` in each.

- [ ] **Step 9: Verify no stale references remain**

```bash
grep -rn 'modules/b1c-' --include='*.md' --include='*.yml' --include='*.yaml' --include='*.tf' .
```

Expected: no output (empty). If anything prints, it's a reference Steps 2-8 missed — fix it before continuing.

- [ ] **Step 10: Validate the three moved modules still work**

```bash
for m in modules/aws/b1c-secure-bucket modules/aws/b1c-serverless-api modules/aws/b1c-aurora-cluster; do
  echo "=== $m ==="
  terraform -chdir="$m" init -backend=false -input=false
  terraform -chdir="$m" validate
done
```

Expected: `Success! The configuration is valid.` for all three.

- [ ] **Step 11: Format check**

```bash
terraform fmt -check -recursive
```

Expected: no output, exit code 0.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(modules)!: move AWS modules under modules/aws/

Prepares a symmetric modules/aws/ + modules/gcp/ layout ahead of adding
GCP module mirrors. Free to do now — v0.1.0 has not been tagged, so
there are no external consumers of the old modules/b1c-* paths yet.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add the `google` tflint plugin

**Files:**
- Modify: `.tflint.hcl`

**Interfaces:**
- Produces: `plugin "google"` rule set, required by Task 3's `tflint --chdir` step.

- [ ] **Step 1: Add the plugin block**

Append to `.tflint.hcl`, after the existing `plugin "aws"` block:

```hcl
# The Google plugin adds GCP-specific rules (deprecated resource types,
# invalid machine types, etc.). It is fetched automatically on first run.
# Verify this is still the latest release before merging:
# https://github.com/terraform-linters/tflint-ruleset-google/releases
plugin "google" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-google"
  version = "0.29.0"
}
```

- [ ] **Step 2: Verify tflint still initializes cleanly**

```bash
tflint --chdir=modules/aws/b1c-secure-bucket --init
tflint --chdir=modules/aws/b1c-secure-bucket --format compact
```

Expected: plugin download succeeds, zero lint issues reported (the AWS module content hasn't changed).

- [ ] **Step 3: Commit**

```bash
git add .tflint.hcl
git commit -m "chore(tflint): add google ruleset plugin ahead of GCP modules"
```

---

### Task 3: `modules/gcp/b1c-secure-bucket` (GCS)

**Files:**
- Create: `modules/gcp/b1c-secure-bucket/versions.tf`
- Create: `modules/gcp/b1c-secure-bucket/variables.tf`
- Create: `modules/gcp/b1c-secure-bucket/main.tf`
- Create: `modules/gcp/b1c-secure-bucket/outputs.tf`
- Create: `modules/gcp/b1c-secure-bucket/README.md`
- Create: `modules/gcp/b1c-secure-bucket/examples/basic/main.tf`
- Modify: `.github/workflows/ci.yml` (add matrix entries)
- Modify: `.github/dependabot.yml` (add Terraform ecosystem entry)

**Interfaces:**
- Produces: `bucket_name`, `bucket_url`, `bucket_self_link` outputs — consumed by Task 8's `examples/gcp-static-site/`.

- [ ] **Step 1: Write `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID in which to create the bucket."
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name for the GCS bucket."
}

variable "location" {
  type        = string
  description = "GCS bucket location: a region (e.g. 'us-central1') or a multi-region (e.g. 'US')."
  default     = "US"
}

variable "labels" {
  type        = map(string)
  description = "Map of labels to merge into every labelable resource created by this module. GCS labels must be lowercase and match GCP's label key/value character constraints (letters, numbers, underscores, dashes)."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z0-9_-]{1,63}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys and values must be lowercase and contain only letters, numbers, underscores, and dashes (max 63 characters each)."
  }
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable GCS bucket object versioning. Highly recommended for production workloads."
  default     = true
}

variable "kms_key_name" {
  type        = string
  description = "Fully qualified resource ID of a Cloud KMS CryptoKey to use for CMEK encryption (e.g. 'projects/p/locations/l/keyRings/r/cryptoKeys/k'). When null, Google-managed encryption is used."
  default     = null
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Number of days after which noncurrent object versions are permanently deleted by a lifecycle rule."
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days > 0
    error_message = "noncurrent_version_expiration_days must be greater than 0."
  }
}

variable "wif_principal_member" {
  type        = string
  description = "IAM principal identifier for a Workload-Identity-federated caller (e.g. 'principalSet://iam.googleapis.com/projects/.../workloadIdentityPools/...' or 'serviceAccount:name@project.iam.gserviceaccount.com') to grant object read/write/list access. When null, no IAM binding is created."
  default     = null
}

variable "force_destroy" {
  type        = bool
  description = "When true, all objects (including noncurrent versions) are deleted when the bucket is destroyed. Set to false in production to prevent accidental data loss."
  default     = false
}
```

- [ ] **Step 3: Write `main.tf`**

```hcl
# ---------------------------------------------------------------------------
# b1c-secure-bucket (GCP)
#
# Opinionated GCS bucket with:
#   - Uniform bucket-level access + enforced public access prevention
#   - Encryption (Google-managed default, CMEK optional)
#   - Versioning (enabled by default)
#   - Lifecycle rule to expire noncurrent versions
#   - Optional IAM binding granting a Workload-Identity-federated principal
#     read/write access
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "this" {
  project       = var.project_id
  name          = var.bucket_name
  location      = var.location
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "encryption" {
    for_each = var.kms_key_name != null ? [var.kms_key_name] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_expiration_days
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# ---------------------------------------------------------------------------
# Optional IAM binding — Workload Identity Federation principal access
# Only created when var.wif_principal_member is non-null.
# ---------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "wif_access" {
  count = var.wif_principal_member != null ? 1 : 0

  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = var.wif_principal_member
}
```

- [ ] **Step 4: Write `outputs.tf`**

```hcl
output "bucket_name" {
  description = "Name of the GCS bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "gs:// URL of the GCS bucket."
  value       = google_storage_bucket.this.url
}

output "bucket_self_link" {
  description = "Self-link URI of the GCS bucket."
  value       = google_storage_bucket.this.self_link
}
```

- [ ] **Step 5: Validate the module**

```bash
terraform -chdir=modules/gcp/b1c-secure-bucket init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-secure-bucket validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Lint the module**

```bash
tflint --chdir=modules/gcp/b1c-secure-bucket --format compact
```

Expected: zero issues.

- [ ] **Step 7: Write `examples/basic/main.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# ---------------------------------------------------------------------------
# PREREQUISITES:
# Replace var.project_id's value (via -var or a .tfvars file) with a real
# GCP project ID from your account. This module does not create the project.
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example bucket into."
}

# Minimal example: creates a private, encrypted, versioned GCS bucket.
# No backend{} block here — configure remote state in your root module.
module "my_bucket" {
  source = "../../"

  project_id  = var.project_id
  bucket_name = "my-org-my-app-artifacts-dev"

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "bucket_name" {
  description = "Name of the created bucket."
  value       = module.my_bucket.bucket_name
}

output "bucket_url" {
  description = "gs:// URL of the created bucket."
  value       = module.my_bucket.bucket_url
}
```

- [ ] **Step 8: Validate the example**

```bash
terraform -chdir=modules/gcp/b1c-secure-bucket/examples/basic init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-secure-bucket/examples/basic validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 9: Write `README.md`**

```markdown
# b1c-secure-bucket (GCP)

A hardened GCS bucket module that enforces encryption, blocks all public access, enables versioning, and optionally grants a Workload-Identity-federated principal scoped read/write access via an IAM binding. Mirrors [`modules/aws/b1c-secure-bucket`](../../aws/b1c-secure-bucket/) for the GCP provider.

## Features

- **Public access blocked** — `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"`.
- **Encryption** — Google-managed by default; switch to CMEK by passing `kms_key_name`.
- **Versioning** — enabled by default; configurable via `versioning_enabled`.
- **Noncurrent version lifecycle** — a lifecycle rule automatically expires noncurrent object versions after `noncurrent_version_expiration_days` (default 90) days.
- **Optional Workload Identity Federation binding** — pass `wif_principal_member` to grant a federated GitHub Actions principal (or any IAM member) `roles/storage.objectAdmin` on this bucket only. No binding is created when the variable is null.
- **Labels, not tags** — GCS calls them labels; they're lowercase-only and validated by this module. Don't reuse an AWS `tags` map verbatim.

## Usage

```hcl
module "artifacts_bucket" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-secure-bucket?ref=v0.1.0"

  project_id  = "my-gcp-project"
  bucket_name = "my-org-my-app-artifacts-prod"

  # Optional: grant a Workload-Identity-federated principal access
  wif_principal_member = "principalSet://iam.googleapis.com/projects/123/locations/global/workloadIdentityPools/github/attribute.repository/my-org/my-app"

  # Optional: use a customer-managed KMS key instead of Google-managed encryption
  # kms_key_name = "projects/my-gcp-project/locations/us/keyRings/my-ring/cryptoKeys/my-key"

  labels = {
    environment = "prod"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "bucket_url" {
  value = module.artifacts_bucket.bucket_url
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| google | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID in which to create the bucket. | `string` | n/a | yes |
| bucket_name | Globally unique name for the GCS bucket. | `string` | n/a | yes |
| location | GCS bucket location: a region or a multi-region. | `string` | `"US"` | no |
| labels | Map of labels to merge into every labelable resource. | `map(string)` | `{}` | no |
| versioning_enabled | Enable GCS bucket object versioning. | `bool` | `true` | no |
| kms_key_name | Cloud KMS CryptoKey resource ID for CMEK encryption. Null uses Google-managed encryption. | `string` | `null` | no |
| noncurrent_version_expiration_days | Days after which noncurrent versions are deleted. | `number` | `90` | no |
| wif_principal_member | IAM principal granted object read/write/list access via an IAM binding. | `string` | `null` | no |
| force_destroy | Delete all objects when bucket is destroyed. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the GCS bucket. |
| bucket_url | gs:// URL of the GCS bucket. |
| bucket_self_link | Self-link URI of the GCS bucket. |

<!-- END_TF_DOCS -->

## License

MIT
```

Note: `pre-commit`'s `terraform_docs` hook regenerates the content between the markers from the actual `variables.tf`/`outputs.tf` on first run — this hand-written table only needs to be accurate today, not byte-identical to the tool's output forever.

- [ ] **Step 10: Add CI matrix entries**

In `.github/workflows/ci.yml`, add one line to each of the two `matrix.include` lists (from Task 1):

```yaml
          - module: modules/gcp/b1c-secure-bucket
```

- [ ] **Step 11: Add Dependabot entry**

Append to `.github/dependabot.yml`:

```yaml
  # ── Terraform — gcp/b1c-secure-bucket ───────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/gcp/b1c-secure-bucket"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(deps):"
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"
```

- [ ] **Step 12: Format check**

```bash
terraform fmt -check -recursive
```

Expected: no output, exit code 0. If it fails, run `terraform fmt -recursive` and re-check.

- [ ] **Step 13: Commit**

```bash
git add modules/gcp/b1c-secure-bucket .github/workflows/ci.yml .github/dependabot.yml
git commit -m "feat(modules): add gcp/b1c-secure-bucket (GCS mirror of b1c-secure-bucket)"
```

---

### Task 4: `modules/gcp/b1c-serverless-api` (Cloud Run)

**Files:**
- Create: `modules/gcp/b1c-serverless-api/versions.tf`
- Create: `modules/gcp/b1c-serverless-api/variables.tf`
- Create: `modules/gcp/b1c-serverless-api/main.tf`
- Create: `modules/gcp/b1c-serverless-api/outputs.tf`
- Create: `modules/gcp/b1c-serverless-api/README.md`
- Create: `modules/gcp/b1c-serverless-api/examples/basic/main.tf`
- Modify: `.github/workflows/ci.yml` (add matrix entries)
- Modify: `.github/dependabot.yml` (add Terraform ecosystem entry)

**Interfaces:**
- Produces: `service_name`, `service_url`, `runtime_service_account_email` outputs — consumed by Task 7's `examples/gcp-cloudrun-python/`.

- [ ] **Step 1: Write `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID in which to create the Cloud Run service."
}

variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service. Also used as a prefix for the runtime service account."
}

variable "region" {
  type        = string
  description = "GCP region to deploy the Cloud Run service into (e.g. 'us-central1')."
}

variable "labels" {
  type        = map(string)
  description = "Map of labels to merge into every labelable resource created by this module."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z0-9_-]{1,63}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys and values must be lowercase and contain only letters, numbers, underscores, and dashes (max 63 characters each)."
  }
}

variable "container_image" {
  type        = string
  description = "Full container image reference to deploy (e.g. 'us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG'). This module does not build or push images — the caller (or gcp-cloudrun-deploy.yml) is responsible for that."
}

variable "container_port" {
  type        = number
  description = "TCP port the container listens on."
  default     = 8080
}

variable "memory" {
  type        = string
  description = "Memory limit per container instance (Cloud Run resource quantity string, e.g. '512Mi', '1Gi')."
  default     = "512Mi"
}

variable "cpu" {
  type        = string
  description = "CPU limit per container instance (Cloud Run resource quantity string, e.g. '1', '2')."
  default     = "1"
}

variable "timeout_seconds" {
  type        = number
  description = "Maximum request duration in seconds before Cloud Run terminates the request. Must be between 1 and 3600."
  default     = 30

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 3600
    error_message = "timeout_seconds must be between 1 and 3600."
  }
}

variable "min_instance_count" {
  type        = number
  description = "Minimum number of container instances to keep warm. 0 allows scale-to-zero."
  default     = 0
}

variable "max_instance_count" {
  type        = number
  description = "Maximum number of container instances Cloud Run will scale out to."
  default     = 10
}

variable "allow_unauthenticated" {
  type        = bool
  description = "When true, grants roles/run.invoker to allUsers, making the service publicly reachable without authentication. Consumers needing auth should leave this false and layer their own IAM/JWT authorization in a wrapper module."
  default     = false
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to inject into the container at runtime."
  default     = {}
}

variable "extra_role_ids" {
  type        = list(string)
  description = "List of additional IAM role IDs to grant the Cloud Run runtime service account on the project (e.g. 'roles/datastore.user', 'roles/secretmanager.secretAccessor')."
  default     = []
}
```

- [ ] **Step 3: Write `main.tf`**

```hcl
# ---------------------------------------------------------------------------
# b1c-serverless-api (GCP) — GENERIC, AUTH-FREE PRIMITIVE
#
# This module provisions a Cloud Run v2 service. It is auth-free by default:
# var.allow_unauthenticated = false (the default) creates the service
# without a public IAM invoker binding, so only principals explicitly
# granted roles/run.invoker can call it. Security is a concern for the
# consumer, mirroring modules/aws/b1c-serverless-api.
#
# Unlike Lambda, Cloud Run deploys a container image, not a zip. This
# module does not build or push images — see gcp-cloudrun-deploy.yml for
# the accompanying source-to-Cloud-Run deploy workflow.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# IAM — Cloud Run runtime service account
# ---------------------------------------------------------------------------

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.service_name}-run-sa"
  display_name = "Runtime service account for Cloud Run service ${var.service_name}"
}

resource "google_project_iam_member" "extra_roles" {
  for_each = toset(var.extra_role_ids)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# ---------------------------------------------------------------------------
# Cloud Run v2 service
# ---------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.runtime.email
    timeout         = "${var.timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          memory = var.memory
          cpu    = var.cpu
        }
      }

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  labels = var.labels
}

# ---------------------------------------------------------------------------
# Optional IAM binding — public invoker access
# Only created when var.allow_unauthenticated = true.
# ---------------------------------------------------------------------------

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

- [ ] **Step 4: Write `outputs.tf`**

```hcl
output "service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.this.name
}

output "service_url" {
  description = "HTTPS URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account_email" {
  description = "Email of the Cloud Run runtime service account. Pass this to wrapper modules that need to grant additional IAM roles."
  value       = google_service_account.runtime.email
}
```

- [ ] **Step 5: Validate the module**

```bash
terraform -chdir=modules/gcp/b1c-serverless-api init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-serverless-api validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Lint the module**

```bash
tflint --chdir=modules/gcp/b1c-serverless-api --format compact
```

Expected: zero issues.

- [ ] **Step 7: Write `examples/basic/main.tf`**

Uses Google's public Cloud Run quickstart image (`us-docker.pkg.dev/cloudrun/container/hello`) so the example is genuinely runnable, not a placeholder.

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example service into."
}

# Minimal example: deploys Google's public Cloud Run quickstart image behind
# an authenticated (non-public) Cloud Run service.
module "my_api" {
  source = "../../"

  project_id      = var.project_id
  service_name    = "example-hello-api"
  region          = "us-central1"
  container_image = "us-docker.pkg.dev/cloudrun/container/hello"

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "service_url" {
  description = "HTTPS URL of the deployed Cloud Run service."
  value       = module.my_api.service_url
}
```

- [ ] **Step 8: Validate the example**

```bash
terraform -chdir=modules/gcp/b1c-serverless-api/examples/basic init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-serverless-api/examples/basic validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 9: Write `README.md`**

```markdown
# b1c-serverless-api (GCP)

A Cloud Run v2 service with a dedicated runtime service account and configurable autoscaling. Mirrors [`modules/aws/b1c-serverless-api`](../../aws/b1c-serverless-api/) for the GCP provider — with one structural difference: Cloud Run deploys a **container image**, not a zip/source directory.

## Features

- **Auth-free by default** — `allow_unauthenticated = false` (the default) creates no public IAM invoker binding. Set it to `true` for a public endpoint, or layer your own IAM/JWT authorization in a wrapper module (mirrors the AWS module's auth-free-by-design stance).
- **Dedicated runtime identity** — a `google_service_account` is created per service, parallel to the AWS module's Lambda execution role. Grant it extra project roles via `extra_role_ids`.
- **Configurable autoscaling** — `min_instance_count` (0 allows scale-to-zero) and `max_instance_count`.
- **No API Gateway resource needed** — Cloud Run's built-in HTTPS endpoint + IAM invoker binding replace the AWS module's separate API Gateway v2 + Lambda integration.
- **No CloudWatch-log-group equivalent** — Cloud Run wires container stdout/stderr to Cloud Logging automatically. This is a platform difference, not a missing feature.

## Usage

```hcl
module "api" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-serverless-api?ref=v0.1.0"

  project_id      = "my-gcp-project"
  service_name    = "example-api"
  region          = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-gcp-project/my-repo/example-api:latest"

  min_instance_count = 0
  max_instance_count = 10
  memory             = "512Mi"
  cpu                = "1"

  labels = { environment = "prod", project = "my-app", managed_by = "terraform" }
}

output "service_url" {
  value = module.api.service_url
}
```

This module is **auth-free** — consumers layer authorization in a wrapper (Auth0, Cognito/Identity Platform, any JWKS-compatible IdP), same convention as the AWS module.

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| google | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID in which to create the Cloud Run service. | `string` | n/a | yes |
| service_name | Name of the Cloud Run service. | `string` | n/a | yes |
| region | GCP region to deploy into. | `string` | n/a | yes |
| labels | Map of labels to merge into every labelable resource. | `map(string)` | `{}` | no |
| container_image | Full container image reference to deploy. | `string` | n/a | yes |
| container_port | TCP port the container listens on. | `number` | `8080` | no |
| memory | Memory limit per container instance. | `string` | `"512Mi"` | no |
| cpu | CPU limit per container instance. | `string` | `"1"` | no |
| timeout_seconds | Maximum request duration in seconds. | `number` | `30` | no |
| min_instance_count | Minimum warm container instances. | `number` | `0` | no |
| max_instance_count | Maximum container instances. | `number` | `10` | no |
| allow_unauthenticated | Grant roles/run.invoker to allUsers. | `bool` | `false` | no |
| environment_variables | Environment variables injected at runtime. | `map(string)` | `{}` | no |
| extra_role_ids | Additional project IAM roles for the runtime service account. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_name | Name of the Cloud Run service. |
| service_url | HTTPS URL of the deployed Cloud Run service. |
| runtime_service_account_email | Email of the Cloud Run runtime service account. |

<!-- END_TF_DOCS -->

## License

MIT
```

- [ ] **Step 10: Add CI matrix entries**

```yaml
          - module: modules/gcp/b1c-serverless-api
```

(Add to both `matrix.include` lists in `.github/workflows/ci.yml`.)

- [ ] **Step 11: Add Dependabot entry**

```yaml
  # ── Terraform — gcp/b1c-serverless-api ──────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/gcp/b1c-serverless-api"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(deps):"
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"
```

- [ ] **Step 12: Format check**

```bash
terraform fmt -check -recursive
```

- [ ] **Step 13: Commit**

```bash
git add modules/gcp/b1c-serverless-api .github/workflows/ci.yml .github/dependabot.yml
git commit -m "feat(modules): add gcp/b1c-serverless-api (Cloud Run mirror of b1c-serverless-api)"
```

---

### Task 5: `modules/gcp/b1c-relational-db` (Cloud SQL)

**Files:**
- Create: `modules/gcp/b1c-relational-db/versions.tf`
- Create: `modules/gcp/b1c-relational-db/variables.tf`
- Create: `modules/gcp/b1c-relational-db/main.tf`
- Create: `modules/gcp/b1c-relational-db/outputs.tf`
- Create: `modules/gcp/b1c-relational-db/README.md`
- Create: `modules/gcp/b1c-relational-db/examples/basic/main.tf`
- Modify: `.github/workflows/ci.yml` (add matrix entries)
- Modify: `.github/dependabot.yml` (add Terraform ecosystem entry)

**Interfaces:**
- Produces: `instance_name`, `connection_name`, `private_ip_address`, `database_name` outputs. Not consumed by any other task in this plan — this module is a standalone primitive, same as `modules/aws/b1c-aurora-cluster` today.

- [ ] **Step 1: Write `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID in which to create the Cloud SQL instance."
}

variable "instance_name" {
  type        = string
  description = "Name of the Cloud SQL instance. Used as a prefix for related resource names."
}

variable "region" {
  type        = string
  description = "GCP region for the Cloud SQL instance (e.g. 'us-central1')."
}

variable "labels" {
  type        = map(string)
  description = "Map of labels to merge into every labelable resource created by this module."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z0-9_-]{1,63}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys and values must be lowercase and contain only letters, numbers, underscores, and dashes (max 63 characters each)."
  }
}

variable "database_version" {
  type        = string
  description = "Cloud SQL database_version string, which couples engine and version (e.g. 'POSTGRES_15', 'MYSQL_8_0'). No default — consumers must pin an explicit version."

  validation {
    condition     = can(regex("^(POSTGRES|MYSQL)_", var.database_version))
    error_message = "database_version must start with POSTGRES_ or MYSQL_ (e.g. POSTGRES_15, MYSQL_8_0)."
  }
}

variable "database_name" {
  type        = string
  description = "Name of the initial database to create inside the instance."
}

variable "master_username" {
  type        = string
  description = "Username for the master database user."
  default     = "admin"
}

variable "master_password" {
  type        = string
  description = "Password for the master database user. Consider generating this with the random provider in your root module and storing it in Secret Manager rather than passing a literal."
  sensitive   = true
}

variable "tier" {
  type        = string
  description = "Cloud SQL machine tier (e.g. 'db-custom-1-3840'). Cloud SQL has no serverless compute-autoscaling equivalent to Aurora Serverless v2 (see modules/aws/b1c-aurora-cluster) — this picks a fixed machine size. Storage autoscaling (disk_autoresize) is still on by default."
  default     = "db-custom-1-3840"
}

variable "disk_size_gb" {
  type        = number
  description = "Initial disk size in GB. Grows automatically when disk_autoresize is true."
  default     = 20
}

variable "disk_autoresize" {
  type        = bool
  description = "Enable automatic storage capacity increases. This is the closest Cloud SQL equivalent to Aurora's automatic storage scaling."
  default     = true
}

variable "vpc_network" {
  type        = string
  description = "Self-link of the VPC network to peer for private IP connectivity. The module does not create the VPC — it provisions the private-services-access peering range and connection."
}

variable "private_ip_range_prefix_length" {
  type        = number
  description = "Prefix length (CIDR /N) of the allocated IP range reserved for private services access peering."
  default     = 16
}

variable "backup_retention_days" {
  type        = number
  description = "Number of automated backups to retain (backup_configuration.backup_retention_settings.retained_backups). Must be between 1 and 365."
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 1 and 365."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the Cloud SQL instance. Defaults to true to prevent accidental data loss. Set to false only for ephemeral environments."
  default     = true
}

variable "kms_key_name" {
  type        = string
  description = "Fully qualified resource ID of a Cloud KMS CryptoKey for CMEK disk encryption. When null, Google-managed encryption is used."
  default     = null
}
```

- [ ] **Step 3: Write `main.tf`**

```hcl
# ---------------------------------------------------------------------------
# b1c-relational-db (GCP)
#
# Cloud SQL instance with private-IP connectivity, CMEK-optional disk
# encryption, automated backups, and a deletion-protection toggle.
#
# PARITY GAP: Cloud SQL has no serverless *compute* autoscaling equivalent
# to Aurora Serverless v2 (modules/aws/b1c-aurora-cluster). var.tier picks a
# fixed machine size. Storage autoscaling (disk_autoresize) IS a genuine
# parity point and is on by default.
#
# Does NOT create the VPC — var.vpc_network must reference an existing
# network self-link. The module provisions the private-services-access
# peering range required for Cloud SQL private IP.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Private services access — required for Cloud SQL private IP
# ---------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "${var.instance_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_ip_range_prefix_length
  network       = var.vpc_network
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ---------------------------------------------------------------------------
# Cloud SQL instance
# ---------------------------------------------------------------------------

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.instance_name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection
  encryption_key_name = var.kms_key_name

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.tier

    disk_size       = var.disk_size_gb
    disk_autoresize = var.disk_autoresize
    disk_type       = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    user_labels = var.labels
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "master" {
  project  = var.project_id
  name     = var.master_username
  instance = google_sql_database_instance.this.name
  password = var.master_password
}
```

- [ ] **Step 4: Write `outputs.tf`**

```hcl
output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Connection name of the instance, in the format project:region:instance. Required for the Cloud SQL Auth Proxy / connector libraries."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Name of the created database."
  value       = google_sql_database.this.name
}
```

- [ ] **Step 5: Validate the module**

```bash
terraform -chdir=modules/gcp/b1c-relational-db init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-relational-db validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Lint the module**

```bash
tflint --chdir=modules/gcp/b1c-relational-db --format compact
```

Expected: zero issues.

- [ ] **Step 7: Write `examples/basic/main.tf`**

Follows the same "look up existing infra by name" pattern as `modules/aws/b1c-aurora-cluster/examples/basic/main.tf` (the module doesn't create a VPC, so the example finds one).

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example instance into."
}

# ---------------------------------------------------------------------------
# PREREQUISITES:
# Replace this data lookup with your own VPC network, or wire this example
# to a network module output. The module does NOT create the VPC.
# ---------------------------------------------------------------------------

data "google_compute_network" "existing" {
  project = var.project_id
  name    = "default"
}

resource "random_password" "master" {
  length  = 24
  special = false
}

module "my_instance" {
  source = "../../"

  project_id       = var.project_id
  instance_name    = "my-app-db-dev"
  region           = "us-central1"
  database_version = "POSTGRES_15"
  database_name    = "myapp"
  master_username  = "dbadmin"
  master_password  = random_password.master.result

  vpc_network = data.google_compute_network.existing.self_link

  # Development-friendly settings — tighten for production
  tier                   = "db-custom-1-3840"
  deletion_protection    = false
  backup_retention_days  = 7

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "connection_name" {
  description = "Connection name for the Cloud SQL Auth Proxy / connector libraries."
  value       = module.my_instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address for application connections."
  value       = module.my_instance.private_ip_address
}
```

- [ ] **Step 8: Validate the example**

```bash
terraform -chdir=modules/gcp/b1c-relational-db/examples/basic init -backend=false -input=false
terraform -chdir=modules/gcp/b1c-relational-db/examples/basic validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 9: Write `README.md`**

```markdown
# b1c-relational-db (GCP)

A Cloud SQL instance with private-IP connectivity, optional CMEK disk encryption, automated backups, and a deletion-protection toggle. Named for the underlying product (Cloud SQL) rather than reusing "aurora" — Aurora is an AWS brand name, and there is no serverless-compute parity to justify implying one. Mirrors [`modules/aws/b1c-aurora-cluster`](../../aws/b1c-aurora-cluster/) for the GCP provider where the abstraction transfers, and documents where it doesn't.

## Features

- **Private IP only** — `ipv4_enabled = false`; the module provisions the private-services-access VPC peering range Cloud SQL private IP requires. Does not create the VPC itself.
- **Storage autoscaling** — `disk_autoresize` (default `true`) is the closest Cloud SQL equivalent to Aurora's automatic storage scaling.
- **Documented parity gap** — Cloud SQL has no serverless *compute* autoscaling equivalent to Aurora Serverless v2. `tier` picks a fixed machine size.
- **Encryption** — Google-managed by default; switch to CMEK by passing `kms_key_name`.
- **Automated backups** — point-in-time recovery enabled; `backup_retention_days` controls how many automated backups are retained (1-365).
- **Deletion protection on by default** — stricter default than the AWS module, matching Cloud SQL's own default posture.

## Usage

```hcl
module "app_db" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-relational-db?ref=v0.1.0"

  project_id       = "my-gcp-project"
  instance_name    = "my-app-db-prod"
  region           = "us-central1"
  database_version = "POSTGRES_15"
  database_name    = "myapp"
  master_username  = "dbadmin"
  master_password  = var.db_master_password # generate with the random provider; don't hardcode

  vpc_network = google_compute_network.main.self_link

  labels = { environment = "prod", project = "my-app", managed_by = "terraform" }
}

output "connection_name" {
  value = module.app_db.connection_name
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| google | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID in which to create the instance. | `string` | n/a | yes |
| instance_name | Name of the Cloud SQL instance. | `string` | n/a | yes |
| region | GCP region for the instance. | `string` | n/a | yes |
| labels | Map of labels to merge into every labelable resource. | `map(string)` | `{}` | no |
| database_version | Cloud SQL database_version string (e.g. POSTGRES_15). | `string` | n/a | yes |
| database_name | Name of the initial database. | `string` | n/a | yes |
| master_username | Username for the master database user. | `string` | `"admin"` | no |
| master_password | Password for the master database user. | `string` | n/a | yes |
| tier | Cloud SQL machine tier. | `string` | `"db-custom-1-3840"` | no |
| disk_size_gb | Initial disk size in GB. | `number` | `20` | no |
| disk_autoresize | Enable automatic storage capacity increases. | `bool` | `true` | no |
| vpc_network | Self-link of the VPC network to peer for private IP. | `string` | n/a | yes |
| private_ip_range_prefix_length | Prefix length of the peering IP range. | `number` | `16` | no |
| backup_retention_days | Number of automated backups to retain. | `number` | `7` | no |
| deletion_protection | Enable deletion protection. | `bool` | `true` | no |
| kms_key_name | Cloud KMS CryptoKey resource ID for CMEK disk encryption. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the Cloud SQL instance. |
| connection_name | Connection name (project:region:instance). |
| private_ip_address | Private IP address of the instance. |
| database_name | Name of the created database. |

<!-- END_TF_DOCS -->

## License

MIT
```

- [ ] **Step 10: Add CI matrix entries**

```yaml
          - module: modules/gcp/b1c-relational-db
```

(Add to both `matrix.include` lists in `.github/workflows/ci.yml`.)

- [ ] **Step 11: Add Dependabot entry**

```yaml
  # ── Terraform — gcp/b1c-relational-db ───────────────────────────────────────
  - package-ecosystem: "terraform"
    directory: "/modules/gcp/b1c-relational-db"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(deps):"
    groups:
      minor-and-patch:
        update-types:
          - "minor"
          - "patch"
```

- [ ] **Step 12: Format check**

```bash
terraform fmt -check -recursive
```

- [ ] **Step 13: Commit**

```bash
git add modules/gcp/b1c-relational-db .github/workflows/ci.yml .github/dependabot.yml
git commit -m "feat(modules): add gcp/b1c-relational-db (Cloud SQL mirror of b1c-aurora-cluster)"
```

---

### Task 6: `gcp-cloudrun-deploy.yml` reusable workflow

**Files:**
- Create: `.github/workflows/gcp-cloudrun-deploy.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks (workflows are independent of Terraform module internals).
- Produces: a `workflow_call` interface (`service_name`, `gcp_project_id`, `gcp_region`, `source_dir` inputs; `workload_identity_provider`, `service_account` secrets) — consumed by Task 7's caller workflow.

- [ ] **Step 1: Resolve the real commit SHA for `google-github-actions/auth`**

This repo requires every `uses:` to be pinned to a full 40-character commit SHA (`workflows-pinned-to-sha` hook). Look up the current release tag's SHA before writing the workflow file:

```bash
gh api repos/google-github-actions/auth/git/refs/tags/v2.1.6 --jq '.object.sha'
```

Use the SHA this command returns (and the actual latest stable tag, if `v2.1.6` is no longer current) in Step 2 below — do not invent one.

- [ ] **Step 2: Write `gcp-cloudrun-deploy.yml`**

```yaml
# Reusable workflow: gcp-cloudrun-deploy.yml
#
# Deploys a Cloud Run service directly from source using Cloud Run's
# buildpacks-based source deploy, authenticated via Workload Identity
# Federation. Mirrors aws-lambda-deploy.yml's shape for the GCP provider.
#
# Usage: call this workflow with `uses:` from a consumer repo:
#   jobs:
#     deploy:
#       uses: B1Codes/devops-platform/.github/workflows/gcp-cloudrun-deploy.yml@v0.1.0
#       with:
#         service_name: my-app-prod
#         gcp_project_id: my-gcp-project
#         gcp_region: us-central1
#         source_dir: src/
#       secrets:
#         workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
#         service_account: ${{ secrets.GCP_DEPLOY_SERVICE_ACCOUNT }}

on:
  workflow_call:
    inputs:
      service_name:
        description: "Name of the Cloud Run service to deploy."
        required: true
        type: string
      gcp_project_id:
        description: "GCP project ID that owns the Cloud Run service."
        required: true
        type: string
      gcp_region:
        description: "GCP region where the Cloud Run service lives (e.g. us-central1)."
        required: true
        type: string
      source_dir:
        description: "Path to the directory containing the service source code (built via Cloud Run buildpacks)."
        required: true
        type: string
      allow_unauthenticated:
        description: "Pass --allow-unauthenticated to the deploy command. Defaults to false (authenticated-only), matching the b1c-serverless-api module's default."
        required: false
        type: boolean
        default: false
    secrets:
      workload_identity_provider:
        description: "Full resource name of the Workload Identity Federation provider (e.g. projects/123/locations/global/workloadIdentityPools/github/providers/github)."
        required: true
      service_account:
        description: "Email of the GCP service account to impersonate for deployment."
        required: true

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: Deploy Cloud Run — ${{ inputs.service_name }}
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      # ── GCP auth (Workload Identity Federation) ─────────────────────────────
      - name: Authenticate to GCP (Workload Identity Federation)
        uses: google-github-actions/auth@REPLACE_WITH_SHA_FROM_STEP_1 # v2.1.6 — verify SHA before merge, see Task 6 Step 1
        with:
          workload_identity_provider: ${{ secrets.workload_identity_provider }}
          service_account: ${{ secrets.service_account }}

      - name: Set up gcloud CLI
        uses: google-github-actions/setup-gcloud@REPLACE_WITH_SHA_FROM_STEP_1 # v2.1.1 — verify SHA before merge, see Task 6 Step 1

      # ── Deploy ───────────────────────────────────────────────────────────────
      - name: Deploy to Cloud Run from source
        id: deploy
        env:
          SERVICE_NAME: ${{ inputs.service_name }}
          PROJECT_ID: ${{ inputs.gcp_project_id }}
          REGION: ${{ inputs.gcp_region }}
          SOURCE_DIR: ${{ inputs.source_dir }}
          ALLOW_UNAUTH: ${{ inputs.allow_unauthenticated }}
        shell: bash
        run: |
          set -euo pipefail
          AUTH_FLAG="--no-allow-unauthenticated"
          if [[ "${ALLOW_UNAUTH}" == "true" ]]; then
            AUTH_FLAG="--allow-unauthenticated"
          fi
          gcloud run deploy "${SERVICE_NAME}" \
            --project="${PROJECT_ID}" \
            --region="${REGION}" \
            --source="${SOURCE_DIR}" \
            "${AUTH_FLAG}" \
            --quiet \
            --format=json \
            | tee /tmp/deploy-result.json
          SERVICE_URL=$(jq -r '.status.url' /tmp/deploy-result.json)
          echo "service_url=${SERVICE_URL}" >> "${GITHUB_OUTPUT}"

      - name: Report deployed URL
        env:
          SERVICE_NAME: ${{ inputs.service_name }}
          SERVICE_URL: ${{ steps.deploy.outputs.service_url }}
        shell: bash
        run: |
          set -euo pipefail
          echo "Cloud Run service '${SERVICE_NAME}' deployed at ${SERVICE_URL}."
```

- [ ] **Step 3: Replace the SHA placeholders**

Replace both `REPLACE_WITH_SHA_FROM_STEP_1` occurrences with the real 40-character SHA resolved in Step 1 (one for `google-github-actions/auth`, and repeat the lookup for `google-github-actions/setup-gcloud` at its current tag). Update the trailing version comments to match.

- [ ] **Step 4: Lint the workflow**

```bash
actionlint .github/workflows/gcp-cloudrun-deploy.yml
```

Expected: no output (no errors).

- [ ] **Step 5: Verify the SHA-pinning hook passes**

```bash
pre-commit run workflows-pinned-to-sha --files .github/workflows/gcp-cloudrun-deploy.yml
```

Expected: `Passed`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/gcp-cloudrun-deploy.yml
git commit -m "feat(workflows): add gcp-cloudrun-deploy.yml reusable workflow"
```

---

### Task 7: `examples/gcp-cloudrun-python/`

**Files:**
- Create: `examples/gcp-cloudrun-python/main.tf`
- Create: `examples/gcp-cloudrun-python/variables.tf`
- Create: `examples/gcp-cloudrun-python/versions.tf`
- Create: `examples/gcp-cloudrun-python/src/main.py`
- Create: `examples/gcp-cloudrun-python/src/requirements.txt`
- Create: `examples/gcp-cloudrun-python/Procfile`
- Create: `examples/gcp-cloudrun-python/README.md`
- Create: `examples/gcp-cloudrun-python/.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: `modules/gcp/b1c-serverless-api` (Task 4) via `source = "../../modules/gcp/b1c-serverless-api"`; `gcp-cloudrun-deploy.yml` (Task 6) via `uses:`.

Mirrors `examples/lambda-python/` end to end: a minimal source app, a Terraform root that provisions the service via the module, and a caller workflow that deploys it.

- [ ] **Step 1: Write `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example service into."
}
```

- [ ] **Step 3: Write `main.tf`**

```hcl
# ---------------------------------------------------------------------------
# examples/gcp-cloudrun-python/main.tf
#
# Instantiates the gcp/b1c-serverless-api module to deploy a minimal Python
# Cloud Run service. The initial container_image points at Google's public
# hello-world image; gcp-cloudrun-deploy.yml (via the caller workflow in
# .github/workflows/deploy.yml) redeploys from examples/gcp-cloudrun-python/
# source on every push, which is how Cloud Run's buildpacks build actually
# replaces this placeholder image with the real application.
#
# No backend{} block here — configure remote state in a terraform.tf file
# in your own repo pointing at your Terraform state bucket. See:
# docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

module "example_python_api" {
  source = "../../modules/gcp/b1c-serverless-api"

  project_id      = var.project_id
  service_name    = "example-python-api"
  region          = "us-central1"
  container_image = "us-docker.pkg.dev/cloudrun/container/hello"

  allow_unauthenticated = true

  labels = {
    project     = "example-cloudrun-python"
    managed_by  = "terraform"
    environment = "demo"
  }
}

output "service_url" {
  description = "HTTPS URL for the deployed Cloud Run service."
  value       = module.example_python_api.service_url
}

output "service_name" {
  description = "Name of the deployed Cloud Run service."
  value       = module.example_python_api.service_name
}
```

- [ ] **Step 4: Validate the example root**

```bash
terraform -chdir=examples/gcp-cloudrun-python init -backend=false -input=false
terraform -chdir=examples/gcp-cloudrun-python validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Write the Python source app**

`examples/gcp-cloudrun-python/src/main.py`:

```python
import os

from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return "Hello from Cloud Run!"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
```

`examples/gcp-cloudrun-python/src/requirements.txt`:

```text
flask==3.0.3
gunicorn==22.0.0
```

`examples/gcp-cloudrun-python/Procfile`:

```text
web: gunicorn --bind :$PORT --chdir src main:app
```

- [ ] **Step 6: Write `.github/workflows/deploy.yml`**

```yaml
# Caller workflow: deploy the example-python-api Cloud Run service on every
# push to main.
#
# This workflow calls the reusable gcp-cloudrun-deploy.yml from this repo.
# Cloud Run builds the image from source via buildpacks on every deploy —
# there is no separate Terraform-managed image reference to keep in sync.
#
# Required GitHub Actions secrets in this repo:
#   GCP_WIF_PROVIDER            -- Workload Identity Federation provider resource name.
#   GCP_DEPLOY_SERVICE_ACCOUNT  -- Service account email GitHub Actions impersonates.
#   See docs/PREREQUISITES.md for setup instructions.
#
# NOTE: The uses: line below references @main for simplicity in this example.
# In production, pin to a specific release tag or commit SHA:
#   uses: B1Codes/devops-platform/.github/workflows/gcp-cloudrun-deploy.yml@v0.1.0

name: Deploy example-python-api (Cloud Run)

on:
  push:
    branches:
      - main
    paths:
      - "examples/gcp-cloudrun-python/src/**"
      - "examples/gcp-cloudrun-python/Procfile"
      - "examples/gcp-cloudrun-python/.github/workflows/deploy.yml"

jobs:
  deploy:
    name: Deploy Cloud Run service
    uses: B1Codes/devops-platform/.github/workflows/gcp-cloudrun-deploy.yml@main
    with:
      service_name: example-python-api
      gcp_project_id: my-gcp-project
      gcp_region: us-central1
      source_dir: examples/gcp-cloudrun-python
      allow_unauthenticated: true
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
      service_account: ${{ secrets.GCP_DEPLOY_SERVICE_ACCOUNT }}
```

- [ ] **Step 7: Write `README.md`**

```markdown
# examples/gcp-cloudrun-python

An end-to-end example showing `modules/gcp/b1c-serverless-api` provisioning a Cloud Run service, plus a caller workflow (`.github/workflows/deploy.yml`) that redeploys it via `gcp-cloudrun-deploy.yml` on every push to `main`. Mirrors [`examples/lambda-python`](../lambda-python/) for the GCP provider.

## What's here

- `main.tf` / `variables.tf` / `versions.tf` — Terraform root instantiating `modules/gcp/b1c-serverless-api`.
- `src/main.py` — a minimal Flask app (`/` and `/health` routes).
- `Procfile` — tells Cloud Run's buildpacks how to start the app.
- `.github/workflows/deploy.yml` — caller workflow using `gcp-cloudrun-deploy.yml`.

## Try it

1. `terraform init && terraform apply -var project_id=<your-gcp-project>` — provisions the Cloud Run service (initially running Google's public hello-world image).
2. Set up Workload Identity Federation in your GCP project and add `GCP_WIF_PROVIDER` / `GCP_DEPLOY_SERVICE_ACCOUNT` as repository secrets — see `docs/PREREQUISITES.md`.
3. Push a change under `src/` to `main` — the caller workflow redeploys the service from source via Cloud Run buildpacks.

## License

MIT
```

- [ ] **Step 8: Lint the caller workflow**

```bash
actionlint examples/gcp-cloudrun-python/.github/workflows/deploy.yml
```

Expected: no output. (Caller workflows under `examples/*/.github/workflows/` are exempt from the SHA-pinning hook — the `@main` reference is intentional, per the file's own header comment.)

- [ ] **Step 9: Format check**

```bash
terraform fmt -check -recursive
```

- [ ] **Step 10: Commit**

```bash
git add examples/gcp-cloudrun-python
git commit -m "feat(examples): add gcp-cloudrun-python end-to-end example"
```

---

### Task 8: `examples/gcp-static-site/` + `gcp-static-site.yml`

**Files:**
- Create: `examples/gcp-static-site/main.tf`
- Create: `examples/gcp-static-site/site/index.html`
- Create: `examples/gcp-static-site/README.md`
- Create: `examples/gcp-static-site/.github/workflows/deploy.yml`
- Create: `.github/workflows/gcp-static-site.yml`

**Interfaces:**
- Consumes: `modules/gcp/b1c-secure-bucket` (Task 3) via `source = "../../modules/gcp/b1c-secure-bucket"`.
- Produces: outputs `load_balancer_ip`, `bucket_name` used by the example's own README instructions (no other task consumes these).

Mirrors `examples/static-site/` (no dedicated Terraform module — the AWS side composes `b1c-secure-bucket` with raw `aws_cloudfront_distribution` directly in the example, and this does the same with GCS + external HTTPS Load Balancer + Cloud CDN).

- [ ] **Step 1: Write `main.tf`**

```hcl
# ---------------------------------------------------------------------------
# examples/gcp-static-site/main.tf
#
# Deploys a static website using:
#   - gcp/b1c-secure-bucket for origin storage
#   - google_compute_backend_bucket + Cloud CDN as the caching layer
#   - An external HTTPS Load Balancer (URL map, target proxy, forwarding
#     rule, managed SSL certificate) fronting the backend bucket
#
# This is the GCP architectural equivalent of examples/static-site's
# S3 + CloudFront + OAC composition — GCS buckets can't serve HTTPS on a
# custom domain on their own, so the LB + CDN stack is required, not
# optional, for parity with the AWS example.
#
# No backend{} block here -- configure remote state in your own repo.
# See docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example static site into."
}

variable "domain_name" {
  type        = string
  description = "Domain name to bind the managed SSL certificate to (e.g. 'site.example.com'). You must control DNS for this domain and point it at the load balancer's IP after apply."
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Origin bucket via the gcp/b1c-secure-bucket module
# The backend bucket resource below reads directly from GCS; no public
# bucket ACLs are needed because Cloud CDN/backend-bucket access GCS via
# the Cloud Storage API using the project's own service identity.
# ---------------------------------------------------------------------------

module "site_bucket" {
  source = "../../modules/gcp/b1c-secure-bucket"

  project_id  = var.project_id
  bucket_name = "example-static-site-${random_id.suffix.hex}"

  labels = {
    project     = "example-static-site"
    managed_by  = "terraform"
    environment = "demo"
  }
}

# ---------------------------------------------------------------------------
# Cloud CDN-enabled backend bucket
# ---------------------------------------------------------------------------

resource "google_compute_backend_bucket" "this" {
  project     = var.project_id
  name        = "example-static-site-backend"
  bucket_name = module.site_bucket.bucket_name
  enable_cdn  = true
}

# ---------------------------------------------------------------------------
# External HTTPS Load Balancer — URL map, managed cert, target proxy,
# global forwarding rule
# ---------------------------------------------------------------------------

resource "google_compute_url_map" "this" {
  project         = var.project_id
  name            = "example-static-site-url-map"
  default_service = google_compute_backend_bucket.this.id
}

resource "google_compute_managed_ssl_certificate" "this" {
  project = var.project_id
  name    = "example-static-site-cert"

  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "this" {
  project          = var.project_id
  name             = "example-static-site-https-proxy"
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
}

resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "example-static-site-ip"
}

resource "google_compute_global_forwarding_rule" "this" {
  project    = var.project_id
  name       = "example-static-site-forwarding-rule"
  target     = google_compute_target_https_proxy.this.id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "load_balancer_ip" {
  description = "Global IP address of the load balancer. Point your domain's DNS A record here."
  value       = google_compute_global_address.lb_ip.address
}

output "bucket_name" {
  description = "GCS bucket name. Pass this to gcp-static-site.yml as bucket_name."
  value       = module.site_bucket.bucket_name
}

output "backend_bucket_name" {
  description = "Name of the Cloud CDN-enabled backend bucket. Pass this to gcp-static-site.yml as backend_bucket_name for cache invalidation."
  value       = google_compute_backend_bucket.this.name
}
```

- [ ] **Step 2: Validate the example**

```bash
terraform -chdir=examples/gcp-static-site init -backend=false -input=false
terraform -chdir=examples/gcp-static-site validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Write `site/index.html`**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>GCP Static Site Example</title>
  </head>
  <body>
    <h1>Hello from GCS + Cloud CDN!</h1>
  </body>
</html>
```

- [ ] **Step 4: Write `.github/workflows/gcp-static-site.yml` (repo-root reusable workflow)**

```yaml
# Reusable workflow: gcp-static-site.yml
#
# Syncs a static site build to a GCS bucket and invalidates the Cloud CDN
# cache on the backend bucket fronting it. Mirrors aws-static-site.yml's
# shape for the GCP provider.
#
# Usage: call this workflow with `uses:` from a consumer repo:
#   jobs:
#     deploy:
#       uses: B1Codes/devops-platform/.github/workflows/gcp-static-site.yml@v0.1.0
#       with:
#         build_command: npm run build
#         build_output_dir: dist/
#         bucket_name: my-site-prod
#         backend_bucket_name: my-site-prod-backend
#         gcp_project_id: my-gcp-project
#       secrets:
#         workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
#         service_account: ${{ secrets.GCP_DEPLOY_SERVICE_ACCOUNT }}

on:
  workflow_call:
    inputs:
      build_command:
        description: "Shell command used to build the site (e.g. 'npm run build')."
        required: true
        type: string
      build_output_dir:
        description: "Directory produced by the build command that should be synced to GCS."
        required: true
        type: string
      bucket_name:
        description: "Name of the GCS bucket to sync the built site into."
        required: true
        type: string
      backend_bucket_name:
        description: "Name of the Cloud CDN-enabled backend bucket to invalidate after deployment."
        required: true
        type: string
      gcp_project_id:
        description: "GCP project ID that owns the bucket and backend bucket."
        required: true
        type: string
      node_version:
        description: "Node.js version to install for the build step."
        required: false
        type: string
        default: "20"
    secrets:
      workload_identity_provider:
        description: "Full resource name of the Workload Identity Federation provider."
        required: true
      service_account:
        description: "Email of the GCP service account to impersonate for deployment."
        required: true

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: Deploy static site to GCS + Cloud CDN
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Set up Node.js
        uses: actions/setup-node@0a44ba7841725637a19e28fa30b79a866c81b0a6 # v4.0.4
        with:
          node-version: ${{ inputs.node_version }}
          cache: "npm"

      - name: Install npm dependencies
        shell: bash
        run: |
          set -euo pipefail
          if [[ -f "package-lock.json" ]]; then
            echo "Found package-lock.json — using 'npm ci'."
            npm ci
          else
            echo "No package-lock.json — using 'npm install'."
            npm install
          fi

      - name: Build site
        env:
          BUILD_CMD: ${{ inputs.build_command }}
        shell: bash
        run: |
          set -euo pipefail
          eval "${BUILD_CMD}"

      # ── GCP auth (Workload Identity Federation) ─────────────────────────────
      - name: Authenticate to GCP (Workload Identity Federation)
        uses: google-github-actions/auth@REPLACE_WITH_SHA_FROM_TASK_6_STEP_1 # v2.1.6 — verify SHA before merge
        with:
          workload_identity_provider: ${{ secrets.workload_identity_provider }}
          service_account: ${{ secrets.service_account }}

      - name: Set up gcloud CLI
        uses: google-github-actions/setup-gcloud@REPLACE_WITH_SHA_FROM_TASK_6_STEP_1 # v2.1.1 — verify SHA before merge

      # ── Sync to GCS ──────────────────────────────────────────────────────────
      - name: Sync to GCS
        env:
          BUILD_OUTPUT_DIR: ${{ inputs.build_output_dir }}
          BUCKET_NAME: ${{ inputs.bucket_name }}
        shell: bash
        run: |
          set -euo pipefail
          gcloud storage rsync "${BUILD_OUTPUT_DIR}" "gs://${BUCKET_NAME}" --delete-unmatched-destination-objects
          echo "Sync to gs://${BUCKET_NAME} complete."

      # ── Cloud CDN cache invalidation ─────────────────────────────────────────
      - name: Invalidate Cloud CDN cache
        env:
          PROJECT_ID: ${{ inputs.gcp_project_id }}
          BACKEND_BUCKET_NAME: ${{ inputs.backend_bucket_name }}
        shell: bash
        run: |
          set -euo pipefail
          gcloud compute url-maps invalidate-cdn-cache "${BACKEND_BUCKET_NAME}" \
            --project="${PROJECT_ID}" \
            --path="/*" \
            --quiet
          echo "Cloud CDN cache invalidated for backend bucket ${BACKEND_BUCKET_NAME}."
```

Reuse the same real SHAs resolved in Task 6 Step 1 — replace both `REPLACE_WITH_SHA_FROM_TASK_6_STEP_1` occurrences.

- [ ] **Step 5: Write `.github/workflows/deploy.yml` (example caller workflow)**

```yaml
# Caller workflow: deploy the example static site on every push to main.
#
# This workflow calls the reusable gcp-static-site.yml from this repo.
# The bucket, backend bucket, load balancer, and managed SSL certificate
# must already exist (created by terraform apply against examples/gcp-static-site/main.tf).
#
# Required GitHub Actions secrets in this repo:
#   GCP_WIF_PROVIDER            -- Workload Identity Federation provider resource name.
#   GCP_DEPLOY_SERVICE_ACCOUNT  -- Service account email GitHub Actions impersonates.
#   See docs/PREREQUISITES.md for setup instructions.
#
# NOTE: The uses: line below references @main for simplicity in this example.
# In production, pin to a specific release tag or commit SHA.

name: Deploy example static site (GCS + Cloud CDN)

on:
  push:
    branches:
      - main
    paths:
      - "examples/gcp-static-site/site/**"
      - "examples/gcp-static-site/.github/workflows/deploy.yml"

jobs:
  deploy:
    name: Deploy static site
    uses: B1Codes/devops-platform/.github/workflows/gcp-static-site.yml@main
    with:
      build_command: "true" # no build step needed — plain HTML in site/
      build_output_dir: examples/gcp-static-site/site
      bucket_name: example-static-site-REPLACE_WITH_TERRAFORM_OUTPUT
      backend_bucket_name: example-static-site-backend
      gcp_project_id: my-gcp-project
    secrets:
      workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
      service_account: ${{ secrets.GCP_DEPLOY_SERVICE_ACCOUNT }}
```

- [ ] **Step 6: Write `README.md`**

```markdown
# examples/gcp-static-site

An end-to-end example showing `modules/gcp/b1c-secure-bucket` composed with a GCS backend bucket, Cloud CDN, and an external HTTPS Load Balancer, deployed via `gcp-static-site.yml`. Mirrors [`examples/static-site`](../static-site/) for the GCP provider — GCS + Cloud CDN + Load Balancer is the architectural equivalent of S3 + CloudFront + OAC.

## What's here

- `main.tf` — Terraform root: `gcp/b1c-secure-bucket` + backend bucket + URL map + managed SSL cert + HTTPS proxy + global forwarding rule.
- `site/index.html` — the static content to deploy.
- `.github/workflows/deploy.yml` — caller workflow using `gcp-static-site.yml`.

## Try it

1. `terraform init && terraform apply -var project_id=<your-gcp-project> -var domain_name=<your-domain>` — provisions the bucket, CDN, and load balancer.
2. Point your domain's DNS A record at the `load_balancer_ip` output. Managed SSL certificate provisioning can take up to an hour after DNS propagates.
3. Fill in the real `bucket_name` Terraform output into `.github/workflows/deploy.yml`'s `bucket_name` input (Terraform appends a random suffix, so this is not knowable in advance).
4. Set up Workload Identity Federation and add `GCP_WIF_PROVIDER` / `GCP_DEPLOY_SERVICE_ACCOUNT` as repository secrets — see `docs/PREREQUISITES.md`.
5. Push a change under `site/` to `main` — the caller workflow syncs it to GCS and invalidates the CDN cache.

## License

MIT
```

- [ ] **Step 7: Lint both workflows**

```bash
actionlint .github/workflows/gcp-static-site.yml examples/gcp-static-site/.github/workflows/deploy.yml
```

Expected: no output.

- [ ] **Step 8: Verify the SHA-pinning hook passes on the reusable workflow**

```bash
pre-commit run workflows-pinned-to-sha --files .github/workflows/gcp-static-site.yml
```

Expected: `Passed`. (The example caller workflow is exempt, per repo convention.)

- [ ] **Step 9: Format check**

```bash
terraform fmt -check -recursive
```

- [ ] **Step 10: Commit**

```bash
git add examples/gcp-static-site .github/workflows/gcp-static-site.yml
git commit -m "feat(workflows,examples): add gcp-static-site.yml and gcp-static-site example"
```

---

### Task 9: Documentation pass — README, ARCHITECTURE, CLAUDE.md, b1/context, RELEASE-CHECKLIST, CHANGELOG

**Files:**
- Modify: `README.md`, `docs/ARCHITECTURE.md`, `CLAUDE.md`, `b1/context/consumer-wiring.md`, `b1/context/portability.md`, `RELEASE-CHECKLIST.md`, `CHANGELOG.md`, `CONTRIBUTING.md`

**Interfaces:** none — this task only touches prose/diagrams describing the code Tasks 1-8 already shipped.

- [ ] **Step 1: Update `README.md`**

Change the top tagline:

```markdown
Open-source AWS + GCP deployment engine: reusable GitHub Actions workflows and Terraform modules.
```

Update the "Why this exists" paragraph's last sentence to drop the AWS-only framing:

```markdown
This repository codifies a "Golden Path": a single, opinionated set of Terraform modules and reusable GitHub Actions workflows that any project can call instead of building from scratch. It fills the gap between "I have a cloud account" and "I have a working, cost-tracked, secure CI/CD pipeline," on AWS or GCP, without locking consumers into a proprietary platform.
```

Update the Mermaid diagram's engine subgraph to list both providers:

```
    subgraph engine["devops-platform (this repo)"]
        direction TB
        rw["Reusable Workflows\n(aws-lambda-deploy.yml, aws-static-site.yml,\ngcp-cloudrun-deploy.yml, gcp-static-site.yml,\nterraform-plan-cost.yml)"]
        tfaws["modules/aws/\n(b1c-secure-bucket\nb1c-serverless-api\nb1c-aurora-cluster)"]
        tfgcp["modules/gcp/\n(b1c-secure-bucket\nb1c-serverless-api\nb1c-relational-db)"]
    end
```

(Adjust the surrounding `caller -->`, `rw -->`, `tf* -->` edges so both `tfaws` and `tfgcp` connect the same way `tf` did before — same state/services targets, just two module boxes instead of one.)

Update the "What's inside" bullets:

```markdown
- **`modules/`** — Reusable Terraform building blocks, split by provider:
  - `modules/aws/` — `b1c-secure-bucket` (S3), `b1c-serverless-api` (Lambda + API Gateway v2), `b1c-aurora-cluster` (Aurora Serverless v2).
  - `modules/gcp/` — `b1c-secure-bucket` (GCS), `b1c-serverless-api` (Cloud Run), `b1c-relational-db` (Cloud SQL).

- **`.github/workflows/`** — Reusable GitHub Actions workflows (called via `workflow_call`):
  - `aws-lambda-deploy.yml` / `gcp-cloudrun-deploy.yml` — packages source and deploys to Lambda / Cloud Run.
  - `aws-static-site.yml` / `gcp-static-site.yml` — builds a frontend, syncs to S3+CloudFront / GCS+Cloud CDN.
  - `terraform-plan-cost.yml` — runs `terraform plan` and posts an Infracost diff comment on pull requests (provider-agnostic).
```

- [ ] **Step 2: Update `docs/ARCHITECTURE.md`**

Add a new subsection after "### Layer 1 — Terraform Modules (`modules/`)" noting the provider split:

```markdown
Modules are organized by provider: `modules/aws/` and `modules/gcp/`. Module
names stay identical across providers where the abstraction genuinely maps
1:1 (`b1c-secure-bucket`, `b1c-serverless-api`); where it doesn't, the GCP
module is named for the actual product rather than reusing an AWS brand
name (`b1c-relational-db`, not `b1c-aurora-cluster`).

| Module | Provider | What it creates |
|---|---|---|
| `modules/aws/b1c-secure-bucket` | AWS | S3 bucket with encryption, versioning, public-access blocks |
| `modules/aws/b1c-serverless-api` | AWS | Lambda + API Gateway v2 + IAM execution role + CloudWatch log group |
| `modules/aws/b1c-aurora-cluster` | AWS | Aurora Serverless v2 cluster with KMS encryption and subnet group |
| `modules/gcp/b1c-secure-bucket` | GCP | GCS bucket with encryption, versioning, public-access prevention |
| `modules/gcp/b1c-serverless-api` | GCP | Cloud Run v2 service + dedicated runtime service account |
| `modules/gcp/b1c-relational-db` | GCP | Cloud SQL instance with private IP, CMEK-optional encryption |
```

Add a matching sentence to "### Layer 2 — Reusable Workflows" noting `gcp-cloudrun-deploy.yml` and `gcp-static-site.yml` exist alongside their AWS counterparts and use Workload Identity Federation instead of OIDC role assumption.

Add to "## Conventions enforced by this design", a fifth bullet:

```markdown
- **WIF only (GCP).** No GCP-facing workflow accepts a static service-account
  JSON key. All GCP authentication flows through Workload Identity
  Federation via `google-github-actions/auth` — the GCP equivalent of the
  OIDC-only rule above.
```

- [ ] **Step 3: Update `CLAUDE.md` (repo root)**

Update the "Repository context" bullet list to add the GCP line (from Task 1 Step 8, the AWS line already reads `modules/aws/`):

```markdown
- **Generic Terraform modules** under `modules/aws/` (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-aurora-cluster`) and `modules/gcp/` (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-relational-db`), consumed via `source = "github.com/B1Codes/devops-platform//modules/<provider>/<name>?ref=<tag>"`.
- **Reusable `workflow_call` GitHub Actions** under `.github/workflows/` (`aws-lambda-deploy.yml`, `aws-static-site.yml`, `gcp-cloudrun-deploy.yml`, `gcp-static-site.yml`, `terraform-plan-cost.yml`) consumed via `uses: B1Codes/devops-platform/.github/workflows/<name>.yml@<sha>`.
```

Add a new bullet under "## Non-negotiable conventions" (as item 5, renumbering nothing else — additive):

```markdown
5. **WIF only (GCP).** No workflow accepts a GCP service-account JSON key (`credentials_json:`). GCP auth always flows through Workload Identity Federation via `google-github-actions/auth`.
```

- [ ] **Step 4: Update `b1/context/consumer-wiring.md`**

Add a new section after the existing `b1c-aurora-cluster` minimum-viable block, before "## Reusable workflow via `workflow_call`":

```markdown
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
```

Add two rows to the "Quick reference for the three workflows" table (retitle it "five workflows"):

```markdown
| `gcp-cloudrun-deploy.yml` | Deploy to Cloud Run from source via WIF | `service_name`, `gcp_project_id`, `gcp_region`, `source_dir` |
| `gcp-static-site.yml` | Build, GCS sync, Cloud CDN invalidation | `build_command`, `build_output_dir`, `bucket_name`, `backend_bucket_name`, `gcp_project_id` |
```

- [ ] **Step 5: Update `b1/context/portability.md`**

Change "Any value that only makes sense inside B1Codes' AWS Organization" to:

```markdown
- Any value that only makes sense inside B1Codes' AWS Organization or GCP resource hierarchy.
```

Add a second grep invocation alongside the existing account-ID check:

```markdown
# 1b. No hardcoded GCP project/org numbers (also commonly numeric literals).
grep -rE '"[0-9]{9,12}"' --include='*.tf' --include='*.yml' --include='*.yaml' --include='*.md'
```

- [ ] **Step 6: Update `RELEASE-CHECKLIST.md`**

Add the matching checklist item next to the existing AWS account ID check:

```markdown
- [ ] No hardcoded GCP project/org numbers in any tracked file:
      ```bash
      grep -rE '"[0-9]{9,12}"' --include='*.tf' --include='*.yml' --include='*.yaml' --include='*.md'
      ```
      Review any hits — GCP project numbers and organization IDs are
      typically 9-12 digit numeric strings.
```

Add `terraform-docs` regeneration commands for the three new GCP modules next to the existing three:

```bash
terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-secure-bucket
terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-serverless-api
terraform-docs markdown table --config .terraform-docs.yml modules/gcp/b1c-relational-db
```

- [ ] **Step 7: Update `CHANGELOG.md`**

Add three bullets to the `[Unreleased]` section, alongside the existing three AWS module bullets:

```markdown
- `modules/gcp/b1c-secure-bucket` — Opinionated GCS bucket with encryption,
  versioning, public access prevention, and optional Workload Identity
  Federation IAM binding.
- `modules/gcp/b1c-serverless-api` — Cloud Run v2 service with a dedicated
  runtime service account and configurable autoscaling.
- `modules/gcp/b1c-relational-db` — Cloud SQL instance with private IP,
  CMEK-optional encryption, and automated backups.
- `gcp-cloudrun-deploy.yml` — deploys a Cloud Run service from source via
  Workload Identity Federation.
- `gcp-static-site.yml` — builds a frontend, syncs to GCS, and invalidates
  Cloud CDN.
```

- [ ] **Step 8: Update `CONTRIBUTING.md`**

Add a short note to the "Local development" section, after the existing `terraform validate` snippet, documenting the provider version convention:

```markdown
### Provider version pinning

AWS modules pin `hashicorp/aws ~> 5.0`; GCP modules pin `hashicorp/google ~> 6.0`. When adding a new module, match the major version already in use by its sibling modules for that provider unless you have a specific reason to bump — check `versions.tf` in an existing module under the same `modules/<provider>/` directory.
```

- [ ] **Step 9: Full-repo verification**

```bash
terraform fmt -check -recursive
pre-commit run --all-files
```

Expected: both commands exit 0 with no unresolved issues.

- [ ] **Step 10: Commit**

```bash
git add README.md docs/ARCHITECTURE.md CLAUDE.md b1/context/consumer-wiring.md b1/context/portability.md RELEASE-CHECKLIST.md CHANGELOG.md CONTRIBUTING.md
git commit -m "docs: document GCP modules and workflows across README, ARCHITECTURE, and b1 context"
```

---

## Self-Review Notes

- **Spec coverage:** every section of `2026-07-19-gcp-expansion-design.md` maps to a task — directory restructure (Task 1), tflint plugin (Task 2), three GCP modules (Tasks 3-5), `gcp-cloudrun-deploy.yml` (Task 6), `examples/gcp-cloudrun-python/` (Task 7), `gcp-static-site.yml` + `examples/gcp-static-site/` (Task 8), and the full documentation/tooling list from the spec's "Tooling & documentation updates" section (Task 9). `terraform-plan-cost.yml` is explicitly left untouched per the spec's decision log — no task modifies it.
- **Placeholder scan:** the only intentional placeholders are the `REPLACE_WITH_SHA_FROM_STEP_1` / `REPLACE_WITH_SHA_FROM_TASK_6_STEP_1` tokens in Tasks 6 and 8, and `bucket_name: example-static-site-REPLACE_WITH_TERRAFORM_OUTPUT` in Task 8's example caller workflow. Each has an explicit resolving step immediately following it (Task 6 Step 1's `gh api` lookup; Task 8's README step 3) — these are not left dangling, matching the repo's own precedent for the markdownlint action SHA in `ci.yml`.
- **Type/interface consistency:** `modules/gcp/b1c-secure-bucket` outputs (`bucket_name`, `bucket_url`, `bucket_self_link`) match what Task 8's `examples/gcp-static-site/main.tf` consumes (`module.site_bucket.bucket_name`). `modules/gcp/b1c-serverless-api` outputs (`service_name`, `service_url`, `runtime_service_account_email`) match Task 7's `examples/gcp-cloudrun-python/main.tf` consumption (`module.example_python_api.service_url`, `.service_name`). `gcp-cloudrun-deploy.yml`'s `workflow_call` inputs (`service_name`, `gcp_project_id`, `gcp_region`, `source_dir`, `allow_unauthenticated`) match exactly what Task 7's caller workflow passes under `with:`.
