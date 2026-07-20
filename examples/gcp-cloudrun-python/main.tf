# ---------------------------------------------------------------------------
# examples/gcp-cloudrun-python/main.tf
#
# Instantiates the gcp/b1c-serverless-api module to deploy a minimal Python
# Cloud Run service. The initial container_image points at Google's public
# hello-world image; gcp-cloudrun-deploy.yml (via the caller workflow in
# .github/workflows/deploy.yml) redeploys from examples/gcp-cloudrun-python/
# source on every push, which is how Cloud Run's buildpacks build actually
# replaces this placeholder image with the real application.
#
# No backend{} block here — configure remote state in a terraform.tf file
# in your own repo pointing at your Terraform state bucket. See:
# docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

module "example_python_api" {
  source = "../../modules/gcp/b1c-serverless-api"

  project_id      = var.project_id
  service_name    = "example-python-api"
  region          = "us-central1"
  container_image = "us-docker.pkg.dev/cloudrun/container/hello"

  allow_unauthenticated = true

  labels = {
    project     = "example-cloudrun-python"
    managed_by  = "terraform"
    environment = "demo"
  }
}

output "service_url" {
  description = "HTTPS URL for the deployed Cloud Run service."
  value       = module.example_python_api.service_url
}

output "service_name" {
  description = "Name of the deployed Cloud Run service."
  value       = module.example_python_api.service_name
}
