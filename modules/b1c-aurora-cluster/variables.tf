variable "cluster_identifier" {
  type        = string
  description = "Unique identifier for the Aurora DB cluster. Used as the cluster name and as a prefix for related resource names."
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to merge into every taggable resource created by this module."
  default     = {}
}

variable "engine" {
  type        = string
  description = "Aurora database engine. Must be one of: aurora-postgresql, aurora-mysql."
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "engine must be either 'aurora-postgresql' or 'aurora-mysql'."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version for the Aurora cluster (e.g. '15.4' for aurora-postgresql or '8.0.mysql_aurora.3.05.2' for aurora-mysql). No default — consumers must pin an explicit version."
}

variable "database_name" {
  type        = string
  description = "Name of the initial database to create inside the cluster."
}

variable "master_username" {
  type        = string
  description = "Username for the master database user."
  default     = "admin"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC in which to create the security group and subnet group. The module does not create the VPC."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the DB subnet group. Must span at least two Availability Zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least two subnet IDs (one per Availability Zone) for high availability."
  }
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs allowed to connect to the database port. Ingress is restricted to these security groups only — no CIDR-based ingress is added by default, following least-privilege principles."
  default     = []
}

variable "database_port" {
  type        = number
  description = "TCP port the database listens on. Defaults to null, which causes the module to derive the correct port from the engine (5432 for aurora-postgresql, 3306 for aurora-mysql)."
  default     = null
}

variable "min_acu" {
  type        = number
  description = "Minimum Aurora Capacity Units for Serverless v2 scaling. Must be between 0.5 and 128 in increments of 0.5. Default 0.5 ACU costs approximately $43/month at us-east-1 list pricing when idle."
  default     = 0.5

  validation {
    condition     = var.min_acu >= 0.5 && var.min_acu <= 128
    error_message = "min_acu must be between 0.5 and 128."
  }
}

variable "max_acu" {
  type        = number
  description = "Maximum Aurora Capacity Units for Serverless v2 scaling. Must be >= min_acu and <= 128."
  default     = 4

  validation {
    condition     = var.max_acu >= 0.5 && var.max_acu <= 128
    error_message = "max_acu must be between 0.5 and 128."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain automated cluster backups. Must be between 1 and 35."
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the Aurora cluster. Defaults to true to prevent accidental data loss. Set to false only for ephemeral environments."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of an existing KMS CMK to use for storage encryption. When null, the module creates a new customer-managed KMS key."
  default     = null
}

variable "manage_master_user_password" {
  type        = bool
  description = "When true, RDS manages the master password in AWS Secrets Manager and rotates it automatically. Recommended. Set to false only if you need to manage the password externally (requires adding a master_password variable in a wrapper module)."
  default     = true
}
