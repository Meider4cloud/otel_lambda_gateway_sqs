# IAM Role for Lambda 1 (API Handler)
resource "aws_iam_role" "lambda1_role" {
  name = "${var.project_name}-${var.environment}-lambda1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# IAM Policy for Lambda 1
resource "aws_iam_role_policy" "lambda1_policy" {
  name = "${var.project_name}-${var.environment}-lambda1-policy"
  role = aws_iam_role.lambda1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.message_queue.arn
      },
      {
        Effect = "Allow"
        Action = concat(local.current_config.iam_permissions, [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ])
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Lambda 2 (Worker)
resource "aws_iam_role" "lambda2_role" {
  name = "${var.project_name}-${var.environment}-lambda2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# IAM Policy for Lambda 2
resource "aws_iam_role_policy" "lambda2_policy" {
  name = "${var.project_name}-${var.environment}-lambda2-policy"
  role = aws_iam_role.lambda2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = concat(local.current_config.iam_permissions, [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ])
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.message_queue.arn
      }
    ]
  })
}
