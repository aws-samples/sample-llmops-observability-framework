# Guardrail Outputs
output "guardrail_id" {
  description = "The ID of the Bedrock guardrail"
  value       = module.guardrails.guardrail_id
}

output "guardrail_arn" {
  description = "The ARN of the Bedrock guardrail"
  value       = module.guardrails.guardrail_arn
}

output "guardrail_secret_name" {
  description = "The name of the secret containing guardrail details"
  value       = module.guardrails.guardrail_secret_name
}

# Monitoring Outputs
output "log_group_name" {
  description = "CloudWatch log group name for Bedrock invocations"
  value       = module.logging.log_group_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for Bedrock logs"
  value       = module.logging.s3_bucket_name
}

# Dashboard Outputs
output "core_dashboard_url" {
  description = "URL to the core monitoring dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.dashboards.core_dashboard_name}"
}

output "identity_dashboard_url" {
  description = "URL to the identity tracking dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.dashboards.identity_dashboard_name}"
}

output "log_analysis_dashboard_url" {
  description = "URL to the log analysis dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.log_analysis.dashboard_name}"
}

# Lambda Outputs
output "log_analyzer_lambda_arn" {
  description = "ARN of the log analyzer Lambda function"
  value       = module.log_analysis.lambda_arn
}

output "log_analyzer_lambda_name" {
  description = "Name of the log analyzer Lambda function"
  value       = module.log_analysis.lambda_name
}

# IAM Outputs
output "llmops_role_arn" {
  description = "ARN of the LLMOps monitoring role"
  value       = module.iam.llmops_role_arn
}

output "llmops_role_name" {
  description = "Name of the LLMOps monitoring role"
  value       = module.iam.llmops_role_name
}

# Grafana Outputs (conditional)
output "grafana_workspace_id" {
  description = "ID of the Grafana workspace"
  value       = var.enable_grafana ? module.grafana[0].workspace_id : null
}

output "grafana_workspace_endpoint" {
  description = "Endpoint URL of the Grafana workspace"
  value       = var.enable_grafana ? "https://${module.grafana[0].workspace_endpoint}" : null
}

output "grafana_workspace_arn" {
  description = "ARN of the Grafana workspace"
  value       = var.enable_grafana ? module.grafana[0].workspace_arn : null
}

# Alarm Outputs
output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = module.alarms.sns_topic_arn
}

output "alarm_arns" {
  description = "Map of alarm names to their ARNs"
  value       = module.alarms.alarm_arns
}

# Cross-Account Outputs (conditional)
output "cross_account_role_arn" {
  description = "ARN of the cross-account monitoring role"
  value       = var.enable_cross_account ? module.cross_account[0].cross_account_role_arn : null
}

output "cross_account_external_id" {
  description = "External ID required when assuming the cross-account role"
  value       = var.enable_cross_account ? module.cross_account[0].cross_account_external_id : null
}

output "oam_sink_arn" {
  description = "ARN of the CloudWatch Observability Access Manager sink"
  value       = var.enable_cross_account ? module.cross_account[0].oam_sink_arn : null
}
