output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket (e.g. for use as a CloudFront origin)."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
