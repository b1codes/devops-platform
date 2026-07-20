# b1c-aurora-cluster

An Aurora Serverless v2 cluster module that provisions a production-ready relational database without managing the VPC. Includes KMS encryption, RDS-managed password rotation, IAM database authentication, and a least-privilege security group.

## Features

- **Aurora Serverless v2** — `engine_mode = "provisioned"` with `serverlessv2_scaling_configuration` block; scales between `min_acu` and `max_acu` automatically.
- **Supports PostgreSQL and MySQL** — `engine` accepts `"aurora-postgresql"` (default) or `"aurora-mysql"`; port and CloudWatch log exports are derived automatically.
- **KMS encryption** — module creates a CMK with rotation enabled when `kms_key_arn` is not provided; or reuses an existing key.
- **RDS-managed master password** — AWS Secrets Manager stores and rotates the master password automatically when `manage_master_user_password = true` (default). No plaintext password in Terraform state.
- **IAM database authentication** — `iam_database_authentication_enabled = true` by default, enabling token-based auth for applications using IAM roles.
- **Least-privilege security group** — ingress is granted only to specific security group IDs passed via `allowed_security_group_ids`. No CIDR-based ingress is added.
- **Deletion protection** — enabled by default (`deletion_protection = true`). Set to `false` only for ephemeral environments.
- **Bring your own VPC** — the module does NOT create a VPC, subnets, or routing. Pass `vpc_id` and `subnet_ids` from your root module.

## Cost Notes

Aurora Serverless v2 pricing is based on ACU-hours. The defaults in this module are:

| Setting | Default | Notes |
|---------|---------|-------|
| `min_acu` | `0.5` | Minimum capacity — cluster idles here when not in use |
| `max_acu` | `4` | Maximum capacity — cluster scales up to this under load |

**At us-east-1 list pricing (aurora-postgresql, as of 2024): 0.5 ACU costs approximately $43/month when continuously running at minimum capacity.** This is the cost floor — even an idle cluster incurs this charge. Set `min_acu = 0` only if your Aurora version supports it (check AWS docs; not all versions allow 0 minimum).

For development environments, consider setting `deletion_protection = false` and `backup_retention_days = 1` to minimize costs.

## Usage

```hcl
module "app_db" {
  source = "github.com/B1Codes/devops-platform//modules/aws/b1c-aurora-cluster?ref=v0.1.0"

  cluster_identifier = "my-app-db-prod"
  engine             = "aurora-postgresql"
  engine_version     = "15.4"
  database_name      = "myapp"
  master_username    = "dbadmin"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.app.security_group_id]

  min_acu               = 0.5
  max_acu               = 16
  backup_retention_days = 14
  deletion_protection   = true

  tags = {
    Environment = "prod"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "cluster_endpoint" {
  value = module.app_db.cluster_endpoint
}

output "master_user_secret_arn" {
  value     = module.app_db.master_user_secret_arn
  sensitive = true
}
```

See [`examples/basic/main.tf`](./examples/basic/main.tf) for a runnable minimal example.

## IAM Database Authentication

The `cluster_resource_id` output is the value required in IAM policies for token-based authentication:

```json
{
  "Effect": "Allow",
  "Action": "rds-db:connect",
  "Resource": "arn:aws:rds-db:us-east-1:123456789012:dbuser/<cluster_resource_id>/myapp_user"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-generates the inputs/outputs tables between these markers. -->
<!-- Run: terraform-docs markdown table --output-file README.md . -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_identifier | Unique identifier for the Aurora DB cluster. | `string` | — | yes |
| engine_version | Engine version (e.g. 15.4 for PostgreSQL). No default — pin explicitly. | `string` | — | yes |
| database_name | Name of the initial database to create. | `string` | — | yes |
| vpc_id | VPC ID for the security group. Module does not create the VPC. | `string` | — | yes |
| subnet_ids | Subnet IDs for the DB subnet group (minimum 2, spanning 2 AZs). | `list(string)` | — | yes |
| tags | Map of tags to merge into every taggable resource. | `map(string)` | `{}` | no |
| engine | Aurora engine: aurora-postgresql or aurora-mysql. | `string` | `"aurora-postgresql"` | no |
| master_username | Master database username. | `string` | `"admin"` | no |
| allowed_security_group_ids | Security group IDs allowed to connect on the database port. | `list(string)` | `[]` | no |
| database_port | Override the database port (derived from engine if null). | `number` | `null` | no |
| min_acu | Minimum Aurora Capacity Units (0.5–128). Default 0.5 ≈ $43/mo idle. | `number` | `0.5` | no |
| max_acu | Maximum Aurora Capacity Units (0.5–128, must be >= min_acu). | `number` | `4` | no |
| backup_retention_days | Days to retain automated backups (1–35). | `number` | `7` | no |
| deletion_protection | Enable deletion protection. Recommended true in production. | `bool` | `true` | no |
| kms_key_arn | Existing KMS key ARN. Module creates a CMK if null. | `string` | `null` | no |
| manage_master_user_password | Let RDS manage the master password in Secrets Manager. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_endpoint | Writer endpoint for the Aurora cluster. |
| reader_endpoint | Reader endpoint for read-only queries. |
| cluster_identifier | Identifier of the Aurora cluster. |
| cluster_arn | ARN of the Aurora cluster. |
| cluster_resource_id | RDS resource ID for IAM database authentication policies. |
| master_user_secret_arn | ARN of the Secrets Manager secret (sensitive). Null if manage_master_user_password = false. |
| security_group_id | ID of the security group attached to the cluster. |
| kms_key_arn | ARN of the KMS key used for storage encryption. |

<!-- END_TF_DOCS -->

## License

MIT
