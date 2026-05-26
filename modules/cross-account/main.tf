data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─────────────────────────────────────────────────────────────
# Cross-Account Monitoring Role
# Allows trusted accounts to read CloudWatch metrics, logs,
# S3 log data, and guardrail config from this account.
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "cross_account_monitor" {
  count = length(var.trusted_account_ids) > 0 ? 1 : 0

  name = var.cross_account_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.trusted_account_ids : "arn:aws:iam::${account_id}:root"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.name_prefix}-cross-account"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cross_account_monitor_policy" {
  count = length(var.trusted_account_ids) > 0 ? 1 : 0

  name = "${var.name_prefix}-cross-account-monitor-policy"
  role = aws_iam_role.cross_account_monitor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchReadAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsReadAccess"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-*:*"
        ]
      },
      {
        Sid    = "S3LogReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "SecretsManagerReadAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.guardrail_secret_arn
      },
      {
        Sid    = "BedrockGuardrailReadAccess"
        Effect = "Allow"
        Action = [
          "bedrock:GetGuardrail",
          "bedrock:ListGuardrails"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# CloudWatch Cross-Account Sharing (Log Destinations)
# Allows remote accounts to send their Bedrock logs to this
# account's CloudWatch for centralized monitoring.
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_destination" "cross_account_logs" {
  count = length(var.remote_account_configs) > 0 ? 1 : 0

  name       = "${var.name_prefix}-cross-account-log-destination"
  role_arn   = aws_iam_role.log_destination[0].arn
  target_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}"
}

resource "aws_iam_role" "log_destination" {
  count = length(var.remote_account_configs) > 0 ? 1 : 0

  name = "${var.name_prefix}-log-destination-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "log_destination_policy" {
  count = length(var.remote_account_configs) > 0 ? 1 : 0

  name = "${var.name_prefix}-log-destination-policy"
  role = aws_iam_role.log_destination[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_destination_policy" "cross_account_logs" {
  count = length(var.remote_account_configs) > 0 ? 1 : 0

  destination_name = aws_cloudwatch_log_destination.cross_account_logs[0].name

  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRemoteAccountsToSendLogs"
        Effect = "Allow"
        Principal = {
          AWS = [
            for config in var.remote_account_configs : "arn:aws:iam::${config.account_id}:root"
          ]
        }
        Action   = "logs:PutSubscriptionFilter"
        Resource = aws_cloudwatch_log_destination.cross_account_logs[0].arn
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# CloudWatch Observability Access Manager (OAM) Sink
# Enables CloudWatch cross-account observability so remote
# accounts can share metrics and logs with this central account.
# ─────────────────────────────────────────────────────────────

resource "aws_oam_sink" "central_monitoring" {
  count = length(var.trusted_account_ids) > 0 ? 1 : 0

  name = "${var.name_prefix}-central-monitoring-sink"

  tags = var.tags
}

resource "aws_oam_sink_policy" "central_monitoring" {
  count = length(var.trusted_account_ids) > 0 ? 1 : 0

  sink_identifier = aws_oam_sink.central_monitoring[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.trusted_account_ids : account_id
          ]
        }
        Action   = ["oam:CreateLink", "oam:UpdateLink"]
        Resource = "*"
        Condition = {
          "ForAllValues:StringEquals" = {
            "oam:ResourceTypes" = [
              "AWS::CloudWatch::Metric",
              "AWS::Logs::LogGroup"
            ]
          }
        }
      }
    ]
  })
}
