terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  environment               = var.environment
  name_prefix               = local.name_prefix
  llmops_role_name          = local.llmops_role_name
  log_analyzer_role_name    = local.log_analyzer_role_name
  bedrock_logging_role_name = local.bedrock_logging_role_name
  model_ids                 = var.model_ids
  log_group_name            = local.log_group_name
  s3_bucket_arn             = "arn:aws:s3:::${local.s3_bucket_name}"

  tags = local.common_tags
}

# Logging Module
module "logging" {
  source = "./modules/logging"

  environment                     = var.environment
  name_prefix                     = local.name_prefix
  log_group_name                  = local.log_group_name
  s3_bucket_name                  = local.s3_bucket_name
  log_retention_days              = var.log_retention_days
  enable_model_invocation_logging = var.enable_model_invocation_logging
  bedrock_logging_role_arn        = module.iam.bedrock_logging_role_arn

  tags = local.common_tags
}

# Guardrails Module
module "guardrails" {
  source = "./modules/guardrails"

  environment                    = var.environment
  name_prefix                    = local.name_prefix
  guardrail_name                 = local.guardrail_name
  guardrail_secret_name          = local.guardrail_secret_name
  guardrail_config               = local.guardrail_config
  contextual_grounding_enabled   = var.contextual_grounding_enabled
  contextual_grounding_threshold = var.contextual_grounding_threshold

  tags = local.common_tags
}

# Dashboards Module
module "dashboards" {
  source = "./modules/dashboards"

  environment             = var.environment
  name_prefix             = local.name_prefix
  core_dashboard_name     = local.core_dashboard_name
  identity_dashboard_name = local.identity_dashboard_name
  log_group_name          = local.log_group_name
  model_ids               = var.model_ids

  tags = local.common_tags

  depends_on = [module.logging]
}

# Log Analysis Module
module "log_analysis" {
  source = "./modules/log-analysis"

  environment         = var.environment
  name_prefix         = local.name_prefix
  lambda_name         = local.log_analyzer_lambda_name
  dashboard_name      = local.log_analysis_dashboard_name
  log_group_name      = local.log_group_name
  lambda_role_arn     = module.iam.log_analyzer_role_arn
  lambda_timeout      = var.lambda_timeout
  lambda_runtime      = var.lambda_runtime
  log_retention_days  = var.log_retention_days
  schedule_expression = var.log_analysis_schedule
  model_ids           = var.model_ids
  analysis_model_id   = var.analysis_model_id
  fallback_model_id   = var.fallback_model_id

  tags = local.common_tags

  depends_on = [module.iam, module.logging]
}

# Grafana Module (optional)
module "grafana" {
  source = "./modules/grafana"
  count  = var.enable_grafana ? 1 : 0

  environment               = var.environment
  name_prefix               = local.name_prefix
  create_workspace          = var.grafana_create_workspace
  existing_workspace_id     = var.grafana_existing_workspace_id
  workspace_name            = local.grafana_workspace_name
  account_access_type       = var.grafana_account_access_type
  authentication_providers  = var.grafana_authentication_providers
  permission_type           = var.grafana_permission_type
  grafana_version           = var.grafana_version
  data_sources              = var.grafana_data_sources
  create_iam_role           = var.grafana_create_iam_role
  existing_iam_role_arn     = var.grafana_existing_iam_role_arn
  cloudwatch_log_group_name = local.log_group_name
  model_ids                 = var.model_ids
  aws_region                = var.aws_region
  slow_request_threshold_ms = var.grafana_slow_request_threshold_ms

  tags = local.common_tags

  depends_on = [module.logging, module.dashboards]
}

# Alarms Module
module "alarms" {
  source = "./modules/alarms"

  environment               = var.environment
  name_prefix               = local.name_prefix
  log_group_name            = local.log_group_name
  lambda_name               = local.log_analyzer_lambda_name
  model_ids                 = var.model_ids
  enable_alarms             = var.enable_alarms
  alarm_email_endpoints     = var.alarm_email_endpoints
  alarm_sns_topic_arn       = var.alarm_sns_topic_arn
  error_rate_threshold      = var.error_rate_threshold
  throttle_rate_threshold   = var.throttle_rate_threshold
  latency_threshold_ms      = var.latency_threshold_ms
  guardrail_block_threshold = var.guardrail_block_threshold
  lambda_error_threshold    = var.lambda_error_threshold

  tags = local.common_tags

  depends_on = [module.logging, module.log_analysis]
}

# Cross-Account Module (optional)
module "cross_account" {
  source = "./modules/cross-account"
  count  = var.enable_cross_account ? 1 : 0

  environment             = var.environment
  name_prefix             = local.name_prefix
  cross_account_role_name = local.cross_account_role_name
  trusted_account_ids     = var.trusted_account_ids
  log_group_name          = local.log_group_name
  s3_bucket_arn           = module.logging.s3_bucket_arn
  guardrail_secret_arn    = module.guardrails.guardrail_secret_arn
  remote_account_configs  = var.remote_account_configs

  tags = local.common_tags

  depends_on = [module.logging, module.guardrails]
}
