variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_name" {
  description = "Name for Lambda function"
  type        = string
}

variable "dashboard_name" {
  description = "Name for dashboard"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of Lambda execution role"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
}

variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
}

variable "model_ids" {
  description = "List of Bedrock model IDs"
  type        = list(string)
}

variable "hours_back" {
  description = "Number of hours of logs to analyze per run"
  type        = number
  default     = 1
}

variable "analysis_model_id" {
  description = "Bedrock model ID used for log analysis"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "fallback_model_id" {
  description = "Fallback Bedrock model ID if primary exceeds input limits"
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "max_log_chars" {
  description = "Maximum characters of log content to send for analysis"
  type        = number
  default     = 50000
}

variable "max_tokens" {
  description = "Maximum tokens for Bedrock analysis response"
  type        = number
  default     = 2000
}

variable "metrics_namespace" {
  description = "CloudWatch metrics namespace for analysis results"
  type        = string
  default     = "LLMOps/LogAnalysis"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
