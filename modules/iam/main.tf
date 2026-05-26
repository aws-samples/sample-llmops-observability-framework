# IAM Role for LLMOps monitoring
resource "aws_iam_role" "llmops_role" {
  name = var.llmops_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "ec2.amazonaws.com"]
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for LLMOps monitoring
resource "aws_iam_policy" "llmops_policy" {
  name = "${var.name_prefix}-monitoring-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          for model_id in var.model_ids : "arn:aws:bedrock:*:*:foundation-model/${model_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "LLMOps"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/bedrock/*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "llmops_policy_attachment" {
  role       = aws_iam_role.llmops_role.name
  policy_arn = aws_iam_policy.llmops_policy.arn
}

# IAM role for log analyzer Lambda
resource "aws_iam_role" "log_analyzer_lambda_role" {
  name = var.log_analyzer_role_name

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

  tags = var.tags
}

# IAM policy for log analyzer role
resource "aws_iam_role_policy" "log_analyzer_policy" {
  name = "${var.name_prefix}-log-analyzer-policy"
  role = aws_iam_role.log_analyzer_lambda_role.id

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
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          for model_id in var.model_ids : "arn:aws:bedrock:*::foundation-model/${model_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/bedrock/*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "LLMOps/LogAnalysis"
          }
        }
      }
    ]
  })
}

# IAM role for Bedrock logging
resource "aws_iam_role" "bedrock_logging_role" {
  name = var.bedrock_logging_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_logging_policy" {
  name = "${var.name_prefix}-bedrock-logging-policy"
  role = aws_iam_role.bedrock_logging_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:${var.log_group_name}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}
