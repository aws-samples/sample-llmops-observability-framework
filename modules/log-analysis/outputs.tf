output "lambda_arn" {
  description = "ARN of the log analyzer Lambda function"
  value       = aws_lambda_function.log_analyzer.arn
}

output "lambda_name" {
  description = "Name of the log analyzer Lambda function"
  value       = aws_lambda_function.log_analyzer.function_name
}

output "dashboard_name" {
  description = "Name of the log analysis dashboard"
  value       = aws_cloudwatch_dashboard.log_analysis_dashboard.dashboard_name
}

output "schedule_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.log_analysis_schedule.name
}
