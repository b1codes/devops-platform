variable "function_name" {
  type        = string
  description = "Name of the Lambda function. Also used as a prefix for the API Gateway and CloudWatch log group."
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to merge into every taggable resource created by this module."
  default     = {}
}

variable "runtime" {
  type        = string
  description = "Lambda runtime identifier (e.g. python3.12, nodejs20.x)."
  default     = "python3.12"
}

variable "handler" {
  type        = string
  description = "Lambda handler in 'file.function' notation (e.g. index.handler)."
  default     = "index.handler"
}

variable "memory_mb" {
  type        = number
  description = "Amount of memory (in MB) allocated to the Lambda function."
  default     = 256
}

variable "timeout_seconds" {
  type        = number
  description = "Maximum execution time (in seconds) for the Lambda function. Must be between 1 and 900."
  default     = 30
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain CloudWatch log events. Must be one of the values accepted by the CloudWatch Logs API."
  default     = 14

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be one of the values supported by CloudWatch Logs: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "source_filename" {
  type        = string
  description = "Absolute path to a pre-built .zip file to upload as the Lambda deployment package. Exactly one of source_filename or source_dir must be set."
  default     = null
}

variable "source_dir" {
  type        = string
  description = "Absolute path to a directory whose contents will be zipped at plan time using the archive provider. Exactly one of source_filename or source_dir must be set."
  default     = null
}

variable "extra_policy_arns" {
  type        = list(string)
  description = "List of additional IAM managed policy ARNs to attach to the Lambda execution role (e.g. for DynamoDB, S3, or Secrets Manager access)."
  default     = []
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to inject into the Lambda function at runtime."
  default     = {}
}
