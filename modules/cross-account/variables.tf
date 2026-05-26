variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cross_account_role_name" {
  description = "Name of the cross-account monitoring role"
  type        = string
}

variable "trusted_account_ids" {
  description = "List of AWS account IDs allowed to assume the cross-account role"
  type        = list(string)
  default     = []
}

variable "log_group_name" {
  description = "CloudWatch log group name for Bedrock invocations"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Bedrock logs"
  type        = string
}

variable "guardrail_secret_arn" {
  description = "ARN of the Secrets Manager secret containing guardrail config"
  type        = string
}

variable "remote_account_configs" {
  description = "List of remote account configurations for cross-account log aggregation"
  type = list(object({
    account_id   = string
    region       = string
    log_group    = string
    display_name = string
  }))
  default = []
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
