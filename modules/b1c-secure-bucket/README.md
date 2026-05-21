# b1c-secure-bucket

A hardened S3 bucket module that enforces encryption, blocks all public access, enables versioning, and optionally grants an OIDC-federated IAM role scoped read/write access via a bucket policy.

## Features

- **All public access blocked** — all four `aws_s3_bucket_public_access_block` settings set to `true`.
- **Server-side encryption** — SSE-S3 (AES256) by default; switch to SSE-KMS by passing a `kms_key_arn`.
- **Versioning** — enabled by default; configurable via `versioning_enabled`.
- **Noncurrent version lifecycle** — a lifecycle rule automatically expires noncurrent object versions after `noncurrent_version_expiration_days` (default 90) days.
- **Optional OIDC bucket policy** — pass `oidc_principal_arn` to grant a GitHub Actions OIDC role (or any IAM role ARN) `GetObject`, `PutObject`, `DeleteObject`, and `ListBucket` on this bucket only. No policy resource is created when the variable is null.
- **Generic and tagless by default** — no hardcoded tags; merge your own via `var.tags`.

## Usage

```hcl
module "artifacts_bucket" {
  source = "github.com/B1Codes/devops-platform//modules/b1c-secure-bucket?ref=v0.1.0"

  bucket_name = "my-org-my-app-artifacts-prod"

  # Optional: grant a GitHub Actions role access
  oidc_principal_arn = "arn:aws:iam::123456789012:role/GitHubActionsRole"

  # Optional: use a customer-managed KMS key instead of SSE-S3
  # kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/mrk-abc123"

  tags = {
    Environment = "prod"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "bucket_arn" {
  value = module.artifacts_bucket.bucket_arn
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

## Notes

- `force_destroy` defaults to `false`. Set it to `true` only in ephemeral/dev environments where data loss is acceptable.
- When `kms_key_arn` is set, `bucket_key_enabled` is automatically set to `true` to reduce KMS API call costs.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-generates the inputs/outputs tables between these markers. -->
<!-- Run: terraform-docs markdown table --output-file README.md . -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| bucket_name | Globally unique name for the S3 bucket. | `string` | — | yes |
| tags | Map of tags to merge into every taggable resource. | `map(string)` | `{}` | no |
| versioning_enabled | Enable S3 bucket versioning. | `bool` | `true` | no |
| kms_key_arn | ARN of a CMK for SSE-KMS encryption. Null uses SSE-S3. | `string` | `null` | no |
| noncurrent_version_expiration_days | Days after which noncurrent versions are deleted. | `number` | `90` | no |
| oidc_principal_arn | IAM role ARN granted read/write access via bucket policy. | `string` | `null` | no |
| force_destroy | Delete all objects when bucket is destroyed. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_arn | ARN of the S3 bucket. |
| bucket_id | Name (ID) of the S3 bucket. |
| bucket_regional_domain_name | Regional domain name (e.g. for CloudFront origins). |

<!-- END_TF_DOCS -->

## License

MIT
