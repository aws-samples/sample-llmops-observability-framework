variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "llmops_role_name" {
  description = "Name for LLMOps monitoring role"
  type        = string
}

variable "log_analyzer_role_name" {
  description = "Name for log analyzer Lambda role"
  type        = string
}

variable "bedrock_logging_role_name" {
  description = "Name for Bedrock logging role"
  type        = string
}

variable "model_ids" {
  description = "List of Bedrock model IDs"
  type        = list(string)
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Bedrock logs"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
