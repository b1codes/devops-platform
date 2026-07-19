# GCP Expansion Design

**Date:** 2026-07-19
**Status:** Approved, not yet implemented
**Scope:** `devops-platform` (public engine) only. No changes to `llc-infra-core`.

## Context

`devops-platform` currently exposes AWS-only primitives: three Terraform
modules (`b1c-secure-bucket`, `b1c-serverless-api`, `b1c-aurora-cluster`)
under `modules/`, and three reusable GitHub Actions workflows
(`aws-lambda-deploy.yml`, `aws-static-site.yml`, `terraform-plan-cost.yml`)
under `.github/workflows/`. This design adds a parallel GCP-backed set of
primitives following the same "Golden Path" methodology described in
`docs/ARCHITECTURE.md`.

The repo is pre-`v0.1.0` (no tag cut yet, per `CLAUDE.md` and
`CHANGELOG.md`), so restructuring the existing AWS module paths is a
zero-cost change — there are no external consumers to break.

## Goals

- Give consumers a GCP-backed equivalent of every existing AWS module and
  deploy workflow, following the same conventions (no `backend {}` in
  modules, no hardcoded identifiers, README + `examples/basic` per module,
  short-lived federated auth only).
- Keep the two provider surfaces symmetric and independently extensible
  (a third provider later should follow the same pattern without needing
  another restructure).
- Preserve portability discipline (`b1/context/portability.md`): no
  B1Codes-specific or account/project-specific values in module bodies.

## Explicitly out of scope

- Any change to `llc-infra-core` (the private Brain layer, `tier1-serverless`,
  `tier2-container`). GCP governance (Cloud Resource Manager, Workload
  Identity Federation setup at the org level, GCS state backend) and GCP
  variants of the tier wrappers are a separate, later design once these
  public-engine primitives exist to wrap.
- Cloud Functions Gen2 (Cloud Run was chosen — see Decision Log).
- Any Azure or additional-provider work.

## Directory & naming architecture

Existing AWS modules move under `modules/aws/`; new GCP modules land under
`modules/gcp/`. Module names stay role-based where the abstraction maps 1:1
across providers, and product-accurate where it doesn't (see
`b1c-relational-db` below — "aurora" is an AWS brand name and doesn't belong
in a GCP module).

```
modules/
  aws/
    b1c-secure-bucket/
    b1c-serverless-api/
    b1c-aurora-cluster/
  gcp/
    b1c-secure-bucket/           # GCS
    b1c-serverless-api/          # Cloud Run
    b1c-relational-db/           # Cloud SQL

examples/
  lambda-python/                 # existing, AWS
  static-site/                   # existing, AWS
  gcp-cloudrun-python/           # new
  gcp-static-site/               # new
```

`examples/gcp-*` mirrors `examples/lambda-python` and `examples/static-site`
in shape and README structure.

## Module specs

### `modules/gcp/b1c-secure-bucket`

Mirrors `modules/aws/b1c-secure-bucket`.

- `google_storage_bucket` with `uniform_bucket_level_access = true` and
  `public_access_prevention = "enforced"` (GCS's block-public-access
  equivalent of the AWS module's `aws_s3_bucket_public_access_block`).
- Versioning on by default; lifecycle rule expiring noncurrent versions
  after `var.noncurrent_version_expiration_days` (same variable name/default
  as the AWS module for parity).
- Encryption: Google-managed by default; optional CMEK via
  `var.kms_key_name` (a Cloud KMS `CryptoKey` resource ID), mirroring
  `var.kms_key_arn`.
- Optional IAM binding (`google_storage_bucket_iam_member`) granting a
  Workload-Identity-federated principal object get/put/delete/list, via
  `var.wif_principal_member` (format `principalSet://...` or
  `serviceAccount:...`), replacing `var.oidc_principal_arn`. Null by
  default → no binding created, same behavior as the AWS module.
- `var.tags` becomes `var.labels`. **Not a silent rename** — GCS labels are
  lowercase-only with a stricter charset than AWS tags. The module
  validates this with a `validation` block and the README calls it out as
  a footgun for anyone porting tag maps from the AWS side.
- `var.bucket_name` requires global uniqueness, same constraint as S3.
  Additionally requires `var.project_id` (GCP resources are always scoped
  to a project; there's no AWS-account-level implicit scoping equivalent).

### `modules/gcp/b1c-serverless-api`

Mirrors `modules/aws/b1c-serverless-api`. Targets **Cloud Run**, not Cloud
Functions Gen2 (see Decision Log).

- `google_cloud_run_v2_service` deployed from `var.container_image` — a
  container image reference, not a zip/source directory. This is the one
  place the deploy *model* genuinely diverges from Lambda; documented
  prominently in the module README, not hidden behind matching variable
  names.
- IAM invoker binding (`google_cloud_run_v2_service_iam_member`) controls
  public vs. authenticated access via `var.allow_unauthenticated` (default
  `false`).
- Dedicated `google_service_account` created as the service's runtime
  identity — parallels the Lambda execution role in the AWS module.
- `var.min_instance_count` / `var.max_instance_count` cover autoscaling;
  `var.memory` (e.g. `"512Mi"`) and `var.cpu` (e.g. `"1"`) replace
  `var.memory_mb`.
- No separate CloudWatch-log-group-equivalent resource: Cloud Run wires
  stdout/stderr to Cloud Logging automatically. README notes this is a
  platform difference, not a missing feature.
- No API Gateway resource: Cloud Run's built-in HTTPS endpoint replaces
  the AWS module's API Gateway v2 + Lambda integration. A unified
  API-Gateway-style front door across multiple Cloud Run services is out
  of scope for v1 (documented as a known parity gap).

### `modules/gcp/b1c-relational-db`

Mirrors `modules/aws/b1c-aurora-cluster`, but named for the product
(Cloud SQL) rather than reusing "aurora," an AWS brand name that doesn't
translate.

- `google_sql_database_instance` + `google_sql_database` +
  `google_sql_user`, replacing the AWS module's cluster/database/master-user
  resources.
- **Documented parity gap:** Cloud SQL has no serverless *compute*
  autoscaling equivalent to Aurora Serverless v2. `var.tier` picks a fixed
  machine tier (small default, e.g. `db-custom-1-3840`). Storage
  autoscaling (`disk_autoresize = true`) is a genuine parity point and is
  on by default.
- Private connectivity requires a VPC peering range
  (`google_service_networking_connection`) — one more moving part than the
  AWS module's subnet-group wiring. `var.vpc_network` (self-link) replaces
  `var.vpc_id`; the peering range is provisioned by the module.
- `var.engine` accepts `POSTGRES_15`/`MYSQL_8_0`-style Cloud SQL version
  strings (mirrors the AWS module's `engine`/`engine_version` split, but
  Cloud SQL couples engine+version into one `database_version` string, so
  the module exposes a single `var.database_version` instead of two
  variables).
- CMEK optional via `disk_encryption_configuration`; `deletion_protection`
  defaults to `true` (stricter default than the AWS module, matching
  Cloud SQL's own default behavior).

## Workflow specs

### `gcp-cloudrun-deploy.yml`

Mirrors `aws-lambda-deploy.yml`.

- Auth via `google-github-actions/auth` (Workload Identity Federation).
  Needs **two** identifiers where AWS needs one: `workload_identity_provider`
  (full resource name of the WIF provider) and `service_account` (email of
  the service account to impersonate). Both passed as `secrets:` inputs,
  matching the existing convention of treating federated-auth identifiers
  as secrets even though neither is a traditional credential.
- Deploy step: `gcloud run deploy SERVICE --source=DIR`, using Cloud Run's
  buildpacks-based source deploy — the closest one-command mirror to
  `aws lambda update-function-code`. Avoids a separate Docker
  build/push step in v1; revisit if consumers need custom Dockerfiles.
- Inputs mirror `aws-lambda-deploy.yml` field-for-field where possible:
  `service_name` (↔ `function_name`), `gcp_project_id`, `gcp_region` (↔
  `aws_region`), `source_dir`.

### `gcp-static-site.yml` + `examples/gcp-static-site/`

Mirrors `aws-static-site.yml` + `examples/static-site/`. **Not a new
Terraform module** — the AWS side has no dedicated static-site module
either; `examples/static-site/main.tf` composes `b1c-secure-bucket` with a
raw `aws_cloudfront_distribution` directly. The GCP mirror follows the same
composition pattern:

- `examples/gcp-static-site/main.tf` composes `modules/gcp/b1c-secure-bucket`
  with `google_compute_backend_bucket`, `google_compute_url_map`,
  `google_compute_target_https_proxy`, `google_compute_global_forwarding_rule`,
  and `google_compute_managed_ssl_certificate` — GCP's external HTTPS
  Load Balancer + Cloud CDN stack, the architectural equivalent of
  S3 + CloudFront + OAC.
- `gcp-static-site.yml` workflow: `gcloud storage rsync` (↔ `aws s3 sync`)
  + `gcloud compute url-maps invalidate-cdn-cache` (↔ CloudFront
  invalidation), with the same `wait_for_invalidation`-style optional wait
  input.

### `terraform-plan-cost.yml`

Untouched. Infracost prices GCP resources from the Terraform plan
automatically; no code change needed.

## New convention: "WIF only"

Parallel to the existing "OIDC only" rule (`CLAUDE.md` non-negotiable #4):
no GCP-facing workflow accepts a static service-account JSON key
(`credentials_json:`). All GCP authentication flows through Workload
Identity Federation via `google-github-actions/auth`. Enforced via review
for v1; a `workflows-pinned-to-sha`-style pygrep hook that flags
`credentials_json:` usage is a nice-to-have follow-up, not required to ship
this design.

## Tooling & documentation updates

- **`.tflint.hcl`**: add `plugin "google"` (`tflint-ruleset-google`)
  alongside the existing `plugin "aws"`.
- **`.github/workflows/ci.yml`**: the hardcoded `matrix.module` list (both
  the `terraform validate` and `tflint` jobs) updates to the new
  `modules/aws/*` paths and gains three `modules/gcp/*` entries.
- **`README.md`** and **`docs/ARCHITECTURE.md`**: module table and the two
  Mermaid diagrams gain a GCP column/branch.
- **`b1/context/*.md`**: short GCP section added alongside existing AWS
  content (conventions, footguns, portability).
- **`RELEASE-CHECKLIST.md`** / **`b1/context/portability.md`**: the
  "no hardcoded AWS account ID" grep gains a parallel pattern for GCP
  project/org numbers (also commonly numeric literals). The existing
  `B1Codes\|llc-infra-core\|b1codes` grep already covers both providers
  as-is, no change needed there.
- **`CONTRIBUTING.md`**: document the `hashicorp/google` provider version
  constraint convention (`~> 6.0`, mirroring the AWS module's `~> 5.0`
  pattern) — exact version to be confirmed against current release at
  implementation time.
- Module-documentation contract (README + `examples/basic/main.tf` per
  module) applies identically to the three new GCP modules.

## Decision log

| Decision | Choice | Why |
|---|---|---|
| Module directory layout | `modules/aws/*` + `modules/gcp/*` (moved existing) | Symmetric, scales to a 3rd provider, free to do pre-v0.1.0 |
| Serverless compute target | Cloud Run, not Cloud Functions Gen2 | Cloud Functions Gen2 is a thinner wrapper over Cloud Run; GCP steers new HTTP workloads to Cloud Run directly; built-in HTTPS + IAM invoker avoids a separate API Gateway resource |
| Static site hosting | GCS + Cloud CDN + external HTTPS LB, not Firebase Hosting | Chosen for architectural parity with S3 + CloudFront over Firebase's simpler but non-parallel DX |
| `terraform-plan-cost.yml` | Left unchanged | Infracost is already provider-agnostic |
| DB module name | `b1c-relational-db`, not `b1c-aurora-cluster`-style | "Aurora" is an AWS brand name; no GCP product shares it, and there's no serverless-compute parity to justify implying one |

## Open items for implementation time

- Confirm current `hashicorp/google` provider major version before pinning
  `~> 6.0` in `versions.tf` for the new modules.
- Confirm current pinned SHAs for `google-github-actions/auth` and any
  `google-github-actions/setup-gcloud` action before wiring the new
  workflows (repo convention requires full 40-character SHA pins with a
  trailing version comment).
