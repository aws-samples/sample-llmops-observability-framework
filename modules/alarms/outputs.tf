output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = var.enable_alarms && var.alarm_sns_topic_arn == "" && length(aws_sns_topic.alarm_notifications) > 0 ? aws_sns_topic.alarm_notifications[0].arn : var.alarm_sns_topic_arn
}

output "alarm_arns" {
  description = "Map of alarm names to their ARNs"
  value = var.enable_alarms ? {
    bedrock_errors    = aws_cloudwatch_metric_alarm.bedrock_invocation_errors[0].arn
    bedrock_throttles = aws_cloudwatch_metric_alarm.bedrock_throttles[0].arn
    guardrail_blocks  = aws_cloudwatch_metric_alarm.guardrail_interventions[0].arn
    lambda_errors     = aws_cloudwatch_metric_alarm.lambda_errors[0].arn
    log_volume_drop   = aws_cloudwatch_metric_alarm.log_volume_drop[0].arn
    ai_severity       = aws_cloudwatch_metric_alarm.ai_severity_score[0].arn
  } : {}
}

output "per_model_latency_alarm_arns" {
  description = "List of per-model high latency alarm ARNs"
  value       = var.enable_alarms ? aws_cloudwatch_metric_alarm.bedrock_high_latency[*].arn : []
}
