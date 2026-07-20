terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy the example instance into."
}

# ---------------------------------------------------------------------------
# PREREQUISITES:
# Replace this data lookup with your own VPC network, or wire this example
# to a network module output. The module does NOT create the VPC.
# ---------------------------------------------------------------------------

data "google_compute_network" "existing" {
  project = var.project_id
  name    = "default"
}

resource "random_password" "master" {
  length  = 24
  special = false
}

module "my_instance" {
  source = "../../"

  project_id       = var.project_id
  instance_name    = "my-app-db-dev"
  region           = "us-central1"
  database_version = "POSTGRES_15"
  database_name    = "myapp"
  master_username  = "dbadmin"
  master_password  = random_password.master.result

  vpc_network = data.google_compute_network.existing.self_link

  # Development-friendly settings — tighten for production
  tier                  = "db-custom-1-3840"
  deletion_protection   = false
  backup_retention_days = 7

  labels = {
    environment = "dev"
    project     = "my-app"
    managed_by  = "terraform"
  }
}

output "connection_name" {
  description = "Connection name for the Cloud SQL Auth Proxy / connector libraries."
  value       = module.my_instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address for application connections."
  value       = module.my_instance.private_ip_address
}
