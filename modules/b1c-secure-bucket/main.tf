# ---------------------------------------------------------------------------
# b1c-secure-bucket
#
# Opinionated S3 bucket with:
#   - All public access blocked
#   - Server-side encryption (SSE-S3 default, SSE-KMS optional)
#   - Versioning (enabled by default)
#   - Lifecycle rule to expire noncurrent versions
#   - Optional bucket policy granting an OIDC-federated role read/write access
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# S3 Bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

# ---------------------------------------------------------------------------
# Block all public access
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ---------------------------------------------------------------------------
# Server-side encryption
# SSE-S3 (AES256) is the default. When var.kms_key_arn is set, SSE-KMS is
# used with the provided CMK.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }

    # Prevent uploading objects with SSE disabled when using CMK
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

# ---------------------------------------------------------------------------
# Lifecycle configuration — expire noncurrent object versions
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Lifecycle rules require versioning to be fully consistent; add an explicit
  # dependency so the rule is applied after versioning is configured.
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

# ---------------------------------------------------------------------------
# Optional bucket policy — OIDC principal access
# Only created when var.oidc_principal_arn is non-null.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "oidc_access" {
  count = var.oidc_principal_arn != null ? 1 : 0

  statement {
    sid    = "OIDCPrincipalBucketAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.oidc_principal_arn]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid    = "OIDCPrincipalListBucket"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.oidc_principal_arn]
    }

    actions = ["s3:ListBucket"]

    resources = [aws_s3_bucket.this.arn]
  }
}

resource "aws_s3_bucket_policy" "oidc_access" {
  count = var.oidc_principal_arn != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.oidc_access[0].json

  # Policy must be applied after the public access block; otherwise Terraform
  # may fail if the bucket doesn't yet have the block in place.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
