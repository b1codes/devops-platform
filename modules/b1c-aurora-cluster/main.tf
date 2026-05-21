# ---------------------------------------------------------------------------
# b1c-aurora-cluster
#
# Aurora Serverless v2 cluster with:
#   - DB subnet group and least-privilege security group (SG-based ingress only)
#   - KMS encryption (module creates a CMK unless one is provided)
#   - RDS-managed master password in AWS Secrets Manager
#   - IAM database authentication enabled
#   - Deletion protection on by default
#   - Configurable Serverless v2 ACU scaling range
#
# This module does NOT create the VPC, subnets, or any application-layer
# resources. Pass var.vpc_id, var.subnet_ids, and var.allowed_security_group_ids
# from your root module.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

locals {
  # Derive the default database port from the engine when the caller does not
  # supply one. aurora-postgresql uses 5432; aurora-mysql uses 3306.
  effective_port = var.database_port != null ? var.database_port : (
    var.engine == "aurora-postgresql" ? 5432 : 3306
  )

  # CloudWatch log exports differ by engine.
  log_exports = var.engine == "aurora-postgresql" ? ["postgresql"] : ["audit", "general", "slowquery"]

  # Use the provided KMS key ARN, or the one created by this module.
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
}

# ---------------------------------------------------------------------------
# KMS — create a CMK when the caller does not supply one
# ---------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "CMK for Aurora cluster ${var.cluster_identifier}"
  deletion_window_in_days = 14
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-kms"
  })
}

resource "aws_kms_alias" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${var.cluster_identifier}"
  target_key_id = aws_kms_key.this[0].key_id
}

# ---------------------------------------------------------------------------
# DB subnet group
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name        = "${var.cluster_identifier}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for Aurora cluster ${var.cluster_identifier}"

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Security group
# Ingress is restricted to specific security groups — no CIDR ingress by default.
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.cluster_identifier}-sg"
  description = "Security group for Aurora cluster ${var.cluster_identifier}. Ingress allowed from approved security groups on port ${local.effective_port} only."
  vpc_id      = var.vpc_id

  # Egress: allow all (standard for stateful RDS resources).
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-sg"
  })
}

resource "aws_security_group_rule" "ingress_from_sg" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = local.effective_port
  to_port                  = local.effective_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "Allow database access from security group ${each.value}"
}

# ---------------------------------------------------------------------------
# Aurora cluster
# ---------------------------------------------------------------------------

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier
  engine             = var.engine
  engine_mode        = "provisioned"
  engine_version     = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username
  port            = local.effective_port

  # RDS manages the master password in Secrets Manager and rotates it
  # automatically. This is the recommended approach — avoids storing plaintext
  # passwords in Terraform state.
  manage_master_user_password = var.manage_master_user_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_acu
    max_capacity = var.max_acu
  }

  storage_encrypted = true
  kms_key_id        = local.kms_key_arn

  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.deletion_protection

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = local.log_exports

  # Never apply changes immediately in production. Consumers can override by
  # setting apply_immediately = true in a wrapper module for dev environments.
  apply_immediately = false

  tags = merge(var.tags, {
    Name = var.cluster_identifier
  })
}

# ---------------------------------------------------------------------------
# Aurora cluster instance — single writer (Serverless v2)
# ---------------------------------------------------------------------------

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.cluster_identifier}-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  # Pre-create the parameter group association with the cluster before
  # applying cluster-level changes.
  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-writer"
  })
}
