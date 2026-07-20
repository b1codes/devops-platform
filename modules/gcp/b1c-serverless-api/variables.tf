variable "project_id" {
  type        = string
  description = "GCP project ID in which to create the Cloud Run service."
}

variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service. Also used as a prefix for the runtime service account."
}

variable "region" {
  type        = string
  description = "GCP region to deploy the Cloud Run service into (e.g. 'us-central1')."
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

variable "container_image" {
  type        = string
  description = "Full container image reference to deploy (e.g. 'us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG'). This module does not build or push images — the caller (or gcp-cloudrun-deploy.yml) is responsible for that."
}

variable "container_port" {
  type        = number
  description = "TCP port the container listens on."
  default     = 8080
}

variable "memory" {
  type        = string
  description = "Memory limit per container instance (Cloud Run resource quantity string, e.g. '512Mi', '1Gi')."
  default     = "512Mi"
}

variable "cpu" {
  type        = string
  description = "CPU limit per container instance (Cloud Run resource quantity string, e.g. '1', '2')."
  default     = "1"
}

variable "timeout_seconds" {
  type        = number
  description = "Maximum request duration in seconds before Cloud Run terminates the request. Must be between 1 and 3600."
  default     = 30

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 3600
    error_message = "timeout_seconds must be between 1 and 3600."
  }
}

variable "min_instance_count" {
  type        = number
  description = "Minimum number of container instances to keep warm. 0 allows scale-to-zero."
  default     = 0
}

variable "max_instance_count" {
  type        = number
  description = "Maximum number of container instances Cloud Run will scale out to."
  default     = 10
}

variable "allow_unauthenticated" {
  type        = bool
  description = "When true, grants roles/run.invoker to allUsers, making the service publicly reachable without authentication. Consumers needing auth should leave this false and layer their own IAM/JWT authorization in a wrapper module."
  default     = false
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to inject into the container at runtime."
  default     = {}
}

variable "extra_role_ids" {
  type        = list(string)
  description = "List of additional IAM role IDs to grant the Cloud Run runtime service account on the project (e.g. 'roles/datastore.user', 'roles/secretmanager.secretAccessor')."
  default     = []
}
