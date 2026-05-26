output "cross_account_role_arn" {
  description = "ARN of the cross-account monitoring role"
  value       = length(aws_iam_role.cross_account_monitor) > 0 ? aws_iam_role.cross_account_monitor[0].arn : ""
}

output "cross_account_role_name" {
  description = "Name of the cross-account monitoring role"
  value       = length(aws_iam_role.cross_account_monitor) > 0 ? aws_iam_role.cross_account_monitor[0].name : ""
}

output "cross_account_external_id" {
  description = "External ID required when assuming the cross-account role"
  value       = "${var.name_prefix}-cross-account"
}

output "log_destination_arn" {
  description = "ARN of the CloudWatch log destination for cross-account log aggregation"
  value       = length(aws_cloudwatch_log_destination.cross_account_logs) > 0 ? aws_cloudwatch_log_destination.cross_account_logs[0].arn : ""
}

output "oam_sink_arn" {
  description = "ARN of the CloudWatch Observability Access Manager sink"
  value       = length(aws_oam_sink.central_monitoring) > 0 ? aws_oam_sink.central_monitoring[0].arn : ""
}

output "oam_sink_id" {
  description = "ID of the CloudWatch Observability Access Manager sink"
  value       = length(aws_oam_sink.central_monitoring) > 0 ? aws_oam_sink.central_monitoring[0].id : ""
}
