output "service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.this.name
}

output "service_url" {
  description = "HTTPS URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account_email" {
  description = "Email of the Cloud Run runtime service account. Pass this to wrapper modules that need to grant additional IAM roles."
  value       = google_service_account.runtime.email
}
