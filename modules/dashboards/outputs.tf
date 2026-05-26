output "core_dashboard_name" {
  description = "Name of the core monitoring dashboard"
  value       = aws_cloudwatch_dashboard.bedrock_core_dashboard.dashboard_name
}

output "identity_dashboard_name" {
  description = "Name of the identity tracking dashboard"
  value       = aws_cloudwatch_dashboard.bedrock_identity_tracking.dashboard_name
}
