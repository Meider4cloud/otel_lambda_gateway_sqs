output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL"
  value       = "${module.lambda_otel.api_gateway_invoke_url}/process"
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  value       = module.lambda_otel.api_gateway_execution_arn
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = module.lambda_otel.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = module.lambda_otel.sqs_queue_arn
}

output "lambda1_function_name" {
  description = "Lambda 1 (API Handler) function name"
  value       = module.lambda_otel.lambda1_function_name
}

output "lambda2_function_name" {
  description = "Lambda 2 (Worker) function name"
  value       = module.lambda_otel.lambda2_function_name
}

output "lambda1_arn" {
  description = "Lambda 1 ARN"
  value       = module.lambda_otel.lambda1_function_arn
}

output "lambda2_arn" {
  description = "Lambda 2 ARN"
  value       = module.lambda_otel.lambda2_function_arn
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
      newrelic_native    = "New Relic monitoring with native Lambda layer (APM mode)"
    }[var.observability_config]
    backend    = startswith(var.observability_config, "newrelic") ? "New Relic" : "AWS X-Ray"
    layer_type = endswith(var.observability_config, "adot") ? "AWS ADOT" : var.observability_config == "newrelic_native" ? "New Relic Native" : "Community OpenTelemetry"
  }
}
