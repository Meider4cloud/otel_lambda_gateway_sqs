# OpenTelemetry Lambda Functions Module

This Terraform module creates AWS Lambda functions with OpenTelemetry instrumentation support.

## Features

- **Dual Lambda Setup**: API handler and worker functions
- **OpenTelemetry Ready**: Supports various observability configurations
- **Flexible Configuration**: Customizable runtime, timeout, layers, and environment variables
- **IAM Integration**: Proper roles and policies for SQS and observability services
- **CloudWatch Integration**: Automatic log groups with configurable retention
- **SQS Event Source**: Worker function triggered by SQS messages

## Architecture

```
API Gateway → Lambda1 (API Handler) → SQS → Lambda2 (Worker)
     ↓              ↓                         ↓
CloudWatch     CloudWatch                CloudWatch
   Logs          Logs                     Logs
```

## Usage

```hcl
module "lambda_otel" {
  source = "./modules/lambda-otel"

  # Basic configuration
  project_name = "my-project"
  environment  = "prod"

  # Lambda source directories
  lambda1_source_dir = "${path.module}/../lambda1"
  lambda2_source_dir = "${path.module}/../lambda2"

  # Lambda configuration
  lambda_runtime = "python3.9"
  lambda_timeout = 30
  lambda_layers  = ["arn:aws:lambda:region:account:layer:otel-layer:1"]

  # Environment variables
  lambda1_environment_variables = {
    SQS_QUEUE_URL = aws_sqs_queue.queue.url
    ENVIRONMENT   = "prod"
  }

  lambda2_environment_variables = {
    ENVIRONMENT = "prod"
  }

  # SQS integration
  sqs_queue_arn = aws_sqs_queue.queue.arn

  # Additional IAM permissions
  additional_iam_permissions = [
    "xray:PutTraceSegments",
    "xray:PutTelemetryRecords"
  ]

  tags = {
    Environment = "prod"
    Project     = "my-project"
  }
}
```

## Inputs

| Name               | Description                               | Type           | Default       | Required |
| ------------------ | ----------------------------------------- | -------------- | ------------- | -------- |
| project_name       | Project name for resource naming          | `string`       | n/a           | yes      |
| environment        | Environment name                          | `string`       | n/a           | yes      |
| lambda1_source_dir | Source directory for Lambda 1 code        | `string`       | n/a           | yes      |
| lambda2_source_dir | Source directory for Lambda 2 code        | `string`       | n/a           | yes      |
| sqs_queue_arn      | ARN of the SQS queue for Lambda 2 trigger | `string`       | n/a           | yes      |
| lambda_runtime     | Lambda runtime version                    | `string`       | `"python3.9"` | no       |
| lambda_timeout     | Lambda function timeout in seconds        | `number`       | `30`          | no       |
| lambda_layers      | List of Lambda layer ARNs                 | `list(string)` | `[]`          | no       |
| tags               | Tags to apply to all resources            | `map(string)`  | `{}`          | no       |

## Outputs

| Name                     | Description                      |
| ------------------------ | -------------------------------- |
| lambda1_function_name    | Name of Lambda 1 function        |
| lambda1_function_arn     | ARN of Lambda 1 function         |
| lambda2_function_name    | Name of Lambda 2 function        |
| lambda2_function_arn     | ARN of Lambda 2 function         |
| lambda_functions_summary | Summary of both Lambda functions |

## Resources Created

- 2x AWS Lambda Functions (API handler + worker)
- 2x IAM Roles with appropriate policies
- 2x CloudWatch Log Groups
- 1x SQS Event Source Mapping

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | ~> 5.0  |
| archive   | ~> 2.0  |
