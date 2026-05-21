# tflint configuration for devops-platform
#
# Install tflint: https://github.com/terraform-linters/tflint#installation
# Run: tflint --recursive
#
# The AWS plugin adds AWS-specific rules (deprecated resource types, invalid
# instance types, etc.). It is fetched automatically on first run.

plugin "aws" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  version = "0.32.0"
}

# ---------------------------------------------------------------------------
# Core Terraform rules
# ---------------------------------------------------------------------------

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
