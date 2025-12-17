# New Relic AWS Cloud Integration Module
# Based on: https://registry.terraform.io/providers/newrelic/newrelic/latest/docs/guides/cloud_integrations_guide#aws

# terraform {
#   required_providers {
#     newrelic = {
#       source  = "newrelic/newrelic"
#       version = "~> 3.0"
#     }
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# Data sources for AWS account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# New Relic cloud account linking
resource "newrelic_cloud_aws_link_account" "aws_link" {
  arn                    = aws_iam_role.newrelic_integration_role.arn
  name                   = var.integration_name
  metric_collection_mode = var.metric_collection_mode
}

# IAM role for New Relic to assume
resource "aws_iam_role" "newrelic_integration_role" {
  name = "${var.integration_name}-newrelic-integration-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::754728514883:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.newrelic_account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "NewRelic AWS Integration"
  })
}

# IAM policy for New Relic integration with read-only access
resource "aws_iam_role_policy" "newrelic_integration_policy" {
  name = "${var.integration_name}-newrelic-integration-policy"
  role = aws_iam_role.newrelic_integration_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Core permissions for monitoring
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",

          # EC2 and compute
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",

          # Lambda
          "lambda:ListFunctions",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
          "lambda:GetAlias",
          "lambda:ListTags",

          # SQS
          "sqs:ListQueues",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags",

          # API Gateway
          "apigateway:GET",

          # X-Ray
          "xray:GetTraceSummaries",
          "xray:GetServiceGraph",
          "xray:GetTimeSeriesServiceStatistics",

          # Resource Groups and Tags
          "tag:GetResources",
          "resource-groups:ListGroupResources",
          "resource-groups:GetGroup",
          "resource-groups:ListGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# New Relic AWS integrations - Enable specific AWS services
resource "newrelic_cloud_aws_integrations" "aws_integrations" {
  linked_account_id = newrelic_cloud_aws_link_account.aws_link.id

  # Lambda integration
  dynamic "lambda" {
    for_each = var.enable_lambda_integration ? [1] : []
    content {
      metrics_polling_interval = var.lambda_polling_interval
      aws_regions              = var.aws_regions
    }
  }

  # API Gateway integration
  dynamic "api_gateway" {
    for_each = var.enable_api_gateway_integration ? [1] : []
    content {
      metrics_polling_interval = var.api_gateway_polling_interval
      aws_regions              = var.aws_regions
      stage_prefixes           = var.api_gateway_stage_prefixes
    }
  }

  # SQS integration
  dynamic "sqs" {
    for_each = var.enable_sqs_integration ? [1] : []
    content {
      metrics_polling_interval = var.sqs_polling_interval
      aws_regions              = var.aws_regions
      fetch_extended_inventory = var.sqs_fetch_extended_inventory
      fetch_tags               = var.sqs_fetch_tags
      queue_prefixes           = var.sqs_queue_prefixes
    }
  }

  #   # CloudWatch integration
  #   dynamic "cloudwatch" {
  #     for_each = var.enable_cloudwatch_integration ? [1] : []
  #     content {
  #       metrics_polling_interval = var.cloudwatch_polling_interval
  #       aws_regions              = var.aws_regions
  #     }
  #   }

  # X-Ray integration
  dynamic "x_ray" {
    for_each = var.enable_xray_integration ? [1] : []
    content {
      metrics_polling_interval = var.xray_polling_interval
      aws_regions              = var.aws_regions
    }
  }
}

# CloudWatch Metric Stream (recommended for most metrics)
resource "aws_cloudwatch_metric_stream" "newrelic_metric_stream" {
  count = var.enable_metric_stream ? 1 : 0

  name          = "${var.integration_name}-newrelic-metric-stream"
  role_arn      = aws_iam_role.metric_stream_role[0].arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.newrelic_stream[0].arn
  output_format = var.metric_stream_output_format

  dynamic "include_filter" {
    for_each = var.metric_stream_include_filters
    content {
      namespace    = include_filter.key
      metric_names = include_filter.value
    }
  }

  dynamic "exclude_filter" {
    for_each = var.metric_stream_exclude_filters
    content {
      namespace    = exclude_filter.key
      metric_names = exclude_filter.value
    }
  }

  tags = var.tags
}

# IAM role for CloudWatch Metric Stream
resource "aws_iam_role" "metric_stream_role" {
  count = var.enable_metric_stream ? 1 : 0

  name = "${var.integration_name}-metric-stream-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "streams.metrics.cloudwatch.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for CloudWatch Metric Stream
resource "aws_iam_role_policy" "metric_stream_policy" {
  count = var.enable_metric_stream ? 1 : 0

  name = "${var.integration_name}-metric-stream-policy"
  role = aws_iam_role.metric_stream_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.newrelic_stream[0].arn
      }
    ]
  })
}

# Kinesis Data Firehose delivery stream
resource "aws_kinesis_firehose_delivery_stream" "newrelic_stream" {
  count = var.enable_metric_stream ? 1 : 0

  name        = "${var.integration_name}-newrelic-stream"
  destination = "http_endpoint"

  http_endpoint_configuration {
    name               = "New Relic"
    url                = var.newrelic_firehose_endpoint
    role_arn           = aws_iam_role.firehose_role[0].arn
    s3_backup_mode     = "FailedDataOnly"
    buffering_interval = 60
    buffering_size     = 5
    retry_duration     = 60

    request_configuration {
      content_encoding = "GZIP"

      common_attributes {
        name  = "licenseKey"
        value = var.newrelic_license_key
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs[0].name
      log_stream_name = aws_cloudwatch_log_stream.firehose_logs[0].name
    }

    s3_configuration {
      role_arn   = aws_iam_role.firehose_role[0].arn
      bucket_arn = aws_s3_bucket.firehose_backup[0].arn
      prefix     = "failed-metrics/"

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = aws_cloudwatch_log_group.firehose_logs[0].name
        log_stream_name = aws_cloudwatch_log_stream.firehose_logs[0].name
      }
    }
  }

  tags = var.tags
}

# IAM role for Kinesis Firehose
resource "aws_iam_role" "firehose_role" {
  count = var.enable_metric_stream ? 1 : 0

  name = "${var.integration_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Kinesis Firehose
resource "aws_iam_role_policy" "firehose_policy" {
  count = var.enable_metric_stream ? 1 : 0

  name = "${var.integration_name}-firehose-policy"
  role = aws_iam_role.firehose_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.firehose_backup[0].arn,
          "${aws_s3_bucket.firehose_backup[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 bucket for failed metric stream data
resource "aws_s3_bucket" "firehose_backup" {
  count = var.enable_metric_stream ? 1 : 0

  bucket        = "${var.integration_name}-newrelic-firehose-backup-${random_id.bucket_suffix[0].hex}"
  force_destroy = var.force_destroy_s3_bucket

  tags = var.tags
}

# Random ID for S3 bucket suffix
resource "random_id" "bucket_suffix" {
  count = var.enable_metric_stream ? 1 : 0

  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "firehose_backup_versioning" {
  count = var.enable_metric_stream ? 1 : 0

  bucket = aws_s3_bucket.firehose_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup_encryption" {
  count = var.enable_metric_stream ? 1 : 0

  bucket = aws_s3_bucket.firehose_backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "firehose_backup_lifecycle" {
  count = var.enable_metric_stream ? 1 : 0

  bucket = aws_s3_bucket.firehose_backup[0].id

  rule {
    id     = "failed_metrics_lifecycle"
    status = "Enabled"

    expiration {
      days = var.s3_backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# CloudWatch log group for Firehose
resource "aws_cloudwatch_log_group" "firehose_logs" {
  count = var.enable_metric_stream ? 1 : 0

  name              = "/aws/firehose/${var.integration_name}-newrelic-stream"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = var.tags
}

# CloudWatch log stream for Firehose
resource "aws_cloudwatch_log_stream" "firehose_logs" {
  count = var.enable_metric_stream ? 1 : 0

  name           = "${var.integration_name}-firehose-logs"
  log_group_name = aws_cloudwatch_log_group.firehose_logs[0].name
}
