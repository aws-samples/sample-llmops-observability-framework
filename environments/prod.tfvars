# Production Environment Configuration
environment  = "prod"
project_name = "llmops"
aws_region   = "us-east-1"

# Bedrock Configuration
model_ids = [
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "anthropic.claude-3-5-haiku-20241022-v1:0",
  "anthropic.claude-sonnet-4-20250514-v1:0"
]

enable_model_invocation_logging = true

# Monitoring Configuration
log_retention_days = 90
dashboard_name     = "LLMOps-Bedrock"

# Guardrail Configuration
guardrail_config_path          = "config/guardrails.yaml"
contextual_grounding_enabled   = true
contextual_grounding_threshold = 0.80

# Grafana Configuration
enable_grafana           = true
grafana_create_workspace = true
# grafana_authentication_providers = ["AWS_SSO"]  # Requires IAM Identity Center enabled
# grafana_authentication_providers = ["SAML"]     # Use if SSO is not enabled
# grafana_existing_workspace_id = "g-XXXXXXXXXX"  # Uncomment if using existing workspace
# grafana_create_workspace      = false            # Set to false if using existing workspace

# Lambda Configuration
lambda_timeout        = 300
lambda_runtime        = "python3.11"
log_analysis_schedule = "rate(30 minutes)"

# Alarm Configuration
enable_alarms         = true
alarm_email_endpoints = [] # Add email addresses: ["[email]"]
# alarm_sns_topic_arn   = ""  # Uncomment to use an existing SNS topic
error_rate_threshold      = 5
throttle_rate_threshold   = 3
latency_threshold_ms      = 5000
guardrail_block_threshold = 20
lambda_error_threshold    = 1

# Cross-Account Configuration
enable_cross_account = false
# trusted_account_ids   = ["123456789012", "987654321098"]
# remote_account_configs = [
#   {
#     account_id   = "123456789012"
#     region       = "us-east-1"
#     log_group    = "/aws/bedrock/model-invocations-prod"
#     display_name = "Team-A Production"
#   }
# ]

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "Platform"
  Application = "LLMOps"
  Compliance  = "Required"
}
