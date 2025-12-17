# Lambda Module Outputs

output "lambda1_function_name" {
  description = "Name of Lambda 1 function"
  value       = aws_lambda_function.lambda1.function_name
}

output "lambda1_function_arn" {
  description = "ARN of Lambda 1 function"
  value       = aws_lambda_function.lambda1.arn
}

output "lambda1_invoke_arn" {
  description = "Invoke ARN of Lambda 1 function"
  value       = aws_lambda_function.lambda1.invoke_arn
}

output "lambda1_role_arn" {
  description = "ARN of Lambda 1 IAM role"
  value       = aws_iam_role.lambda1_role.arn
}

output "lambda2_function_name" {
  description = "Name of Lambda 2 function"
  value       = aws_lambda_function.lambda2.function_name
}

output "lambda2_function_arn" {
  description = "ARN of Lambda 2 function"
  value       = aws_lambda_function.lambda2.arn
}

output "lambda2_invoke_arn" {
  description = "Invoke ARN of Lambda 2 function"
  value       = aws_lambda_function.lambda2.invoke_arn
}

output "lambda2_role_arn" {
  description = "ARN of Lambda 2 IAM role"
  value       = aws_iam_role.lambda2_role.arn
}

output "lambda1_log_group_name" {
  description = "CloudWatch log group name for Lambda 1"
  value       = aws_cloudwatch_log_group.lambda1_logs.name
}

output "lambda2_log_group_name" {
  description = "CloudWatch log group name for Lambda 2"
  value       = aws_cloudwatch_log_group.lambda2_logs.name
}

# SQS Outputs
output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.message_queue.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.message_queue.url
}

output "sqs_dlq_arn" {
  description = "ARN of the SQS dead letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "sqs_trigger_uuid" {
  description = "UUID of the SQS event source mapping"
  value       = aws_lambda_event_source_mapping.sqs_trigger.uuid
}

# API Gateway Outputs
output "api_gateway_rest_api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}"
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.api_stage.stage_name
}

output "lambda_functions_summary" {
  description = "Summary of created Lambda functions"
  value = {
    lambda1 = {
      name      = aws_lambda_function.lambda1.function_name
      arn       = aws_lambda_function.lambda1.arn
      runtime   = aws_lambda_function.lambda1.runtime
      timeout   = aws_lambda_function.lambda1.timeout
      log_group = aws_cloudwatch_log_group.lambda1_logs.name
    }
    lambda2 = {
      name      = aws_lambda_function.lambda2.function_name
      arn       = aws_lambda_function.lambda2.arn
      runtime   = aws_lambda_function.lambda2.runtime
      timeout   = aws_lambda_function.lambda2.timeout
      log_group = aws_cloudwatch_log_group.lambda2_logs.name
    }
  }
}
