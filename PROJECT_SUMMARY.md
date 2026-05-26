# LLMOps Observability Platform — Framework Overview

## Overview

A modular, config-driven observability and security enforcement framework for Amazon Bedrock LLM applications. The platform provides centralized guardrail enforcement, comprehensive monitoring, identity tracking, and AI-powered log analysis across multiple environments.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     LLMOps Platform                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐       ┌───────────────────────┐               │
│  │   Python     │       │   Terraform Modules   │               │
│  │   Wrapper    │───────│   (8 modules)         │               │
│  └──────┬───────┘       └───────────┬───────────┘               │
│         │                           │                            │
│         ▼                           ▼                            │
│  ┌──────────────────────────────────────────┐                   │
│  │         Amazon Bedrock Runtime            │                   │
│  │  ┌────────────────────────────────────┐  │                   │
│  │  │   Guardrails (YAML-configured)     │  │                   │
│  │  └────────────────────────────────────┘  │                   │
│  └──────────────┬───────────────────────────┘                   │
│                 │                                                │
│        ┌────────┴────────┐                                      │
│        ▼                 ▼                                       │
│  ┌───────────┐    ┌────────────┐                                │
│  │CloudWatch │    │ S3 Bucket  │                                │
│  │  Logs     │    │  (Logs)    │                                │
│  └─────┬─────┘    └────────────┘                                │
│        │                                                        │
│   ┌────┴──────────────────────────────────┐                     │
│   │     Monitoring & Alerting             │                     │
│   │  ┌─────────────┐  ┌───────────────┐  │                     │
│   │  │ CloudWatch  │  │ Grafana       │  │                     │
│   │  │ Dashboards  │  │ (optional)    │  │                     │
│   │  └─────────────┘  └───────────────┘  │                     │
│   │  ┌─────────────┐  ┌───────────────┐  │                     │
│   │  │ CloudWatch  │  │ Cross-Account │  │                     │
│   │  │ Alarms+SNS  │  │ OAM (opt.)   │  │                     │
│   │  └─────────────┘  └───────────────┘  │                     │
│   └───────────────────────────────────────┘                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| **iam** | IAM roles and policies for Bedrock access, Lambda execution, and logging |
| **logging** | CloudWatch log groups and encrypted S3 bucket for Bedrock invocation logs |
| **guardrails** | Bedrock guardrails with YAML-driven content, topic, PII, and word policies |
| **dashboards** | CloudWatch dashboards for core metrics and identity tracking |
| **log-analysis** | AI-powered log analysis Lambda with EventBridge scheduling and anomaly detection |
| **alarms** | CloudWatch alarms with SNS notifications for errors, throttling, latency, guardrail blocks, Lambda failures, log volume drops, and AI severity |
| **cross-account** | Optional cross-account IAM roles, CloudWatch log destinations, and OAM sinks for multi-account monitoring |
| **grafana** | Optional Amazon Managed Grafana workspace with dashboards mirroring CloudWatch |

## Key Capabilities

### Security Enforcement
- Content filtering (hate, violence, sexual, misconduct, prompt attack)
- Topic restrictions (financial, legal, medical advice)
- PII detection and anonymization (19+ entity types + custom regex)
- Custom word blocking with managed profanity lists
- Contextual grounding (optional, configurable threshold)
- Bypass prevention via Python wrapper enforcement

### Monitoring and Observability
- CloudWatch dashboards: core metrics, identity tracking, log analysis
- CloudWatch alarms with SNS notifications: invocation errors, throttling, per-model high latency (p99), guardrail intervention spikes, Lambda analyzer failures, log volume drops, AI severity score
- Optional Grafana dashboards mirroring CloudWatch
- Per-model invocation, error, latency, and token usage metrics
- Guardrail intervention tracking with trace details
- Slow request detection with configurable thresholds
- CloudWatch anomaly detection for error patterns

### Multi-Account Support
- Cross-account IAM role for trusted accounts to read metrics, logs, S3 data, and guardrail config
- CloudWatch log destinations for centralized log aggregation from remote accounts
- CloudWatch Observability Access Manager (OAM) sinks for native cross-account observability
- All cross-account resources are environment-scoped and protected by external ID

### Multi-Environment Support
- Three environments: dev, test, prod
- Environment-specific log retention, model lists, analysis frequency
- Graduated security strictness (contextual grounding enabled in prod)
- Isolated resource naming per environment

### Python Wrapper
- Drop-in replacement for direct boto3 Bedrock calls
- Supports `invoke_model()` and `converse()` APIs
- Environment-aware configuration via environment variables
- Guardrail config caching from Secrets Manager
- Integration patterns: Flask, Lambda, async

## Configuration Flow

### Model IDs
`model_ids` in `environments/*.tfvars` propagates automatically to:
1. **IAM** — scopes `bedrock:InvokeModel` permissions to listed models
2. **CloudWatch Dashboards** — generates per-model metric widgets
3. **Alarms** — creates per-model high latency alarms
4. **Log Analysis** — per-model panels + Lambda invoke permissions
5. **Grafana** (if enabled) — per-model panel targets

Adding or removing a model and running `terraform apply` updates all dashboards, alarms, and IAM policies automatically.

### Guardrail Policies
`config/guardrails.yaml` → Terraform `yamldecode()` → Bedrock Guardrail resource → Secrets Manager → Python wrapper reads at runtime

### Environment Settings
`environments/*.tfvars` → `variables.tf` → `locals.tf` (naming) → all modules

## File Structure

```
├── main.tf                          # Root module orchestration
├── variables.tf                     # Input variables
├── locals.tf                        # Naming conventions and config loading
├── outputs.tf                       # Output values
├── config/
│   └── guardrails.yaml             # Guardrail policy configuration
├── environments/
│   ├── dev.tfvars                  # Development settings
│   ├── test.tfvars                 # Test settings
│   └── prod.tfvars                 # Production settings
├── modules/
│   ├── iam/                        # IAM roles and policies
│   ├── logging/                    # CloudWatch + S3 logging
│   ├── guardrails/                 # Bedrock guardrails + Secrets Manager
│   ├── dashboards/                 # CloudWatch dashboards
│   ├── log-analysis/               # Lambda + EventBridge + anomaly detection
│   ├── alarms/                     # CloudWatch alarms + SNS notifications
│   ├── cross-account/              # Cross-account IAM, log destinations, OAM (optional)
│   └── grafana/                    # Grafana workspace + dashboards (optional)
├── examples/
│   ├── basic_usage.py              # 6 usage examples
│   └── enforce_wrapper_usage.py    # 5 enforcement strategies
├── guardrail_bedrock_wrapper.py    # Python security wrapper
├── README.md                       # Project documentation
├── DEPLOYMENT.md                   # Deployment guide
└── PYTHON_WRAPPER_GUIDE.md         # Wrapper usage guide
```

## Deployment

```bash
# Initialize
terraform init

# Deploy per environment
terraform apply -var-file=environments/dev.tfvars
terraform apply -var-file=environments/test.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## Customization Guide

| What to Customize | Where | Impact |
|-------------------|-------|--------|
| Bedrock models | `environments/*.tfvars` → `model_ids` | IAM, dashboards, alarms, Grafana, log analysis |
| Guardrail policies | `config/guardrails.yaml` | Content filtering, topic restrictions, PII rules |
| Log retention | `environments/*.tfvars` → `log_retention_days` | CloudWatch and Lambda log groups |
| Analysis frequency | `environments/*.tfvars` → `log_analysis_schedule` | EventBridge Lambda trigger |
| Analysis model | `environments/*.tfvars` → `analysis_model_id` | Bedrock model used by log analysis Lambda |
| Alarm thresholds | `environments/*.tfvars` → `error_rate_threshold`, `latency_threshold_ms`, etc. | CloudWatch alarm sensitivity |
| Alarm notifications | `environments/*.tfvars` → `alarm_email_endpoints` or `alarm_sns_topic_arn` | SNS email subscriptions or existing topic |
| Cross-account | `environments/*.tfvars` → `enable_cross_account`, `trusted_account_ids` | Multi-account monitoring |
| Grafana enablement | `environments/*.tfvars` → `enable_grafana` | Grafana workspace + dashboards |
| Slow request threshold | `modules/dashboards/main.tf` / Grafana variables | Dashboard alert thresholds |
| Project naming | `environments/*.tfvars` → `project_name` | All resource names |
| AWS region | `environments/*.tfvars` → `aws_region` | All resources |
| Tags | `environments/*.tfvars` → `tags` | All resources |

## Production Readiness Checklist

- [ ] Configure S3 backend for Terraform remote state
- [ ] Verify model IDs match your Bedrock account access
- [ ] Review and tune guardrail policy strengths
- [ ] Set appropriate log retention per compliance requirements
- [ ] Configure alarm email endpoints or existing SNS topic ARN
- [ ] Tune alarm thresholds per environment (error rate, latency, throttle, guardrail blocks)
- [ ] Enable Grafana if needed (`enable_grafana = true`)
- [ ] Configure authentication provider for Grafana (SAML or AWS_SSO)
- [ ] Enable cross-account monitoring if multi-account (`enable_cross_account = true`)
- [ ] Provide trusted account IDs and configure remote account log aggregation
- [ ] Create OAM links in remote accounts pointing to central OAM sink
- [ ] Review IAM policy scoping for least-privilege (including cross-account role)
- [ ] Add S3 lifecycle policies for log expiration
- [ ] Publish guardrail version (replace DRAFT for production)
- [ ] Add Lambda dead-letter queue for failed invocations
- [ ] Conduct security review of IAM policies and guardrail config

## Support and Maintenance

| Task | How |
|------|-----|
| Update guardrails | Edit `config/guardrails.yaml` → `terraform apply` |
| Add/remove models | Edit `model_ids` in tfvars → `terraform apply` |
| Change environment settings | Edit `environments/*.tfvars` → `terraform apply` |
| Tune alarm thresholds | Edit threshold variables in tfvars → `terraform apply` |
| Change alarm recipients | Edit `alarm_email_endpoints` or `alarm_sns_topic_arn` in tfvars → `terraform apply` |
| Add trusted accounts | Edit `trusted_account_ids` in tfvars → `terraform apply` |
| View logs | `aws logs tail /aws/bedrock/model-invocations-{env} --follow` |
| Check alarm state | `aws cloudwatch describe-alarms --alarm-name-prefix llmops-{env}` |
| Check guardrail config | `aws secretsmanager get-secret-value --secret-id llmops-guardrail-config-{env}` |
| Access dashboards | `terraform output core_dashboard_url` / `terraform output grafana_workspace_endpoint` |

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
