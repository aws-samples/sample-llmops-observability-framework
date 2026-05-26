# Test Environment Configuration
environment  = "test"
project_name = "llmops"
aws_region   = "us-east-1"

# Bedrock Configuration
model_ids = [
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "anthropic.claude-3-5-haiku-20241022-v1:0"
]

enable_model_invocation_logging = true

# Monitoring Configuration
log_retention_days = 14
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
error_rate_threshold      = 10
throttle_rate_threshold   = 5
latency_threshold_ms      = 7000
guardrail_block_threshold = 30

# Cross-Account Configuration
enable_cross_account = false
# trusted_account_ids   = ["123456789012"]
# remote_account_configs = []

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "QA"
  Application = "LLMOps"
}
