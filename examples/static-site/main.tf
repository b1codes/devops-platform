# ---------------------------------------------------------------------------
# examples/static-site/main.tf
#
# Deploys a static website using:
#   - b1c-secure-bucket for origin storage (private, encrypted)
#   - aws_cloudfront_distribution with Origin Access Control (OAC)
#   - A bucket policy scoped to the CloudFront distribution ARN
#
# A random_id suffix avoids S3 global name collisions when multiple
# consumers try this example simultaneously.
#
# No backend{} block here -- configure remote state in your own repo.
# See docs/PREREQUISITES.md for setup instructions.
# ---------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Origin bucket via the b1c-secure-bucket module
# Public access is blocked by the module; CloudFront accesses via OAC.
# ---------------------------------------------------------------------------

module "site_bucket" {
  source = "../../modules/aws/b1c-secure-bucket"

  bucket_name        = "example-static-site-${random_id.suffix.hex}"
  versioning_enabled = true

  tags = {
    Project     = "example-static-site"
    ManagedBy   = "Terraform"
    Environment = "demo"
  }
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control
# OAC is the current AWS-recommended mechanism for CloudFront to access a
# private S3 origin. It supersedes the legacy Origin Access Identity (OAI).
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "example-static-site-oac"
  description                       = "OAC for the example static site S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "example-static-site distribution"

  origin {
    origin_id                = module.site_bucket.bucket_id
    domain_name              = module.site_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = module.site_bucket.bucket_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
    compress    = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = "example-static-site"
    ManagedBy   = "Terraform"
    Environment = "demo"
  }
}

# ---------------------------------------------------------------------------
# Bucket policy -- grant CloudFront service principal read access
# Scoped to this specific distribution via the AWS:SourceArn condition so that
# no other CloudFront distribution can access this origin bucket.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudfront_read" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${module.site_bucket.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront_read" {
  bucket = module.site_bucket.bucket_id
  policy = data.aws_iam_policy_document.cloudfront_read.json

  # The public-access block on the bucket must exist before the policy is
  # applied, which the module guarantees. The CloudFront distribution must
  # also exist before we can reference its ARN in the condition.
  depends_on = [aws_cloudfront_distribution.this]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "cloudfront_domain" {
  description = "Default CloudFront domain for the static site (e.g. d1234abcd.cloudfront.net)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Pass this to aws-static-site.yml as cloudfront_distribution_id."
  value       = aws_cloudfront_distribution.this.id
}

output "bucket_name" {
  description = "S3 bucket name. Pass this to aws-static-site.yml as bucket_name."
  value       = module.site_bucket.bucket_id
}
