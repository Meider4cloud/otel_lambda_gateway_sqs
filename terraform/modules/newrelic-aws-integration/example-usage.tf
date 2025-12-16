# Example usage of the New Relic AWS Integration module
# Add this to your main terraform configuration to enable New Relic monitoring

# First, ensure you have the New Relic provider configured
terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.0"
    }
  }
}

# Configure the New Relic provider
provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key # Personal API key
  region     = "US"                 # or "EU" for European accounts
}

# New Relic AWS Integration Module
module "newrelic_aws_integration" {
  source = "./modules/newrelic-aws-integration"

  # Required variables
  newrelic_account_id  = var.newrelic_account_id
  newrelic_license_key = var.newrelic_license_key

  # Integration configuration
  integration_name = "${var.project_name}-${var.environment}"
  aws_regions      = ["eu-central-1"] # Match your deployment region

  # Enable metric stream (recommended)
  enable_metric_stream        = true
  metric_stream_output_format = "opentelemetry1.0"

  # Include metrics for your specific services
  metric_stream_include_filters = {
    "AWS/Lambda"     = [] # All Lambda metrics
    "AWS/ApiGateway" = [] # All API Gateway metrics  
    "AWS/SQS"        = [] # All SQS metrics
    "AWS/X-Ray"      = [] # All X-Ray metrics
  }

  # Enable specific service integrations
  enable_lambda_integration      = true
  enable_api_gateway_integration = true
  enable_sqs_integration         = true
  enable_cloudwatch_integration  = true
  enable_xray_integration        = true

  # Polling intervals (in seconds)
  lambda_polling_interval      = 300 # 5 minutes
  api_gateway_polling_interval = 300 # 5 minutes
  sqs_polling_interval         = 300 # 5 minutes
  xray_polling_interval        = 300 # 5 minutes

  # Service-specific configurations
  sqs_fetch_extended_inventory = true
  sqs_fetch_tags               = true

  # Filter by your API Gateway stages if needed
  # api_gateway_stage_prefixes = ["dev", "prod"]

  # Filter by SQS queue prefixes if needed
  # sqs_queue_prefixes = ["otel-alml-poc"]

  # Storage and retention settings
  s3_backup_retention_days      = 30   # Keep failed metrics for 30 days
  cloudwatch_log_retention_days = 14   # Keep logs for 2 weeks
  force_destroy_s3_bucket       = true # Set to true for dev/test environments

  # Tags for all created resources
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    Purpose     = "NewRelic AWS Integration"
    ManagedBy   = "terraform"
  }
}

# Output important information
output "newrelic_integration_summary" {
  description = "Summary of New Relic AWS integration"
  value       = module.newrelic_aws_integration.integration_summary
}

output "newrelic_integration_role_arn" {
  description = "IAM role ARN for New Relic integration"
  value       = module.newrelic_aws_integration.integration_role_arn
}

output "newrelic_metric_stream_arn" {
  description = "CloudWatch Metric Stream ARN"
  value       = module.newrelic_aws_integration.metric_stream_arn
}

# Variables that need to be defined (add to your variables.tf)
variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
}

variable "newrelic_api_key" {
  description = "New Relic Personal API Key"
  type        = string
  sensitive   = true
}

variable "newrelic_license_key" {
  description = "New Relic License Key (ingest key)"
  type        = string
  sensitive   = true
}
