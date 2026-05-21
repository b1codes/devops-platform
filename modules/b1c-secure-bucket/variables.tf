variable "bucket_name" {
  type        = string
  description = "Globally unique name for the S3 bucket."
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to merge into every taggable resource created by this module."
  default     = {}
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable S3 bucket versioning. Highly recommended for production workloads."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of a customer-managed KMS key to use for SSE-KMS encryption. When null, SSE-S3 (AES256) is used."
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

variable "oidc_principal_arn" {
  type        = string
  description = "ARN of an IAM role (typically an OIDC-federated GitHub Actions role) that will be granted GetObject, PutObject, ListBucket, and DeleteObject on this bucket. When null, no bucket policy is created."
  default     = null
}

variable "force_destroy" {
  type        = bool
  description = "When true, all objects (including non-current versions) are deleted when the bucket is destroyed. Set to false in production to prevent accidental data loss."
  default     = false
}
