# New Relic AWS Integration Terraform Module

This Terraform module sets up comprehensive AWS monitoring integration with New Relic, providing both CloudWatch Metric Streams (recommended) and API polling for various AWS services.

## Features

- **CloudWatch Metric Stream**: Real-time metric streaming via Kinesis Data Firehose (recommended approach)
- **API Polling Integration**: Poll AWS APIs for services not supported by metric streams
- **Comprehensive Service Coverage**: Lambda, API Gateway, SQS, CloudWatch, X-Ray
- **Flexible Configuration**: Enable/disable specific services and customize polling intervals
- **Security Best Practices**: IAM roles with least privilege access
- **Backup & Logging**: S3 backup for failed metrics and CloudWatch logging

## Usage

### Basic Example

```hcl
module "newrelic_aws_integration" {
  source = "./modules/newrelic-aws-integration"

  newrelic_account_id  = "1234567"
  newrelic_license_key = var.newrelic_license_key
  integration_name     = "production-monitoring"
  aws_regions          = ["us-east-1", "eu-central-1"]

  # Enable specific integrations
  enable_lambda_integration      = true
  enable_api_gateway_integration = true
  enable_sqs_integration        = true
  enable_xray_integration       = true

  tags = {
    Environment = "production"
    Project     = "otel-alml"
    Owner       = "infrastructure-team"
  }
}
```

### Advanced Example with Metric Stream Filters

```hcl
module "newrelic_aws_integration" {
  source = "./modules/newrelic-aws-integration"

  newrelic_account_id  = var.newrelic_account_id
  newrelic_license_key = var.newrelic_license_key
  integration_name     = "production-monitoring"
  aws_regions          = ["us-east-1", "us-west-2"]

  # CloudWatch Metric Stream configuration
  enable_metric_stream         = true
  metric_stream_output_format  = "opentelemetry1.0"

  # Include specific metrics
  metric_stream_include_filters = {
    "AWS/Lambda"     = []  # Include all Lambda metrics
    "AWS/ApiGateway" = []  # Include all API Gateway metrics
    "AWS/SQS"        = ["ApproximateNumberOfMessages", "NumberOfMessagesSent"]
  }

  # Service-specific configurations
  enable_lambda_integration      = true
  lambda_polling_interval       = 300

  enable_sqs_integration        = true
  sqs_fetch_extended_inventory  = true
  sqs_fetch_tags               = true

  enable_api_gateway_integration = true
  api_gateway_stage_prefixes    = ["prod", "staging"]

  # Storage and retention
  s3_backup_retention_days       = 90
  cloudwatch_log_retention_days  = 30
  force_destroy_s3_bucket       = false

  tags = {
    Environment = "production"
    Project     = "monitoring"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | ~> 5.0  |
| newrelic  | ~> 3.0  |
| random    | ~> 3.0  |

## Providers

| Name     | Version |
| -------- | ------- |
| aws      | ~> 5.0  |
| newrelic | ~> 3.0  |
| random   | ~> 3.0  |

## Inputs

### Required Variables

| Name                 | Description                             | Type     |
| -------------------- | --------------------------------------- | -------- |
| newrelic_account_id  | The New Relic account ID                | `string` |
| newrelic_license_key | New Relic license key for metric stream | `string` |

### Optional Variables

| Name                           | Description                                        | Type           | Default          |
| ------------------------------ | -------------------------------------------------- | -------------- | ---------------- |
| integration_name               | Name for the integration (used in resource naming) | `string`       | `"aws-newrelic"` |
| aws_regions                    | List of AWS regions to monitor                     | `list(string)` | `["us-east-1"]`  |
| enable_metric_stream           | Enable CloudWatch Metric Stream                    | `bool`         | `true`           |
| metric_collection_mode         | Metric collection mode: PUSH or PULL               | `string`       | `"PULL"`         |
| enable_lambda_integration      | Enable AWS Lambda integration                      | `bool`         | `true`           |
| enable_api_gateway_integration | Enable AWS API Gateway integration                 | `bool`         | `true`           |
| enable_sqs_integration         | Enable AWS SQS integration                         | `bool`         | `true`           |
| enable_xray_integration        | Enable AWS X-Ray integration                       | `bool`         | `true`           |

See [variables.tf](./variables.tf) for the complete list of configurable options.

## Outputs

| Name                 | Description                                           |
| -------------------- | ----------------------------------------------------- |
| integration_name     | Name of the New Relic AWS integration                 |
| linked_account_id    | New Relic linked account ID                           |
| integration_role_arn | ARN of the IAM role created for New Relic integration |
| aws_account_id       | AWS Account ID where integration is configured        |
| enabled_integrations | List of enabled AWS service integrations              |
| metric_stream_arn    | ARN of the CloudWatch Metric Stream (if enabled)      |
| integration_summary  | Summary of the integration configuration              |

## Architecture

### CloudWatch Metric Stream (Recommended)

```
AWS CloudWatch → Metric Stream → Kinesis Firehose → New Relic
                                      ↓
                               S3 (Failed Data Backup)
```

### API Polling Integration

```
New Relic ←→ IAM Role ←→ AWS APIs (Lambda, SQS, etc.)
```

## Resources Created

- **IAM Role & Policies**: For New Relic to access AWS resources
- **CloudWatch Metric Stream**: Real-time metric streaming (if enabled)
- **Kinesis Data Firehose**: Delivery stream to New Relic
- **S3 Bucket**: Backup for failed metric deliveries
- **CloudWatch Logs**: Logging for Firehose operations
- **New Relic Cloud Account Link**: Links AWS account to New Relic
- **New Relic Service Integrations**: Enables specific AWS services

## Security

- IAM roles follow least privilege principle
- Cross-account access uses external ID for additional security
- S3 bucket encryption enabled by default
- CloudWatch logs for monitoring integration health

## Cost Considerations

- **Metric Stream**: Charges for CloudWatch custom metrics and Kinesis Firehose data processing
- **API Polling**: Charges for AWS API calls (typically minimal)
- **S3 Storage**: Charges for failed metric backup storage
- **Data Transfer**: Outbound data transfer charges may apply

## Monitoring

- CloudWatch logs provide visibility into Firehose delivery status
- S3 bucket contains failed metric deliveries for troubleshooting
- New Relic Infrastructure monitoring shows integration health

## Limitations

- Some AWS services require API polling and are not available via Metric Stream
- Metric Stream has a slight delay compared to real-time polling
- Regional restrictions may apply to certain integrations

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Update documentation for any new variables or outputs
3. Test with different AWS regions and service combinations
4. Ensure security best practices are maintained

## Support

For issues related to:

- **Module functionality**: Open an issue in this repository
- **New Relic integration**: Check [New Relic documentation](https://docs.newrelic.com/docs/infrastructure/amazon-integrations/)
- **AWS services**: Refer to [AWS documentation](https://docs.aws.amazon.com/)

## License

This module is provided under the MIT License. See LICENSE file for details.
