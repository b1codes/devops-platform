# ---------------------------------------------------------------------------
# b1c-serverless-api (GCP) — GENERIC, AUTH-FREE PRIMITIVE
#
# This module provisions a Cloud Run v2 service. It is auth-free by default:
# var.allow_unauthenticated = false (the default) creates the service
# without a public IAM invoker binding, so only principals explicitly
# granted roles/run.invoker can call it. Security is a concern for the
# consumer, mirroring modules/aws/b1c-serverless-api.
#
# Unlike Lambda, Cloud Run deploys a container image, not a zip. This
# module does not build or push images — see gcp-cloudrun-deploy.yml for
# the accompanying source-to-Cloud-Run deploy workflow.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# IAM — Cloud Run runtime service account
# ---------------------------------------------------------------------------

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.service_name}-run-sa"
  display_name = "Runtime service account for Cloud Run service ${var.service_name}"
}

resource "google_project_iam_member" "extra_roles" {
  for_each = toset(var.extra_role_ids)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# ---------------------------------------------------------------------------
# Cloud Run v2 service
# ---------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.runtime.email
    timeout         = "${var.timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          memory = var.memory
          cpu    = var.cpu
        }
      }

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  labels = var.labels
}

# ---------------------------------------------------------------------------
# Optional IAM binding — public invoker access
# Only created when var.allow_unauthenticated = true.
# ---------------------------------------------------------------------------

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
