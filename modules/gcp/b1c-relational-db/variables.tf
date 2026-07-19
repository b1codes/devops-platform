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
