# LLMOps Observability Platform

> ⚠️ **Important**: This project is provided as sample code for educational purposes.
> It is NOT intended for production use without additional security hardening.
> See [SECURITY.md](SECURITY.md) for production recommendations.

A comprehensive, modular, and config-driven observability solution for Amazon Bedrock LLM applications with built-in security guardrails.

## Features

- **Guardrail Enforcement**: Centralized security controls for all Bedrock API calls
- **Multi-Environment Support**: Separate configurations for dev, test, and prod
- **Comprehensive Monitoring**: CloudWatch dashboards for performance, quality, and identity tracking
- **CloudWatch Alarms**: 7 alarm types with SNS notifications for errors, throttling, latency, guardrail blocks, Lambda failures, log volume drops, and AI severity
- **Multi-Account Monitoring**: Cross-account IAM roles, CloudWatch log destinations, and OAM sinks for centralized observability
- **Grafana Integration**: Optional Amazon Managed Grafana dashboards mirroring CloudWatch
- **Log Analysis**: AI-powered log analysis using Bedrock Claude
- **Config-Driven**: YAML-based guardrail configuration
- **Modular Architecture**: 8 reusable Terraform modules

## Architecture

```
.
├── main.tf                      # Root module orchestration
├── variables.tf                 # Input variables
├── locals.tf                    # Local values and data sources
├── outputs.tf                   # Output values
├── backend.tf.example           # Remote state backend example
├── requirements.txt             # Python dependencies
├── config/
│   └── guardrails.yaml         # Guardrail configuration
├── environments/
│   ├── dev.tfvars              # Development environment
│   ├── test.tfvars             # Test environment
│   └── prod.tfvars             # Production environment
├── examples/
│   ├── basic_usage.py          # Python wrapper usage examples
│   └── enforce_wrapper_usage.py # Guardrail enforcement patterns
├── tests/
│   └── test_guardrail_bedrock_wrapper.py  # Unit tests
├── modules/
│   ├── iam/                    # IAM roles and policies
│   ├── logging/                # CloudWatch and S3 logging
│   ├── guardrails/             # Bedrock guardrails
│   ├── dashboards/             # CloudWatch dashboards
│   ├── log-analysis/           # AI-powered log analysis
│   ├── alarms/                 # CloudWatch alarms + SNS notifications
│   ├── cross-account/          # Cross-account IAM, log destinations, OAM (optional)
│   └── grafana/                # Amazon Managed Grafana (optional)
└── guardrail_bedrock_wrapper.py # Python wrapper for Bedrock calls
```

## Quick Start

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- Python 3.11+ (for wrapper)
- boto3 library (`pip install -r requirements.txt`)

### Remote State (Recommended for Teams)

Copy `backend.tf.example` to `backend.tf` and configure your S3 bucket and DynamoDB table for state locking:
```bash
cp backend.tf.example backend.tf
# Edit backend.tf with your bucket/table names
```

### Deployment

1. **Initialize Terraform**
```bash
terraform init
```

2. **Deploy to Development**
```bash
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

3. **Deploy to Test**
```bash
terraform plan -var-file=environments/test.tfvars
terraform apply -var-file=environments/test.tfvars
```

4. **Deploy to Production**
```bash
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## Guardrail Configuration

Edit `config/guardrails.yaml` to customize:

- Content policy filters (hate, violence, sexual, misconduct)
- Topic restrictions (financial, legal, medical advice)
- PII detection and anonymization
- Custom word filters
- Regex patterns for sensitive data

Example:
```yaml
content_policy:
  filters:
    - type: "HATE"
      input_strength: "HIGH"
      output_strength: "HIGH"
```

## Python Wrapper Usage

The Python wrapper ensures ALL Bedrock calls go through guardrails:

```python
from guardrail_bedrock_wrapper import guardrail_invoke_model, guardrail_converse

# Instead of bedrock_client.invoke_model()
response = guardrail_invoke_model(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body={"prompt": "Hello, how are you?"}
)

# Instead of bedrock_client.converse()
response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}]
)
```

### Environment Variables

- `ENV`: Environment name (dev/test/prod)
- `AWS_REGION`: AWS region (default: us-east-1)
- `GUARDRAIL_ENABLED`: Enable/disable guardrails (default: true)

## Monitoring Dashboards

After deployment, access dashboards via AWS Console:

1. **Core Dashboard**: Model invocations, errors, latency, token usage, guardrail blocks, slow requests
2. **Identity Dashboard**: API calls by IAM role and user
3. **Log Analysis Dashboard**: AI-powered insights and anomaly detection

### CloudWatch Alarms

7 alarm types are created by default (controlled by `enable_alarms`):

| Alarm | What It Monitors |
|-------|-----------------|
| Invocation Errors | Client + server errors combined |
| Throttling | Throttled Bedrock requests |
| High Latency (per model) | p99 latency per model (one alarm per model from `model_ids`) |
| Guardrail Interventions | `guardrail_intervened` events via log metric filter |
| Lambda Analyzer Errors | Log analysis Lambda failures |
| Log Volume Drop | Incoming log bytes drops to zero (logging may be broken) |
| AI Severity Score | AI log analysis reports severity >= 7 |

Configure notifications:
```hcl
# Email notifications
alarm_email_endpoints = ["[email protected]"]

# Or use an existing SNS topic (PagerDuty, Slack, etc.)
alarm_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:my-existing-topic"
```

Tune thresholds per environment:
```hcl
error_rate_threshold      = 5     # prod: strict
throttle_rate_threshold   = 3
latency_threshold_ms      = 5000
guardrail_block_threshold = 20
```

### Multi-Account Monitoring

Enable centralized monitoring across multiple AWS accounts:

```hcl
enable_cross_account = true
trusted_account_ids  = ["123456789012", "987654321098"]
```

This creates:
- **Cross-account IAM role** for trusted accounts to read metrics, logs, and config
- **CloudWatch log destination** for remote accounts to push their Bedrock logs
- **OAM sink** for native cross-account observability in CloudWatch console

Remote accounts need to create OAM links and subscription filters pointing to the central account.

### Grafana Dashboards (Optional)

Enable Grafana dashboards by setting `enable_grafana = true` in your tfvars:

```hcl
# Enable Grafana with a new workspace
enable_grafana           = true
grafana_create_workspace = true

# Or use an existing workspace
enable_grafana                = true
grafana_create_workspace      = false
grafana_existing_workspace_id = "g-XXXXXXXXXX"
```

Grafana provides 3 dashboards mirroring CloudWatch: Core Monitoring, Identity Tracking, and Log Analysis. Access via:
```bash
terraform output grafana_workspace_endpoint
```

**Importing Dashboards:** The module outputs dashboard JSON definitions (`grafana_core_dashboard_json`, etc.) that you can import into your Grafana workspace via the Grafana UI (Dashboards > Import) or the Grafana HTTP API. See the Terraform outputs for the JSON payloads.

**Authentication Note:** The default auth provider is `SAML`. If you want to use `AWS_SSO`, you must first enable AWS IAM Identity Center in your account:
```hcl
grafana_authentication_providers = ["AWS_SSO"]   # Requires IAM Identity Center
grafana_authentication_providers = ["SAML"]      # Works without SSO setup
```

## Security Features

### Guardrail Enforcement

- Content filtering (hate, violence, sexual content)
- Topic restrictions (financial, legal, medical advice)
- PII detection and anonymization
- Custom word blocking
- Contextual grounding (optional)

### Access Control

- IAM role-based access
- Identity tracking in logs
- Secrets Manager for guardrail config
- S3 bucket encryption and access blocking

## Customization

### Adding New Models

Edit `environments/{env}.tfvars`:
```hcl
model_ids = [
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "anthropic.claude-3-5-haiku-20241022-v1:0",
  "your-new-model-id"
]
```

**How model IDs flow through the platform:**

1. `model_ids` is defined in `environments/*.tfvars` and passed to `variables.tf`
2. `main.tf` passes `model_ids` to 5 modules: IAM, Dashboards, Alarms, Log Analysis, and Grafana
3. **IAM module** — scopes `bedrock:InvokeModel` permissions to only the listed models
4. **Dashboards module** — dynamically generates CloudWatch metric widgets per model (invocations, latency)
5. **Alarms module** — creates per-model high latency (p99) alarms
6. **Log Analysis module** — scopes Lambda's Bedrock invoke permissions and generates per-model dashboard widgets
7. **Grafana module** (if enabled) — dynamically generates Grafana panel targets per model, mirroring CloudWatch

After adding a model, run `terraform apply` — all dashboards, alarms, and IAM policies update automatically. No manual editing needed.

### Adjusting Log Retention

```hcl
log_retention_days = 30  # dev: 30, test: 14, prod: 90
```

### Custom Tags

```hcl
tags = {
  CostCenter  = "Engineering"
  Owner       = "Platform"
  Application = "LLMOps"
}
```

## Outputs

After deployment, Terraform outputs:

- Guardrail ID and ARN
- Dashboard URLs
- Lambda function ARNs
- IAM role ARNs
- Log group names
- Alarm SNS topic ARN and alarm ARNs
- Cross-account role ARN and external ID (if enabled)
- Grafana workspace endpoint (if enabled)

## Troubleshooting

### Guardrails Not Working

1. Check Secrets Manager for guardrail config
2. Verify `GUARDRAIL_ENABLED=true`
3. Check CloudWatch logs for errors

### Lambda Failures

1. Check Lambda execution role permissions
2. Verify log group exists
3. Check Lambda timeout settings

### Dashboard Not Showing Data

1. Verify Bedrock logging is enabled
2. Check log group has data
3. Wait 5-10 minutes for metrics to populate

## Cost Optimization

- Adjust log retention based on compliance needs
- Use log analysis schedule wisely (hourly vs 30min)
- Monitor S3 storage costs for logs
- Consider lifecycle policies for old logs

## Compliance

- All PII is automatically anonymized
- Logs retained per environment policy
- Guardrails enforce content policies
- Identity tracking for audit trails

## Cleanup

To destroy all resources created by this project:

1. **Empty the S3 bucket first** (required before Terraform can delete it):
```bash
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive
```

2. **Destroy the infrastructure**:
```bash
terraform destroy -var-file=environments/dev.tfvars
```

3. **Confirm** by typing `yes` when prompted.

> **Note**: If you have cross-account OAM links or subscription filters pointing to this account, remove those in the remote accounts first to avoid orphaned resources.

## Testing

Run the unit tests for the Python wrapper:

```bash
pip install -r requirements.txt
python3 -m pytest tests/ -v
```

The tests use `unittest.mock` to mock AWS calls — no real AWS credentials needed.

## Contributing

1. Create feature branch
2. Update relevant modules
3. Run tests (`python3 -m pytest tests/ -v`)
4. Test in dev environment
5. Submit pull request

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.

## Support

For issues or questions:
- Open a [GitHub issue](../../issues)
- Review [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment guidance
- Check CloudWatch logs for runtime diagnostics
