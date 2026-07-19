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
