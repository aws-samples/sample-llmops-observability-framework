variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# Workspace configuration
variable "create_workspace" {
  description = "Whether to create a new Grafana workspace or use an existing one"
  type        = bool
  default     = true
}

variable "existing_workspace_id" {
  description = "ID of an existing Grafana workspace (required if create_workspace = false)"
  type        = string
  default     = ""
}

variable "workspace_name" {
  description = "Name for the Grafana workspace"
  type        = string
}

variable "workspace_description" {
  description = "Description for the Grafana workspace"
  type        = string
  default     = "LLMOps Observability Grafana Workspace"
}

variable "account_access_type" {
  description = "Account access type for Grafana workspace (CURRENT_ACCOUNT or ORGANIZATION)"
  type        = string
  default     = "CURRENT_ACCOUNT"

  validation {
    condition     = contains(["CURRENT_ACCOUNT", "ORGANIZATION"], var.account_access_type)
    error_message = "account_access_type must be CURRENT_ACCOUNT or ORGANIZATION."
  }
}

variable "authentication_providers" {
  description = "Authentication providers for Grafana workspace (AWS_SSO requires IAM Identity Center enabled)"
  type        = list(string)
  default     = ["SAML"]

  validation {
    condition     = alltrue([for p in var.authentication_providers : contains(["AWS_SSO", "SAML"], p)])
    error_message = "authentication_providers must be AWS_SSO, SAML, or both."
  }
}

variable "permission_type" {
  description = "Permission type for Grafana workspace (SERVICE_MANAGED or CUSTOMER_MANAGED)"
  type        = string
  default     = "SERVICE_MANAGED"

  validation {
    condition     = contains(["SERVICE_MANAGED", "CUSTOMER_MANAGED"], var.permission_type)
    error_message = "permission_type must be SERVICE_MANAGED or CUSTOMER_MANAGED."
  }
}

variable "grafana_version" {
  description = "Grafana version for the workspace"
  type        = string
  default     = "10.4"
}

variable "data_sources" {
  description = "Data sources to enable in the Grafana workspace"
  type        = list(string)
  default     = ["CLOUDWATCH", "XRAY"]
}

variable "notification_destinations" {
  description = "Notification destinations for the Grafana workspace"
  type        = list(string)
  default     = ["SNS"]
}

# Dashboard configuration
variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for Bedrock invocations"
  type        = string
}

variable "model_ids" {
  description = "List of Bedrock model IDs to monitor"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region for CloudWatch data source"
  type        = string
}

variable "slow_request_threshold_ms" {
  description = "Threshold in milliseconds for slow request detection"
  type        = number
  default     = 2000
}

# IAM configuration
variable "create_iam_role" {
  description = "Whether to create an IAM role for the Grafana workspace"
  type        = bool
  default     = true
}

variable "existing_iam_role_arn" {
  description = "ARN of an existing IAM role for Grafana (required if create_iam_role = false)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
