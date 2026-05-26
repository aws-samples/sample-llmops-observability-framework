# Local values for resource naming and configuration
locals {
  # Naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Resource names
  log_group_name        = "/aws/bedrock/model-invocations-${var.environment}"
  s3_bucket_name        = "${var.project_name}-bedrock-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
  guardrail_name        = "${var.project_name}-content-filter-${var.environment}"
  guardrail_secret_name = "${var.project_name}-guardrail-config-${var.environment}"

  # IAM role names
  llmops_role_name          = "${local.name_prefix}-monitor-role"
  log_analyzer_role_name    = "${local.name_prefix}-log-analyzer-role"
  bedrock_logging_role_name = "${local.name_prefix}-bedrock-logging-role"

  # Lambda names
  log_analyzer_lambda_name = "${local.name_prefix}-log-analyzer"

  # Dashboard names
  core_dashboard_name         = "${var.dashboard_name}-Core-${var.environment}"
  identity_dashboard_name     = "${var.dashboard_name}-Identity-${var.environment}"
  log_analysis_dashboard_name = "${var.dashboard_name}-LogAnalysis-${var.environment}"

  # Grafana names
  grafana_workspace_name = "${local.name_prefix}-grafana"

  # Cross-account names
  cross_account_role_name = "${local.name_prefix}-${var.cross_account_role_name}"

  # Load guardrail configuration from YAML
  guardrail_config = yamldecode(fileexists(var.guardrail_config_path) ? file(var.guardrail_config_path) : "{}")

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Component   = "LLMOps"
    }
  )
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
