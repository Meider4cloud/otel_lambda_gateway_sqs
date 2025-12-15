output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_rest_api.api.execution_arn}/${var.api_stage_name}"
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/process"
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = aws_sqs_queue.message_queue.url
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = aws_sqs_queue.message_queue.arn
}

output "lambda1_function_name" {
  description = "Lambda 1 (API Handler) function name"
  value       = aws_lambda_function.lambda1.function_name
}

output "lambda2_function_name" {
  description = "Lambda 2 (Worker) function name"
  value       = aws_lambda_function.lambda2.function_name
}

output "lambda1_arn" {
  description = "Lambda 1 ARN"
  value       = aws_lambda_function.lambda1.arn
}

output "lambda2_arn" {
  description = "Lambda 2 ARN"
  value       = aws_lambda_function.lambda2.arn
}

# Observability Configuration Information
output "current_observability_config" {
  description = "Currently active observability configuration"
  value       = var.observability_config
}

output "observability_layers" {
  description = "Lambda layers being used for observability"
  value       = local.current_config.layers
}

output "configuration_summary" {
  description = "Summary of the POC configuration"
  value = {
    config_type = var.observability_config
    description = {
      xray_adot          = "X-Ray tracing with AWS Distro for OpenTelemetry (ADOT) layer"
      xray_community     = "X-Ray tracing with Community OpenTelemetry layer"
      newrelic_adot      = "New Relic monitoring with AWS Distro for OpenTelemetry (ADOT) layer"
      newrelic_community = "New Relic monitoring with Community OpenTelemetry layer"
    }[var.observability_config]
    backend    = startswith(var.observability_config, "newrelic") ? "New Relic" : "AWS X-Ray"
    layer_type = endswith(var.observability_config, "adot") ? "AWS ADOT" : "Community OpenTelemetry"
  }
}
