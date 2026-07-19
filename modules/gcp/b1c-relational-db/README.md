# b1c-relational-db (GCP)

A Cloud SQL instance with private-IP connectivity, optional CMEK disk encryption, automated backups, and a deletion-protection toggle. Named for the underlying product (Cloud SQL) rather than reusing "aurora" — Aurora is an AWS brand name, and there is no serverless-compute parity to justify implying one. Mirrors [`modules/aws/b1c-aurora-cluster`](../../aws/b1c-aurora-cluster/) for the GCP provider where the abstraction transfers, and documents where it doesn't.

## Features

- **Private IP only** — `ipv4_enabled = false`; the module provisions the private-services-access VPC peering range Cloud SQL private IP requires. Does not create the VPC itself.
- **Storage autoscaling** — `disk_autoresize` (default `true`) is the closest Cloud SQL equivalent to Aurora's automatic storage scaling.
- **Documented parity gap** — Cloud SQL has no serverless *compute* autoscaling equivalent to Aurora Serverless v2. `tier` picks a fixed machine size.
- **Encryption** — Google-managed by default; switch to CMEK by passing `kms_key_name`.
- **Automated backups** — point-in-time recovery enabled; `backup_retention_days` controls how many automated backups are retained (1-365).
- **Deletion protection on by default** — stricter default than the AWS module, matching Cloud SQL's own default posture.

## Usage

```hcl
module "app_db" {
  source = "github.com/B1Codes/devops-platform//modules/gcp/b1c-relational-db?ref=v0.1.0"

  project_id       = "my-gcp-project"
  instance_name    = "my-app-db-prod"
  region           = "us-central1"
  database_version = "POSTGRES_15"
  database_name    = "myapp"
  master_username  = "dbadmin"
  master_password  = var.db_master_password # generate with the random provider; don't hardcode

  vpc_network = google_compute_network.main.self_link

  labels = { environment = "prod", project = "my-app", managed_by = "terraform" }
}

output "connection_name" {
  value = module.app_db.connection_name
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| google | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID in which to create the instance. | `string` | n/a | yes |
| instance_name | Name of the Cloud SQL instance. | `string` | n/a | yes |
| region | GCP region for the instance. | `string` | n/a | yes |
| labels | Map of labels to merge into every labelable resource. | `map(string)` | `{}` | no |
| database_version | Cloud SQL database_version string (e.g. POSTGRES_15). | `string` | n/a | yes |
| database_name | Name of the initial database. | `string` | n/a | yes |
| master_username | Username for the master database user. | `string` | `"admin"` | no |
| master_password | Password for the master database user. | `string` | n/a | yes |
| tier | Cloud SQL machine tier. | `string` | `"db-custom-1-3840"` | no |
| disk_size_gb | Initial disk size in GB. | `number` | `20` | no |
| disk_autoresize | Enable automatic storage capacity increases. | `bool` | `true` | no |
| vpc_network | Self-link of the VPC network to peer for private IP. | `string` | n/a | yes |
| private_ip_range_prefix_length | Prefix length of the peering IP range. | `number` | `16` | no |
| backup_retention_days | Number of automated backups to retain. | `number` | `7` | no |
| deletion_protection | Enable deletion protection. | `bool` | `true` | no |
| kms_key_name | Cloud KMS CryptoKey resource ID for CMEK disk encryption. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the Cloud SQL instance. |
| connection_name | Connection name (project:region:instance). |
| private_ip_address | Private IP address of the instance. |
| database_name | Name of the created database. |

<!-- END_TF_DOCS -->

## License

MIT
