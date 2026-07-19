# ---------------------------------------------------------------------------
# b1c-relational-db (GCP)
#
# Cloud SQL instance with private-IP connectivity, CMEK-optional disk
# encryption, automated backups, and a deletion-protection toggle.
#
# PARITY GAP: Cloud SQL has no serverless *compute* autoscaling equivalent
# to Aurora Serverless v2 (modules/aws/b1c-aurora-cluster). var.tier picks a
# fixed machine size. Storage autoscaling (disk_autoresize) IS a genuine
# parity point and is on by default.
#
# Does NOT create the VPC — var.vpc_network must reference an existing
# network self-link. The module provisions the private-services-access
# peering range required for Cloud SQL private IP.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Private services access — required for Cloud SQL private IP
# ---------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "${var.instance_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_ip_range_prefix_length
  network       = var.vpc_network
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ---------------------------------------------------------------------------
# Cloud SQL instance
# ---------------------------------------------------------------------------

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.instance_name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection
  encryption_key_name = var.kms_key_name

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.tier

    disk_size       = var.disk_size_gb
    disk_autoresize = var.disk_autoresize
    disk_type       = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    user_labels = var.labels
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "master" {
  project  = var.project_id
  name     = var.master_username
  instance = google_sql_database_instance.this.name
  password = var.master_password
}
