# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API for ${var.project_name} ${var.environment} environment"

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
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

# API Gateway Integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_otel.lambda1_invoke_arn
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

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_otel.lambda1_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
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

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  depends_on = [aws_api_gateway_integration.lambda_integration]
}
