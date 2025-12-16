# New Relic AWS Integration Module Variables

variable "newrelic_account_id" {
  description = "The New Relic account ID"
  type        = string
}

variable "newrelic_license_key" {
  description = "New Relic license key for metric stream"
  type        = string
  sensitive   = true
}

variable "integration_name" {
  description = "Name for the integration (used in resource naming)"
  type        = string
  default     = "aws-newrelic"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]*$", var.integration_name))
    error_message = "Integration name must start with a letter and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "aws_regions" {
  description = "List of AWS regions to monitor"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Metric Collection Configuration
variable "metric_collection_mode" {
  description = "Metric collection mode: PUSH or PULL"
  type        = string
  default     = "PULL"

  validation {
    condition     = contains(["PUSH", "PULL"], var.metric_collection_mode)
    error_message = "Metric collection mode must be either PUSH or PULL."
  }
}

variable "enable_metric_stream" {
  description = "Enable CloudWatch Metric Stream (recommended for most use cases)"
  type        = bool
  default     = true
}

variable "metric_stream_output_format" {
  description = "Output format for metric stream: opentelemetry0.7 or opentelemetry1.0"
  type        = string
  default     = "opentelemetry0.7"

  validation {
    condition     = contains(["opentelemetry0.7", "opentelemetry1.0"], var.metric_stream_output_format)
    error_message = "Output format must be opentelemetry0.7 or opentelemetry1.0."
  }
}

variable "metric_stream_include_filters" {
  description = "Map of namespaces and metric names to include in metric stream"
  type        = map(list(string))
  default     = {}
}

variable "metric_stream_exclude_filters" {
  description = "Map of namespaces and metric names to exclude from metric stream"
  type        = map(list(string))
  default     = {}
}

variable "newrelic_firehose_endpoint" {
  description = "New Relic Firehose endpoint URL"
  type        = string
  default     = "https://aws-api.newrelic.com/cloudwatch-metrics/v1"
}

# S3 Configuration
variable "force_destroy_s3_bucket" {
  description = "Force destroy S3 bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "s3_backup_retention_days" {
  description = "Number of days to retain failed metric data in S3"
  type        = number
  default     = 30
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# Service Integration Toggles
variable "enable_lambda_integration" {
  description = "Enable AWS Lambda integration"
  type        = bool
  default     = true
}

variable "enable_api_gateway_integration" {
  description = "Enable AWS API Gateway integration"
  type        = bool
  default     = true
}

variable "enable_sqs_integration" {
  description = "Enable AWS SQS integration"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_integration" {
  description = "Enable AWS CloudWatch integration"
  type        = bool
  default     = true
}

variable "enable_xray_integration" {
  description = "Enable AWS X-Ray integration"
  type        = bool
  default     = true
}

# Polling Intervals (in seconds)
variable "lambda_polling_interval" {
  description = "Lambda metrics polling interval in seconds"
  type        = number
  default     = 300
}

variable "api_gateway_polling_interval" {
  description = "API Gateway metrics polling interval in seconds"
  type        = number
  default     = 300
}

variable "sqs_polling_interval" {
  description = "SQS metrics polling interval in seconds"
  type        = number
  default     = 300
}

variable "cloudwatch_polling_interval" {
  description = "CloudWatch metrics polling interval in seconds"
  type        = number
  default     = 300
}

variable "xray_polling_interval" {
  description = "X-Ray metrics polling interval in seconds"
  type        = number
  default     = 300
}

# Service-specific configurations
variable "api_gateway_stage_prefixes" {
  description = "List of API Gateway stage prefixes to monitor"
  type        = list(string)
  default     = []
}

variable "sqs_fetch_extended_inventory" {
  description = "Fetch extended SQS inventory"
  type        = bool
  default     = true
}

variable "sqs_fetch_tags" {
  description = "Fetch SQS tags"
  type        = bool
  default     = true
}

variable "sqs_queue_prefixes" {
  description = "List of SQS queue prefixes to monitor"
  type        = list(string)
  default     = []
}
