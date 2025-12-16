# Lambda Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod, poc)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.9"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_layers" {
  description = "List of Lambda layer ARNs to attach"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Lambda 1 (API Handler) Configuration
variable "lambda1_source_dir" {
  description = "Source directory for Lambda 1 code"
  type        = string
}

variable "lambda1_handler" {
  description = "Lambda 1 handler function"
  type        = string
  default     = "index.handler"
}

variable "lambda1_environment_variables" {
  description = "Environment variables for Lambda 1"
  type        = map(string)
  default     = {}
}

# Lambda 2 (Worker) Configuration
variable "lambda2_source_dir" {
  description = "Source directory for Lambda 2 code"
  type        = string
}

variable "lambda2_handler" {
  description = "Lambda 2 handler function"
  type        = string
  default     = "index.handler"
}

variable "lambda2_environment_variables" {
  description = "Environment variables for Lambda 2"
  type        = map(string)
  default     = {}
}

# Build Configuration
variable "build_dir" {
  description = "Directory for build artifacts"
  type        = string
  default     = "./build"
}

# SQS Configuration
variable "sqs_visibility_timeout" {
  description = "Visibility timeout for SQS messages (should be >= Lambda timeout)"
  type        = number
  default     = 300
}

variable "sqs_batch_size" {
  description = "SQS batch size for Lambda trigger"
  type        = number
  default     = 10
}

# API Gateway Configuration
variable "api_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "dev"
}

# IAM Configuration
variable "additional_iam_permissions" {
  description = "Additional IAM permissions for Lambda functions"
  type        = list(string)
  default     = []
}
