# OpenTelemetry Lambda Functions Module
# This module creates Lambda functions with OpenTelemetry instrumentation

# Data sources
data "aws_region" "current" {}

# Archive lambda functions
data "archive_file" "lambda1_zip" {
  type        = "zip"
  source_dir  = var.lambda1_source_dir
  output_path = "${var.build_dir}/lambda1.zip"
}

data "archive_file" "lambda2_zip" {
  type        = "zip"
  source_dir  = var.lambda2_source_dir
  output_path = "${var.build_dir}/lambda2.zip"
}

# Lambda 1 - API Handler
resource "aws_lambda_function" "lambda1" {
  filename         = data.archive_file.lambda1_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-api-handler"
  role             = aws_iam_role.lambda1_role.arn
  handler          = var.lambda1_handler
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  source_code_hash = data.archive_file.lambda1_zip.output_base64sha256

  # Only add layers if they exist (for ADOT configs)
  layers = length(var.lambda_layers) > 0 ? var.lambda_layers : null

  # Disable X-Ray tracing to avoid conflicts with OpenTelemetry
  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = var.lambda1_environment_variables
  }

  tags = var.tags
}

# Lambda 2 - Worker
resource "aws_lambda_function" "lambda2" {
  filename         = data.archive_file.lambda2_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-worker"
  role             = aws_iam_role.lambda2_role.arn
  handler          = var.lambda2_handler
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  source_code_hash = data.archive_file.lambda2_zip.output_base64sha256

  # Only add layers if they exist (for ADOT configs)
  layers = length(var.lambda_layers) > 0 ? var.lambda_layers : null

  # Disable X-Ray tracing to avoid conflicts with OpenTelemetry
  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = var.lambda2_environment_variables
  }

  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda1_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda1.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda2_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda2.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# SQS Queue for message processing
resource "aws_sqs_queue" "message_queue" {
  name                       = "${var.project_name}-${var.environment}-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout

  tags = var.tags
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-${var.environment}-dlq"

  tags = var.tags
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API for ${var.project_name} ${var.environment} environment"

  tags = var.tags
}

# API Gateway Resource
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "process"
}

# API Gateway Method
resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda1.invoke_arn
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method.api_method,
    aws_api_gateway_integration.lambda_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api_resource.id,
      aws_api_gateway_method.api_method.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.api_stage_name

  xray_tracing_enabled = true

  tags = var.tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda1.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"

  depends_on = [aws_lambda_function.lambda1]
}

# Event Source Mapping - SQS to Lambda 2
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.message_queue.arn
  function_name    = aws_lambda_function.lambda2.arn
  batch_size       = var.sqs_batch_size

  depends_on = [aws_iam_role_policy.lambda2_policy]
}

# IAM Role for Lambda 1 (API Handler)
resource "aws_iam_role" "lambda1_role" {
  name = "${var.project_name}-${var.environment}-lambda1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda 1
resource "aws_iam_role_policy" "lambda1_policy" {
  name = "${var.project_name}-${var.environment}-lambda1-policy"
  role = aws_iam_role.lambda1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.message_queue.arn
      },
      {
        Effect = "Allow"
        Action = concat(var.additional_iam_permissions, [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ])
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Lambda 2 (Worker)
resource "aws_iam_role" "lambda2_role" {
  name = "${var.project_name}-${var.environment}-lambda2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda 2
resource "aws_iam_role_policy" "lambda2_policy" {
  name = "${var.project_name}-${var.environment}-lambda2-policy"
  role = aws_iam_role.lambda2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = concat(var.additional_iam_permissions, [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ])
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.message_queue.arn
      }
    ]
  })
}
