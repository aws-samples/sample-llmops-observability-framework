variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for Bedrock invocations"
  type        = string
}

variable "lambda_name" {
  description = "Name of the log analyzer Lambda function"
  type        = string
}

variable "model_ids" {
  description = "List of Bedrock model IDs to monitor"
  type        = list(string)
}

# Alarm thresholds
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

variable "log_volume_anomaly_threshold" {
  description = "Threshold for incoming log bytes anomaly (bytes per 5-min period)"
  type        = number
  default     = 0
}

# SNS Configuration
variable "alarm_email_endpoints" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arn" {
  description = "ARN of an existing SNS topic for alarm notifications (if empty, a new topic is created)"
  type        = string
  default     = ""
}

variable "enable_alarms" {
  description = "Enable or disable all CloudWatch alarms"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
