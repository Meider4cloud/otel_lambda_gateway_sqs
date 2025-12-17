variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "otel-alml"
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}

variable "sqs_visibility_timeout" {
  description = "SQS message visibility timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "default_tags" {
  description = "Default Tags for Infrastructure"
  type        = map(string)
  default     = {}
}

# Observability Configuration Variables
variable "observability_config" {
  description = "Observability configuration type"
  type        = string
  default     = "xray_adot"
  validation {
    condition = contains([
      "xray_adot",         # X-Ray with ADOT layer
      "xray_community",    # X-Ray with community OTel layer  
      "newrelic_adot",     # New Relic with ADOT layer
      "newrelic_community" # New Relic with community OTel layer
    ], var.observability_config)
    error_message = "Observability config must be one of: xray_adot, xray_community, newrelic_adot, newrelic_community."
  }
}

variable "newrelic_license_key" {
  description = "New Relic license key (required for New Relic configurations)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "newrelic_account_id" {
  description = "New Relic account ID (required for New Relic configurations)"
  type        = string
  default     = null
}

# New Relic AWS Integration Variables
variable "newrelic_api_key" {
  description = "New Relic Personal API Key (for AWS integration setup)"
  type        = string
  sensitive   = true
  default     = null
}

variable "newrelic_region" {
  description = "New Relic region (US or EU)"
  type        = string
  default     = "EU"
  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "New Relic region must be US or EU."
  }
}

variable "enable_newrelic_aws_integration" {
  description = "Enable New Relic AWS integration (requires newrelic_account_id and newrelic_api_key)"
  type        = bool
  default     = false
}
