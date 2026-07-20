output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora cluster. Use this for all write operations."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster. Use this for read-only queries to distribute load."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_identifier" {
  description = "Identifier of the Aurora cluster."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.this.arn
}

output "cluster_resource_id" {
  description = "RDS resource ID of the cluster. Required for IAM database authentication policies (used in the IAM condition key rds-db:connect)."
  value       = aws_rds_cluster.this.cluster_resource_id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the managed master user password. Only populated when manage_master_user_password = true."
  value       = var.manage_master_user_password ? aws_rds_cluster.this.master_user_secret[0].secret_arn : null
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the security group attached to the Aurora cluster."
  value       = aws_security_group.this.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for Aurora storage encryption. This is either the key provided via var.kms_key_arn or the CMK created by this module."
  value       = local.kms_key_arn
}
