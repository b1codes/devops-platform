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
