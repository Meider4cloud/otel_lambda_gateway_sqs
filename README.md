# Serverless POC Infrastructure

This Terraform configuration deploys a serverless architecture on AWS with the following components:

## Architecture

```
API Gateway → Lambda 1 (API Handler) → SQS Queue → Lambda 2 (Worker)
```

### Components

1. **API Gateway**: REST API endpoint at `/process`
2. **Lambda 1**: API handler that processes HTTP requests and sends messages to SQS
3. **SQS Queue**: Message queue for decoupling the API handler from the worker
4. **Lambda 2**: Worker function that processes messages from SQS
5. **CloudWatch Logs**: Logging for both Lambda functions
6. **IAM Roles**: Proper permissions for all components

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (>= 1.0)
- Python 3.9+ for local testing

## Deployment

1. **Initialize Terraform**:

   ```bash
   cd terraform
   terraform init
   ```

2. **Plan the deployment**:

   ```bash
   terraform plan
   ```

3. **Apply the infrastructure**:

   ```bash
   terraform apply
   ```

4. **Get the API endpoint**:
   ```bash
   terraform output api_gateway_invoke_url
   ```

## Usage

### Testing the API

Send a POST request to the API Gateway endpoint:

```bash
curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/dev/process \
  -H "Content-Type: application/json" \
  -d '{"action": "process_order", "orderId": "12345", "amount": 100}'
```

### Example Request Payloads

#### Process Order

```json
{
  "action": "process_order",
  "orderId": "12345",
  "amount": 100,
  "customerId": "cust_001"
}
```

#### Send Notification

```json
{
  "action": "send_notification",
  "recipient": "user@example.com",
  "message": "Your order has been processed"
}
```

## Configuration

### Variables

- `aws_region`: AWS region (default: us-east-1)
- `environment`: Environment name (default: poc)
- `project_name`: Project name (default: otel-alml)
- `api_stage_name`: API Gateway stage (default: dev)
- `lambda_timeout`: Lambda timeout in seconds (default: 30)
- `sqs_visibility_timeout`: SQS visibility timeout (default: 300)

### Customization

You can customize the deployment by creating a `terraform.tfvars` file:

```hcl
aws_region = "us-west-2"
environment = "staging"
project_name = "my-app"
lambda_timeout = 60
```

## Monitoring

- **CloudWatch Logs**: Check `/aws/lambda/FUNCTION_NAME` log groups
- **SQS Metrics**: Monitor queue depth and message processing in CloudWatch
- **API Gateway Metrics**: Track API calls, latency, and errors

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```

## File Structure

```
.
├── terraform/
│   ├── main.tf              # Provider and data sources
│   ├── variables.tf         # Input variables
│   ├── iam.tf              # IAM roles and policies
│   ├── lambda.tf           # Lambda functions and triggers
│   ├── sqs.tf              # SQS queue configuration
│   ├── api_gateway.tf      # API Gateway setup
│   └── outputs.tf          # Output values
├── lambda1/
│   ├── index.py            # API handler code
│   └── requirements.txt    # Python dependencies
└── lambda2/
    ├── index.py            # Worker code
    └── requirements.txt    # Python dependencies
```

## Next Steps

1. Implement your specific business logic in the Lambda functions
2. Add error handling and retry mechanisms
3. Implement authentication/authorization if needed
4. Add monitoring and alerting
5. Consider adding a DLQ (Dead Letter Queue) for failed messages
6. Add environment-specific configurations
7. Implement CI/CD pipeline for automated deployments

## edits

```bash
curl -X POST https://4g15hn10p9.execute-api.eu-central-1.amazonaws.com/dev/process \
  -H "Content-Type: application/json" \
  -d '{"action": "process_order", "orderId": "12345", "amount": 100}'
```
