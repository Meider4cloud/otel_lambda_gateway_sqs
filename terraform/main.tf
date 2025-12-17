terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "ProjectAdmin-339712788047"
}

# New Relic provider (configure with environment variables or tfvars when using)
provider "newrelic" {
  # Configure via TF_VAR_newrelic_account_id, TF_VAR_newrelic_api_key, TF_VAR_newrelic_region
  # or set dummy values if not using New Relic integration
  account_id = var.newrelic_account_id != null ? var.newrelic_account_id : "0000000"
  api_key    = var.newrelic_api_key != null ? var.newrelic_api_key : "dummy"
  region     = var.newrelic_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda Functions Module
module "lambda_otel" {
  source = "./modules/lambda-otel"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment

  # Lambda source directories
  lambda1_source_dir = "${path.module}/../lambda1"
  lambda2_source_dir = "${path.module}/../lambda2"
  build_dir          = path.module

  # Lambda configuration
  lambda_runtime     = "python3.9"
  lambda_timeout     = var.lambda_timeout
  lambda_layers      = local.current_config.layers
  log_retention_days = 7

  # Environment variables
  lambda1_environment_variables = local.lambda1_env_vars
  lambda2_environment_variables = local.lambda2_env_vars

  # SQS configuration
  sqs_batch_size = 10
  api_stage_name = var.environment

  # IAM permissions from observability config
  additional_iam_permissions = local.current_config.iam_permissions

  # Tags
  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# New Relic AWS Integration Module (commented out until provider issues resolved)
# Uncomment and configure when ready to use New Relic AWS integration
module "newrelic_aws_integration" {
  count  = var.enable_newrelic_aws_integration && var.newrelic_account_id != null ? 1 : 0
  source = "./modules/newrelic-aws-integration"

  newrelic_account_id = var.newrelic_account_id
  //newrelic_api_key     = var.newrelic_api_key
  newrelic_license_key = var.newrelic_license_key
  integration_name     = "${var.project_name}-${var.environment}"
  aws_regions          = [data.aws_region.current.id]

  # ... other configuration
}

