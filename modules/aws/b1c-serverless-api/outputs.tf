output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "api_endpoint" {
  description = "Invoke URL of the API Gateway $default stage (e.g. https://<id>.execute-api.<region>.amazonaws.com)."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "ID of the API Gateway v2 HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "execution_role_arn" {
  description = "ARN of the Lambda execution IAM role. Pass this to wrapper modules that need to attach additional policies."
  value       = aws_iam_role.lambda_exec.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function."
  value       = aws_cloudwatch_log_group.lambda.name
}
