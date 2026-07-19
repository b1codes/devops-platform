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
