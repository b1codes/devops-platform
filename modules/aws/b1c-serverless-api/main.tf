# ---------------------------------------------------------------------------
# b1c-serverless-api — GENERIC, AUTH-FREE PRIMITIVE
#
# This module provisions a Lambda function wired to an HTTP API Gateway v2.
# It is intentionally auth-free: the $default route uses authorization_type
# = "NONE". This is by design — security is a concern for the consumer.
#
# TO ADD AUTH: Create a wrapper module that calls this one, then adds an
# aws_apigatewayv2_authorizer (JWT for Auth0/Cognito) and overrides the
# route's authorization_type and authorizer_id using a separate
# aws_apigatewayv2_route resource that replaces the default route. See the
# private llc-infra-core/modules/tier1-serverless module for an example of
# layering Auth0 JWT authorization on top of this primitive.
#
# No backend{} block — consumers configure remote state at the root level.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Archive — optional: zip a source directory at plan time
# Only used when var.source_dir is set.
# ---------------------------------------------------------------------------

data "archive_file" "source_dir" {
  count = var.source_dir != null ? 1 : 0

  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.archive/${var.function_name}.zip"
}

# ---------------------------------------------------------------------------
# IAM — Lambda execution role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.function_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.function_name}-exec-role"
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extra_policies" {
  for_each = toset(var.extra_policy_arns)

  role       = aws_iam_role.lambda_exec.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# CloudWatch — log group
# Pre-create the log group so that Lambda does not auto-create an unmanaged
# one, and so that retention is enforced from the first invocation.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "/aws/lambda/${var.function_name}"
  })
}

# ---------------------------------------------------------------------------
# Lambda function
# Exactly one of var.source_filename or var.source_dir must be provided.
# This is enforced via a precondition in the lifecycle block below.
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.runtime
  handler       = var.handler
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  # Source resolution: prefer source_filename (pre-built zip), fall back to
  # the archive_file data source result when source_dir is set.
  filename         = var.source_filename != null ? var.source_filename : data.archive_file.source_dir[0].output_path
  source_code_hash = var.source_filename != null ? filebase64sha256(var.source_filename) : data.archive_file.source_dir[0].output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [var.environment_variables] : []
    content {
      variables = environment.value
    }
  }

  lifecycle {
    precondition {
      condition     = (var.source_filename != null) != (var.source_dir != null)
      error_message = "Exactly one of source_filename or source_dir must be set. Provide a pre-built zip path (source_filename) or a directory to zip at plan time (source_dir), but not both."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic_execution,
  ]

  tags = merge(var.tags, {
    Name = var.function_name
  })
}

# ---------------------------------------------------------------------------
# API Gateway v2 — HTTP API
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.function_name}-api"
  protocol_type = "HTTP"

  tags = merge(var.tags, {
    Name = "${var.function_name}-api"
  })
}

resource "aws_apigatewayv2_integration" "lambda_proxy" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

# The $default route is auth-free. To add JWT authorization, create an
# aws_apigatewayv2_authorizer and an aws_apigatewayv2_route resource in your
# wrapper module with authorization_type = "JWT" and the authorizer_id set.
resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  tags = merge(var.tags, {
    Name = "${var.function_name}-default-stage"
  })
}

# ---------------------------------------------------------------------------
# Lambda permission — allow API Gateway to invoke
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
