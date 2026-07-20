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

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example service into."
}

# Minimal example: deploys Google's public Cloud Run quickstart image behind
# an authenticated (non-public) Cloud Run service.
module "my_api" {
  source = "../../"

  project_id      = var.project_id
  service_name    = "example-hello-api"
  region          = "us-central1"
  container_image = "us-docker.pkg.dev/cloudrun/container/hello"

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "service_url" {
  description = "HTTPS URL of the deployed Cloud Run service."
  value       = module.my_api.service_url
}
