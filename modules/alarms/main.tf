data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────
# SNS Topic for Alarm Notifications
# ─────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alarm_notifications" {
  count = var.enable_alarms && var.alarm_sns_topic_arn == "" ? 1 : 0

  name = "${var.name_prefix}-bedrock-alarms"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_alarms && var.alarm_sns_topic_arn == "" ? length(var.alarm_email_endpoints) : 0

  topic_arn = aws_sns_topic.alarm_notifications[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

locals {
  sns_topic_arn = var.enable_alarms ? (
    var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : (
      length(aws_sns_topic.alarm_notifications) > 0 ? aws_sns_topic.alarm_notifications[0].arn : ""
    )
  ) : ""
}

# ─────────────────────────────────────────────────────────────
# Bedrock Invocation Error Alarm
# Fires when total client + server errors exceed threshold
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "bedrock_invocation_errors" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-bedrock-invocation-errors"
  alarm_description   = "Bedrock invocation errors exceeded ${var.error_rate_threshold} in 5 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = var.error_rate_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "total_errors"
    expression  = "client_errors + server_errors"
    label       = "Total Errors"
    return_data = true
  }

  metric_query {
    id = "client_errors"
    metric {
      metric_name = "InvocationClientErrors"
      namespace   = "AWS/Bedrock"
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "server_errors"
    metric {
      metric_name = "InvocationServerErrors"
      namespace   = "AWS/Bedrock"
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# Bedrock Throttling Alarm
# Fires when throttled requests exceed threshold
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "bedrock_throttles" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-bedrock-throttles"
  alarm_description   = "Bedrock throttled requests exceeded ${var.throttle_rate_threshold} in 5 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = var.throttle_rate_threshold
  metric_name         = "InvocationThrottles"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# Bedrock High Latency Alarm (per model)
# Fires when p99 latency exceeds threshold for any monitored model
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "bedrock_high_latency" {
  count = var.enable_alarms ? length(var.model_ids) : 0

  alarm_name          = "${var.name_prefix}-high-latency-${replace(var.model_ids[count.index], "/[^a-zA-Z0-9-]/", "-")}"
  alarm_description   = "Bedrock p99 latency for ${var.model_ids[count.index]} exceeded ${var.latency_threshold_ms}ms"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = var.latency_threshold_ms
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 300
  extended_statistic  = "p99"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ModelId = var.model_ids[count.index]
  }

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# Guardrail Intervention Alarm
# Uses a metric filter on the log group to count guardrail blocks
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_metric_filter" "guardrail_interventions" {
  count = var.enable_alarms ? 1 : 0

  name           = "${var.name_prefix}-guardrail-interventions"
  log_group_name = var.log_group_name
  pattern        = "{ $.output.outputBodyJson.stopReason = \"guardrail_intervened\" }"

  metric_transformation {
    name          = "GuardrailInterventions"
    namespace     = "LLMOps/Alarms"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "guardrail_interventions" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-guardrail-interventions"
  alarm_description   = "Guardrail interventions exceeded ${var.guardrail_block_threshold} in 5 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = var.guardrail_block_threshold
  metric_name         = "GuardrailInterventions"
  namespace           = "LLMOps/Alarms"
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# Lambda Log Analyzer Error Alarm
# Fires when the log analysis Lambda itself fails
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-log-analyzer-errors"
  alarm_description   = "Log analyzer Lambda errors exceeded ${var.lambda_error_threshold} in 5 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.lambda_error_threshold
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_name
  }

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# Log Volume Drop Alarm
# Fires when incoming log bytes drops to zero (logging may be broken)
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "log_volume_drop" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-log-volume-drop"
  alarm_description   = "Bedrock invocation log volume dropped to zero — logging may be broken"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  threshold           = var.log_volume_anomaly_threshold
  metric_name         = "IncomingBytes"
  namespace           = "AWS/Logs"
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "breaching"

  dimensions = {
    LogGroupName = var.log_group_name
  }

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────
# AI Severity Score Alarm
# Fires when the AI-powered log analysis reports high severity
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ai_severity_score" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-ai-severity-high"
  alarm_description   = "AI log analysis severity score is HIGH (>=7) — review log analysis results"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 7
  metric_name         = "AISeverityScore"
  namespace           = "LLMOps/LogAnalysis"
  period              = 3600
  statistic           = "Maximum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Environment = var.environment
  }

  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  tags = var.tags
}
