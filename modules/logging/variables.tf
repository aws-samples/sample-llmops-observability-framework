variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for logs"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
}

variable "enable_model_invocation_logging" {
  description = "Enable Bedrock model invocation logging"
  type        = bool
}

variable "bedrock_logging_role_arn" {
  description = "ARN of the Bedrock logging role"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
