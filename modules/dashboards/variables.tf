variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "core_dashboard_name" {
  description = "Name for core dashboard"
  type        = string
}

variable "identity_dashboard_name" {
  description = "Name for identity dashboard"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "model_ids" {
  description = "List of Bedrock model IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
