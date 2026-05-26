# Core Variables
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "llmops"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Bedrock Configuration
variable "model_ids" {
  description = "List of Bedrock model IDs to monitor"
  type        = list(string)
  default = [
    "anthropic.claude-3-5-sonnet-20241022-v2:0",
    "anthropic.claude-3-5-haiku-20241022-v1:0"
  ]
}

variable "enable_model_invocation_logging" {
  description = "Enable Bedrock model invocation logging"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "dashboard_name" {
  description = "Base name for CloudWatch dashboards"
  type        = string
  default     = "LLMOps-Bedrock"
}

# Guardrail Configuration
variable "guardrail_config_path" {
  description = "Path to guardrail YAML configuration"
  type        = string
  default     = "config/guardrails.yaml"
}

variable "contextual_grounding_enabled" {
  description = "Enable contextual grounding in guardrails"
  type        = bool
  default     = false
}

variable "contextual_grounding_threshold" {
  description = "Threshold for contextual grounding (0.0-1.0)"
  type        = number
  default     = 0.75
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "log_analysis_schedule" {
  description = "EventBridge schedule expression for log analysis"
  type        = string
  default     = "rate(1 hour)"
}

variable "analysis_model_id" {
  description = "Bedrock model ID used by the log analysis Lambda"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "fallback_model_id" {
  description = "Fallback Bedrock model ID if primary exceeds input limits"
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

# Grafana Configuration
variable "enable_grafana" {
  description = "Enable Amazon Managed Grafana dashboards alongside CloudWatch dashboards"
  type        = bool
  default     = false
}

variable "grafana_create_workspace" {
  description = "Create a new Grafana workspace (false = use existing workspace)"
  type        = bool
  default     = true
}

variable "grafana_existing_workspace_id" {
  description = "ID of an existing Grafana workspace (required if grafana_create_workspace = false)"
  type        = string
  default     = ""
}

variable "grafana_account_access_type" {
  description = "Account access type for Grafana workspace (CURRENT_ACCOUNT or ORGANIZATION)"
  type        = string
  default     = "CURRENT_ACCOUNT"
}

variable "grafana_authentication_providers" {
  description = "Authentication providers for Grafana workspace (AWS_SSO requires IAM Identity Center enabled)"
  type        = list(string)
  default     = ["SAML"]
}

variable "grafana_permission_type" {
  description = "Permission type for Grafana workspace (SERVICE_MANAGED or CUSTOMER_MANAGED)"
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "grafana_version" {
  description = "Grafana version for the workspace"
  type        = string
  default     = "10.4"
}

variable "grafana_data_sources" {
  description = "Data sources to enable in the Grafana workspace"
  type        = list(string)
  default     = ["CLOUDWATCH", "XRAY"]
}

variable "grafana_create_iam_role" {
  description = "Create a new IAM role for Grafana (false = use existing role)"
  type        = bool
  default     = true
}

variable "grafana_existing_iam_role_arn" {
  description = "ARN of an existing IAM role for Grafana (required if grafana_create_iam_role = false)"
  type        = string
  default     = ""
}

variable "grafana_slow_request_threshold_ms" {
  description = "Threshold in milliseconds for slow request detection in Grafana dashboards"
  type        = number
  default     = 2000
}

# Alarm Configuration
variable "enable_alarms" {
  description = "Enable CloudWatch alarms for Bedrock monitoring"
  type        = bool
  default     = true
}

variable "alarm_email_endpoints" {
  description = "List of email addresses to receive alarm notifications via SNS"
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arn" {
  description = "ARN of an existing SNS topic for alarm notifications (if empty, a new topic is created)"
  type        = string
  default     = ""
}

variable "error_rate_threshold" {
  description = "Threshold for Bedrock invocation error count alarm (per 5-min period)"
  type        = number
  default     = 10
}

variable "throttle_rate_threshold" {
  description = "Threshold for Bedrock throttle count alarm (per 5-min period)"
  type        = number
  default     = 5
}

variable "latency_threshold_ms" {
  description = "Threshold in milliseconds for high latency alarm (p99)"
  type        = number
  default     = 5000
}

variable "guardrail_block_threshold" {
  description = "Threshold for guardrail intervention count alarm (per 5-min period)"
  type        = number
  default     = 20
}

variable "lambda_error_threshold" {
  description = "Threshold for Lambda function error count alarm (per 5-min period)"
  type        = number
  default     = 1
}

# Multi-Account Configuration
variable "enable_cross_account" {
  description = "Enable cross-account access for centralized monitoring"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of AWS account IDs allowed to assume the cross-account monitoring role"
  type        = list(string)
  default     = []
}

variable "cross_account_role_name" {
  description = "Name of the IAM role that remote accounts can assume for monitoring access"
  type        = string
  default     = "LLMOps-CrossAccount-Monitor"
}

variable "remote_account_configs" {
  description = "List of remote account configurations for multi-account log aggregation"
  type = list(object({
    account_id   = string
    region       = string
    log_group    = string
    display_name = string
  }))
  default = []
}

# Tagging
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
