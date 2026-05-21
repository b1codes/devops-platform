terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# PREREQUISITES:
# Replace the placeholder VPC/subnet/SG values below with real IDs from your
# AWS account, or wire this example to a VPC module output.
#
# The module does NOT create a VPC, subnets, or a NAT gateway.
# ---------------------------------------------------------------------------

# Example: look up an existing VPC by tag (replace with your own approach)
data "aws_vpc" "selected" {
  tags = {
    Name = "my-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Tier = "private"
  }
}

# Example application security group that will be allowed to connect
data "aws_security_group" "app" {
  tags = {
    Name = "my-app-sg"
  }
}

module "my_cluster" {
  source = "../../"

  cluster_identifier = "my-app-db-dev"
  engine             = "aurora-postgresql"
  engine_version     = "15.4"
  database_name      = "myapp"
  master_username    = "dbadmin"

  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.private.ids

  allowed_security_group_ids = [data.aws_security_group.app.id]

  # Development-friendly settings — tighten for production
  min_acu               = 0.5
  max_acu               = 4
  deletion_protection   = false
  backup_retention_days = 7

  tags = {
    Environment = "dev"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}

output "cluster_endpoint" {
  description = "Writer endpoint for application connections."
  value       = module.my_cluster.cluster_endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for read-only queries."
  value       = module.my_cluster.reader_endpoint
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret for the master password."
  value       = module.my_cluster.master_user_secret_arn
  sensitive   = true
}
