output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Connection name of the instance, in the format project:region:instance. Required for the Cloud SQL Auth Proxy / connector libraries."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Name of the created database."
  value       = google_sql_database.this.name
}
