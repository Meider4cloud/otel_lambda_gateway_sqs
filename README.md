# OpenTelemetry AWS Lambda ML POC

This Terraform project demonstrates **distributed tracing and observability** in serverless AWS architectures using OpenTelemetry and New Relic. It implements **trace context propagation** through SQS message queues to link Lambda function executions across service boundaries.

> This project is meant as a demonstaration and does not represent production ready code. Some features might also not be fully functional.

## 🎯 Project Goals

- **Trace Propagation**: Link Lambda executions through SQS using OpenTelemetry trace context
- **Multi-Backend Support**: Compare X-Ray vs New Relic observability approaches
- **Modular Architecture**: Clean separation between infrastructure and observability configurations
- **Production Ready**: IAM roles, error handling, and comprehensive monitoring

## 🏗️ Architecture

```
API Gateway → Lambda1 (API Handler) → SQS Queue → Lambda2 (Worker)
                ↓                         ↓            ↓
            Trace Context           Message Attrs   Linked Trace
```

### Components

1. **API Gateway**: REST API endpoint at `/process`
2. **Lambda1 (API Handler)**: Processes HTTP requests, extracts trace context, sends to SQS
3. **SQS Queue**: Message queue with trace context propagation via message attributes
4. **Lambda2 (Worker)**: Processes SQS messages, links to parent trace using custom attributes
5. **New Relic Integration**: CloudWatch Metric Streams + native Lambda monitoring
6. **Modular Infrastructure**: Separate terraform modules for clean organization

## 🎛️ Observability Configurations

The project supports **3 configurable observability setups**:

| Config                   | Backend   | Implementation                      | Layer        | Use Case               |
| ------------------------ | --------- | ----------------------------------- | ------------ | ---------------------- |
| **`xray_adot`**          | AWS X-Ray | AWS Distro for OpenTelemetry (ADOT) | AWS Managed  | AWS-native tracing     |
| **`newrelic_community`** | New Relic | Community OpenTelemetry             | Custom build | Direct OTLP export     |
| **`newrelic_native`**    | New Relic | New Relic Lambda Layer              | NR Managed   | APM with trace linking |

_Currently active: **`newrelic_native`** with trace propagation through SQS_

## 🚀 Quick Start

### Prerequisites

- **AWS CLI** with profile `<Your Profile>`
- **Terraform** >= 1.0
- **New Relic Account** (for configs 2-3)

### Deploy Infrastructure

```bash
# Clone and navigate
cd terraform

# Configure observability (optional - defaults to xray_adot)
echo 'observability_config = "newrelic_native"' > terraform.tfvars
echo 'newrelic_license_key = "your-license-key"' >> terraform.tfvars
echo 'newrelic_account_id = "your-account-id"' >> terraform.tfvars

# Deploy
terraform init
terraform apply

# Capture API endpoint as environment variable
export API_ENDPOINT=$(terraform output -raw api_gateway_invoke_url)
echo "API Endpoint: $API_ENDPOINT"
```

## 📡 Testing Trace Propagation

### Send Test Requests

```bash
# Using the captured API endpoint
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Testing trace propagation",
    "priority": "high",
    "test_id": "trace-test-001"
  }'
```

### Verify Trace Linking

**In New Relic (newrelic_native config):**

- Search for transactions with `parent_trace_id` custom attribute
- Filter by `aws.sqs.QueueName = "otel-alml-poc-queue"`
- View service map showing `api-handler` → `worker` relationship

**In AWS X-Ray (xray_adot config):**

- View service map in X-Ray console
- Traces show complete request flow through SQS

## ⚙️ Configuration Options

### Required Variables

```hcl
# terraform.tfvars
aws_region = "eu-central-1"
project_name = "otel-alml"
environment = "poc"

# For New Relic configurations
newrelic_license_key = "your-new-relic-license-key"  # for data ingest into New Relic.
newrelic_account_id = "your-new-relic-account-id"
newrelic_api_key = "your-new-relic-user-key" # For configuring the New Relic resources.

# Choose observability backend
observability_config = "newrelic_native"  # xray_adot | newrelic_community | newrelic_native
```

### Optional Variables

- `api_stage_name`: API Gateway stage (default: `poc`)
- `lambda_timeout`: Lambda timeout in seconds (default: `30`)
- `sqs_visibility_timeout`: SQS visibility timeout (default: `300`)

## 🏗️ Infrastructure Modules

### Core Module: `lambda-otel`

**Location**: `modules/lambda-otel/`

- Lambda functions with configurable observability layers
- SQS queue with DLQ for reliable message processing
- API Gateway with proper IAM integration
- CloudWatch log groups with retention policies
- Dynamic source directory selection based on observability config

### Integration Module: `newrelic-aws-integration`

**Location**: `modules/newrelic-aws-integration/`

- CloudWatch Metric Streams → Kinesis Firehose → New Relic
- S3 backup bucket for failed deliveries
- Comprehensive IAM permissions for AWS service monitoring
- New Relic cloud integrations for Lambda, SQS, API Gateway

## 📂 Project Structure

```
otelALML/
├── terraform/                    # Main Terraform configuration
│   ├── main.tf                  # Module instantiation & providers
│   ├── locals.tf                # Observability configurations
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # API endpoints & resource info
│   └── terraform.tfvars.example # Example configuration
├── modules/
│   ├── lambda-otel/             # Lambda infrastructure module
│   │   ├── main.tf              # Lambda functions, SQS, API Gateway
│   │   ├── variables.tf         # Module variables
│   │   └── outputs.tf           # Module outputs
│   └── newrelic-aws-integration/ # New Relic monitoring module
│       ├── main.tf              # CloudWatch streams & integrations
│       └── variables.tf         # New Relic configuration
├── lambda1/                     # OpenTelemetry Lambda source
│   ├── index.py                 # API handler with OTel instrumentation
│   └── requirements.txt         # OTel dependencies
├── lambda1-newrelic-native/     # New Relic native source
│   ├── index.py                 # Clean handler for NR layer
│   └── requirements.txt         # Minimal dependencies
├── lambda2/                     # OpenTelemetry worker source
│   └── index.py                 # SQS processor with trace linking
├── lambda2-newrelic-native/     # New Relic native worker
│   └── index.py                 # Clean worker for NR layer
└── scripts/                     # Utility scripts
    └── build_layers.sh          # Build custom OTel layers

```

## 🔍 Observability Features

### Trace Context Propagation

**Lambda1 → SQS:**

- Extracts New Relic/X-Ray trace ID and span ID
- Propagates via SQS message attributes (`newrelic_trace_id`, `newrelic_span_id`)
- Adds custom attributes: `aws.sqs.QueueName`, `service_name`, `message_id`

**SQS → Lambda2:**

- Reads trace context from message attributes
- Links to parent trace using `parent_trace_id` custom attribute
- Maintains service correlation with `trace_relationship` metadata

### Custom Attributes for Filtering

| Attribute            | Purpose                     | Values                  |
| -------------------- | --------------------------- | ----------------------- |
| `parent_trace_id`    | Link child traces to parent | New Relic trace ID      |
| `aws.sqs.QueueName`  | Filter by SQS queue         | `otel-alml-poc-queue`   |
| `service_name`       | Identify service role       | `api-handler`, `worker` |
| `trace_relationship` | Trace hierarchy             | `child`, `standalone`   |
| `trace_link_method`  | Propagation method          | `sqs_propagation`       |

## 🚨 Troubleshooting

### Common Issues

1. **SQS Message Attributes**: Cannot use names starting with `AWS.` or `Amazon.` (AWS reserved)
2. **New Relic Layer**: Use ARN `arn:aws:lambda:eu-central-1:451483290750:layer:NewRelicPython39:107`
3. **S3 Bucket Deletion**: Empty bucket before `terraform destroy`:
   ```bash
   aws s3 rm s3://BUCKET-NAME --recursive --profile <Your Profile> --region eu-central-1
   ```

### Check Logs

```bash
# Lambda1 logs (API Handler)
aws logs describe-log-streams --profile <Your Profile> --region eu-central-1 \
  --log-group-name "/aws/lambda/otel-alml-poc-api-handler" --order-by LastEventTime --descending

# Lambda2 logs (Worker)
aws logs describe-log-streams --profile <Your Profile> --region eu-central-1 \
  --log-group-name "/aws/lambda/otel-alml-poc-worker" --order-by LastEventTime --descending
```

## 🧹 Clean Up

```bash
# Remove all infrastructure
terraform destroy -auto-approve

# If S3 bucket errors occur, empty first:
aws s3 rm s3://otel-alml-poc-newrelic-firehose-backup-* --recursive \
  --profile <Your Profile> --region eu-central-1
```

## 🎯 Key Learnings

1. **Trace Propagation**: Manual trace context extraction and injection required for SQS boundaries
2. **Layer Conflicts**: Avoid mixing OpenTelemetry and New Relic instrumentations in same function
3. **IAM Permissions**: New Relic AWS integration needs comprehensive read permissions across services
4. **Source Separation**: Clean source directories prevent instrumentation library conflicts
5. **Custom Attributes**: Essential for linking distributed traces across service boundaries

## 📚 References

- [OpenTelemetry Python Instrumentation](https://opentelemetry.io/docs/instrumentation/python/)
- [New Relic Lambda Monitoring](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/)
- [AWS X-Ray Developer Guide](https://docs.aws.amazon.com/xray/latest/devguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
