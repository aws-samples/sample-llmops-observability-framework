# Development Environment Configuration
environment  = "dev"
project_name = "llmops"
aws_region   = "us-east-1"

# Bedrock Configuration
model_ids = [
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "anthropic.claude-3-5-haiku-20241022-v1:0"
]

enable_model_invocation_logging = true

# Monitoring Configuration
log_retention_days = 30
dashboard_name     = "LLMOps-Bedrock"

# Guardrail Configuration
guardrail_config_path          = "config/guardrails.yaml"
contextual_grounding_enabled   = false
contextual_grounding_threshold = 0.75

# Grafana Configuration
enable_grafana           = false
grafana_create_workspace = true
# grafana_authentication_providers = ["AWS_SSO"]  # Requires IAM Identity Center enabled
# grafana_authentication_providers = ["SAML"]     # Use if SSO is not enabled
# grafana_existing_workspace_id = "g-XXXXXXXXXX"  # Uncomment if using existing workspace
# grafana_create_workspace      = false            # Set to false if using existing workspace

# Lambda Configuration
lambda_timeout        = 300
lambda_runtime        = "python3.11"
log_analysis_schedule = "rate(1 hour)"

# Alarm Configuration
enable_alarms         = true
alarm_email_endpoints = [] # Add email addresses: ["[email]"]
# alarm_sns_topic_arn   = ""  # Uncomment to use an existing SNS topic
error_rate_threshold      = 20 # More lenient for dev
throttle_rate_threshold   = 10
latency_threshold_ms      = 10000
guardrail_block_threshold = 50

# Cross-Account Configuration
enable_cross_account = false
# trusted_account_ids   = ["123456789012", "987654321098"]  # Accounts that can read this account's data
# remote_account_configs = []  # Remote accounts sending logs to this account

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "DevOps"
  Application = "LLMOps"
}
