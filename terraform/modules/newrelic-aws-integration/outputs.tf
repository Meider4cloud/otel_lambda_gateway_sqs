# New Relic AWS Integration Module Outputs

output "integration_name" {
  description = "Name of the New Relic AWS integration"
  value       = var.integration_name
}

output "linked_account_id" {
  description = "New Relic linked account ID"
  value       = newrelic_cloud_aws_link_account.aws_link.id
}

output "integration_role_arn" {
  description = "ARN of the IAM role created for New Relic integration"
  value       = aws_iam_role.newrelic_integration_role.arn
}

output "integration_role_name" {
  description = "Name of the IAM role created for New Relic integration"
  value       = aws_iam_role.newrelic_integration_role.name
}

output "aws_account_id" {
  description = "AWS Account ID where integration is configured"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Primary AWS region for the integration"
  value       = data.aws_region.current.name
}

output "monitored_regions" {
  description = "List of AWS regions being monitored"
  value       = var.aws_regions
}

# Metric Stream outputs
output "metric_stream_enabled" {
  description = "Whether CloudWatch Metric Stream is enabled"
  value       = var.enable_metric_stream
}

output "metric_stream_arn" {
  description = "ARN of the CloudWatch Metric Stream (if enabled)"
  value       = var.enable_metric_stream ? aws_cloudwatch_metric_stream.newrelic_metric_stream[0].arn : null
}

output "metric_stream_name" {
  description = "Name of the CloudWatch Metric Stream (if enabled)"
  value       = var.enable_metric_stream ? aws_cloudwatch_metric_stream.newrelic_metric_stream[0].name : null
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream (if metric stream enabled)"
  value       = var.enable_metric_stream ? aws_kinesis_firehose_delivery_stream.newrelic_stream[0].arn : null
}

output "firehose_backup_bucket" {
  description = "S3 bucket name for failed metric data backup (if metric stream enabled)"
  value       = var.enable_metric_stream ? aws_s3_bucket.firehose_backup[0].id : null
}

# Service integration status
output "enabled_integrations" {
  description = "List of enabled AWS service integrations"
  value = compact([
    var.enable_lambda_integration ? "lambda" : "",
    var.enable_api_gateway_integration ? "api_gateway" : "",
    var.enable_sqs_integration ? "sqs" : "",
    var.enable_cloudwatch_integration ? "cloudwatch" : "",
    var.enable_xray_integration ? "x_ray" : ""
  ])
}

output "integration_summary" {
  description = "Summary of the New Relic AWS integration configuration"
  value = {
    name            = var.integration_name
    account_id      = var.newrelic_account_id
    aws_account_id  = data.aws_caller_identity.current.account_id
    regions         = var.aws_regions
    metric_stream   = var.enable_metric_stream
    collection_mode = var.metric_collection_mode
    enabled_services = length(compact([
      var.enable_lambda_integration ? "lambda" : "",
      var.enable_api_gateway_integration ? "api_gateway" : "",
      var.enable_sqs_integration ? "sqs" : "",
      var.enable_cloudwatch_integration ? "cloudwatch" : "",
      var.enable_xray_integration ? "x_ray" : ""
    ]))
    created_at = timestamp()
  }
}
