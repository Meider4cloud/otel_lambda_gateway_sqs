# SQS Queue for message processing
resource "aws_sqs_queue" "message_queue" {
  name                       = "${var.project_name}-${var.environment}-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-${var.environment}-dlq"

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# SQS Queue Policy to allow Lambda to send messages
resource "aws_sqs_queue_policy" "message_queue_policy" {
  queue_url = aws_sqs_queue.message_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda1_role.arn
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.message_queue.arn
      }
    ]
  })
}
