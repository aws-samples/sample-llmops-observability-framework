data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────
# IAM Role for Amazon Managed Grafana
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "grafana" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name_prefix}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name_prefix}-grafana-cloudwatch-policy"
  role = aws_iam_role.grafana[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.cloudwatch_log_group_name}:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# Amazon Managed Grafana Workspace
# ─────────────────────────────────────────────────────────────
resource "aws_grafana_workspace" "this" {
  count = var.create_workspace ? 1 : 0

  name                      = var.workspace_name
  description               = var.workspace_description
  account_access_type       = var.account_access_type
  authentication_providers  = var.authentication_providers
  permission_type           = var.permission_type
  grafana_version           = var.grafana_version
  role_arn                  = var.create_iam_role ? aws_iam_role.grafana[0].arn : var.existing_iam_role_arn
  data_sources              = var.data_sources
  notification_destinations = var.notification_destinations

  tags = var.tags
}

# Look up existing workspace when not creating
data "aws_grafana_workspace" "existing" {
  count        = var.create_workspace ? 0 : 1
  workspace_id = var.existing_workspace_id
}

locals {
  workspace_id       = var.create_workspace ? aws_grafana_workspace.this[0].id : var.existing_workspace_id
  workspace_endpoint = var.create_workspace ? aws_grafana_workspace.this[0].endpoint : data.aws_grafana_workspace.existing[0].endpoint
}
