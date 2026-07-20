# ---------------------------------------------------------------------------
# examples/gcp-static-site/main.tf
#
# Deploys a static website using:
#   - gcp/b1c-secure-bucket for origin storage
#   - google_compute_backend_bucket + Cloud CDN as the caching layer
#   - An external HTTPS Load Balancer (URL map, target proxy, forwarding
#     rule, managed SSL certificate) fronting the backend bucket
#
# This is the GCP architectural equivalent of examples/static-site's
# S3 + CloudFront + OAC composition — GCS buckets can't serve HTTPS on a
# custom domain on their own, so the LB + CDN stack is required, not
# optional, for parity with the AWS example.
#
# No backend{} block here -- configure remote state in your own repo.
# See docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

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
  description = "GCP project ID to deploy the example static site into."
}

variable "domain_name" {
  type        = string
  description = "Domain name to bind the managed SSL certificate to (e.g. 'site.example.com'). You must control DNS for this domain and point it at the load balancer's IP after apply."
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Origin bucket via the gcp/b1c-secure-bucket module
# The backend bucket resource below reads directly from GCS; no public
# bucket ACLs are needed because Cloud CDN/backend-bucket access GCS via
# the Cloud Storage API using the project's own service identity.
# ---------------------------------------------------------------------------

module "site_bucket" {
  source = "../../modules/gcp/b1c-secure-bucket"

  project_id  = var.project_id
  bucket_name = "example-static-site-${random_id.suffix.hex}"

  labels = {
    project     = "example-static-site"
    managed_by  = "terraform"
    environment = "demo"
  }
}

# ---------------------------------------------------------------------------
# Cloud CDN-enabled backend bucket
# ---------------------------------------------------------------------------

resource "google_compute_backend_bucket" "this" {
  project     = var.project_id
  name        = "example-static-site-backend"
  bucket_name = module.site_bucket.bucket_name
  enable_cdn  = true
}

# ---------------------------------------------------------------------------
# External HTTPS Load Balancer — URL map, managed cert, target proxy,
# global forwarding rule
# ---------------------------------------------------------------------------

resource "google_compute_url_map" "this" {
  project         = var.project_id
  name            = "example-static-site-url-map"
  default_service = google_compute_backend_bucket.this.id
}

resource "google_compute_managed_ssl_certificate" "this" {
  project = var.project_id
  name    = "example-static-site-cert"

  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "this" {
  project          = var.project_id
  name             = "example-static-site-https-proxy"
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
}

resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "example-static-site-ip"
}

resource "google_compute_global_forwarding_rule" "this" {
  project    = var.project_id
  name       = "example-static-site-forwarding-rule"
  target     = google_compute_target_https_proxy.this.id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "load_balancer_ip" {
  description = "Global IP address of the load balancer. Point your domain's DNS A record here."
  value       = google_compute_global_address.lb_ip.address
}

output "bucket_name" {
  description = "GCS bucket name. Pass this to gcp-static-site.yml as bucket_name."
  value       = module.site_bucket.bucket_name
}

output "backend_bucket_name" {
  description = "Name of the Cloud CDN-enabled backend bucket. Pass this to gcp-static-site.yml as backend_bucket_name for cache invalidation."
  value       = google_compute_backend_bucket.this.name
}
