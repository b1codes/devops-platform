terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# ---------------------------------------------------------------------------
# PREREQUISITES:
# Replace var.project_id's value (via -var or a .tfvars file) with a real
# GCP project ID from your account. This module does not create the project.
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example bucket into."
}

# Minimal example: creates a private, encrypted, versioned GCS bucket.
# No backend{} block here — configure remote state in your root module.
module "my_bucket" {
  source = "../../"

  project_id  = var.project_id
  bucket_name = "my-org-my-app-artifacts-dev"

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "bucket_name" {
  description = "Name of the created bucket."
  value       = module.my_bucket.bucket_name
}

output "bucket_url" {
  description = "gs:// URL of the created bucket."
  value       = module.my_bucket.bucket_url
}
