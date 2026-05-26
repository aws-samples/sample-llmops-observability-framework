# Deployment Guide

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Appropriate IAM permissions to create:
   - IAM roles and policies
   - CloudWatch resources
   - S3 buckets
   - Bedrock guardrails
   - Lambda functions
   - Secrets Manager secrets

## Environment Setup

### 1. Configure Variables

Edit the appropriate environment file in `environments/`:

- `dev.tfvars` - Development environment
- `test.tfvars` - Test environment  
- `prod.tfvars` - Production environment

Key variables to customize:
```hcl
environment  = "dev"           # Environment name
project_name = "llmops"        # Project identifier
aws_region   = "us-east-1"     # AWS region

model_ids = [                  # Bedrock models to monitor
  "anthropic.claude-3-5-sonnet-20241022-v2:0"
]

log_retention_days = 7         # CloudWatch log retention

# Alarm configuration
enable_alarms         = true
alarm_email_endpoints = ["[email protected]"]
error_rate_threshold  = 10     # Errors per 5-min period
latency_threshold_ms  = 5000   # p99 latency threshold

# Cross-account (optional)
enable_cross_account  = false
# trusted_account_ids = ["123456789012"]
```

### 2. Customize Guardrails

Edit `config/guardrails.yaml` to configure:

- Content filters (hate, violence, sexual, misconduct)
- Topic restrictions
- PII detection rules
- Custom word filters
- Regex patterns

### 3. Initialize Terraform

```bash
terraform init
```

This downloads required providers and initializes the backend.

## Deployment Steps

### Development Environment

```bash
# Review changes
terraform plan -var-file=environments/dev.tfvars

# Apply changes
terraform apply -var-file=environments/dev.tfvars

# Save outputs
terraform output > outputs-dev.txt
```

### Test Environment

```bash
terraform plan -var-file=environments/test.tfvars
terraform apply -var-file=environments/test.tfvars
terraform output > outputs-test.txt
```

### Production Environment

```bash
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
terraform output > outputs-prod.txt
```

## Post-Deployment

### 1. Verify Guardrails

Check AWS Secrets Manager for guardrail configuration:
```bash
aws secretsmanager get-secret-value \
  --secret-id llmops-guardrail-config-dev \
  --query SecretString \
  --output text | jq
```

### 2. Test Python Wrapper

```python
import os
os.environ['ENV'] = 'dev'

from guardrail_bedrock_wrapper import guardrail_converse

response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}]
)
print(response)
```

### 3. Access Dashboards

Get dashboard URLs from Terraform outputs:
```bash
terraform output core_dashboard_url
terraform output identity_dashboard_url
terraform output log_analysis_dashboard_url

# Alarm outputs
terraform output alarm_sns_topic_arn
terraform output alarm_arns

# Cross-account outputs (if enabled)
terraform output cross_account_role_arn
terraform output cross_account_external_id

# If Grafana is enabled
terraform output grafana_workspace_endpoint
```

### 4. Verify Logging

Check CloudWatch Logs:
```bash
aws logs tail /aws/bedrock/model-invocations-dev --follow
```

## Updating Existing Deployment

### Update Guardrail Configuration

1. Edit `config/guardrails.yaml`
2. Run terraform apply:
```bash
terraform apply -var-file=environments/dev.tfvars
```

### Add New Models

1. Edit `environments/{env}.tfvars`
2. Add model ID to `model_ids` list
3. Apply changes:
```bash
terraform apply -var-file=environments/dev.tfvars
```

**What happens automatically when you add a model:**
- IAM policies update to allow `bedrock:InvokeModel` for the new model
- CloudWatch dashboards add metric widgets for the new model (invocations, latency)
- CloudWatch alarms add a per-model high latency (p99) alarm
- Log Analysis dashboard adds per-model panels
- Grafana dashboards (if enabled) add corresponding panels
- No manual dashboard editing required — all driven by the `model_ids` list

### Enable or Configure Grafana

1. Set `enable_grafana = true` in `environments/{env}.tfvars`
2. Choose authentication provider (`SAML` or `AWS_SSO` — SSO requires IAM Identity Center)
3. To use an existing workspace, set `grafana_create_workspace = false` and provide `grafana_existing_workspace_id`
4. Apply changes:
```bash
terraform apply -var-file=environments/dev.tfvars
```
5. Access Grafana:
```bash
terraform output grafana_workspace_endpoint
```

### Update Lambda Code

The log analysis Lambda source is at `modules/log-analysis/lambda/index.py`. To update:

1. Edit the Lambda source code
2. Apply changes — Terraform automatically packages and deploys:
```bash
terraform apply -var-file=environments/dev.tfvars
```

## Rollback

### Rollback to Previous State

```bash
# List state versions
terraform state list

# Rollback
terraform apply -var-file=environments/dev.tfvars \
  -state=terraform.tfstate.backup
```

### Destroy Resources

```bash
# Destroy specific environment
terraform destroy -var-file=environments/dev.tfvars

# Confirm destruction
# Type 'yes' when prompted
```

## Troubleshooting

### Issue: Guardrail Not Found

**Solution**: Verify secret exists in Secrets Manager
```bash
aws secretsmanager list-secrets | grep guardrail
```

### Issue: Lambda Timeout

**Solution**: Increase timeout in variables
```hcl
lambda_timeout = 600  # Increase to 10 minutes
```

### Issue: Insufficient Permissions

**Solution**: Check IAM role policies
```bash
aws iam get-role-policy \
  --role-name llmops-dev-log-analyzer-role \
  --policy-name llmops-dev-log-analyzer-policy
```

### Issue: Dashboard Not Showing Data

**Solution**: 
1. Verify logging is enabled
2. Check log group has data
3. Wait 5-10 minutes for metrics

## Multi-Region Deployment

To deploy in multiple regions:

1. Create region-specific tfvars:
```hcl
# environments/dev-us-west-2.tfvars
environment = "dev"
aws_region  = "us-west-2"
```

2. Deploy:
```bash
terraform apply -var-file=environments/dev-us-west-2.tfvars
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy LLMOps

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan -var-file=environments/dev.tfvars
      
      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file=environments/dev.tfvars
```

## Security Best Practices

1. **Use Remote State**: Store Terraform state in S3 with encryption
2. **Enable State Locking**: Use DynamoDB for state locking
3. **Rotate Secrets**: Regularly rotate guardrail configurations
4. **Review IAM Policies**: Audit permissions quarterly
5. **Enable CloudTrail**: Track all API calls
6. **Use VPC Endpoints**: For private Bedrock access

## Monitoring Deployment

### Check Resource Creation

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.guardrails.aws_bedrock_guardrail.content_filter
```

### Verify Costs

```bash
# Use AWS Cost Explorer or
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json
```

## Support

For deployment issues:
1. Check CloudWatch Logs
2. Review Terraform state
3. Verify AWS service quotas
4. Contact platform team
