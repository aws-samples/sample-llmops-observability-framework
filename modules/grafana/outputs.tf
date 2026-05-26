output "workspace_id" {
  description = "ID of the Grafana workspace"
  value       = local.workspace_id
}

output "workspace_endpoint" {
  description = "Endpoint URL of the Grafana workspace"
  value       = local.workspace_endpoint
}

output "workspace_arn" {
  description = "ARN of the Grafana workspace"
  value       = var.create_workspace ? aws_grafana_workspace.this[0].arn : data.aws_grafana_workspace.existing[0].arn
}

output "grafana_role_arn" {
  description = "ARN of the Grafana IAM role"
  value       = var.create_iam_role ? aws_iam_role.grafana[0].arn : var.existing_iam_role_arn
}

output "core_dashboard_json" {
  description = "JSON definition of the core monitoring Grafana dashboard"
  value       = local.core_dashboard_json
}

output "identity_dashboard_json" {
  description = "JSON definition of the identity tracking Grafana dashboard"
  value       = local.identity_dashboard_json
}

output "log_analysis_dashboard_json" {
  description = "JSON definition of the log analysis Grafana dashboard"
  value       = local.log_analysis_dashboard_json
}
