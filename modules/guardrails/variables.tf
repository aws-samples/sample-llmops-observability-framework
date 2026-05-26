variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "guardrail_name" {
  description = "Name for the guardrail"
  type        = string
}

variable "guardrail_secret_name" {
  description = "Name for the guardrail secret"
  type        = string
}

variable "guardrail_config" {
  description = "Guardrail configuration from YAML"
  type        = any
  default     = {}
}

variable "contextual_grounding_enabled" {
  description = "Enable contextual grounding"
  type        = bool
  default     = false
}

variable "contextual_grounding_threshold" {
  description = "Threshold for contextual grounding"
  type        = number
  default     = 0.75
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
