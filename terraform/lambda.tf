# Lambda 1 - API Handler
resource "aws_lambda_function" "lambda1" {
  filename         = data.archive_file.lambda1_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-api-handler"
  role             = aws_iam_role.lambda1_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = var.lambda_timeout
  source_code_hash = data.archive_file.lambda1_zip.output_base64sha256

  # Only add layers if they exist (for ADOT configs)
  layers = length(local.current_config.layers) > 0 ? local.current_config.layers : null

  # Disable X-Ray tracing to avoid conflicts with OpenTelemetry
  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = local.lambda1_env_vars
  }

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Lambda 2 - Worker
resource "aws_lambda_function" "lambda2" {
  filename         = data.archive_file.lambda2_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-worker"
  role             = aws_iam_role.lambda2_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = var.lambda_timeout
  source_code_hash = data.archive_file.lambda2_zip.output_base64sha256

  # Only add layers if they exist (for ADOT configs)
  layers = length(local.current_config.layers) > 0 ? local.current_config.layers : null

  # Disable X-Ray tracing to avoid conflicts with OpenTelemetry
  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = local.lambda2_env_vars
  }

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda1_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda1.function_name}"
  retention_in_days = 7

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_cloudwatch_log_group" "lambda2_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda2.function_name}"
  retention_in_days = 7

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Event Source Mapping - SQS to Lambda 2
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.message_queue.arn
  function_name    = aws_lambda_function.lambda2.arn
  batch_size       = 10

  depends_on = [aws_iam_role_policy.lambda2_policy]
}
