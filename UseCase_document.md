# UseCase Document: LLMOps Observability Platform

## 1. What the Code Does

### 1.1 Infrastructure Provisioning (Terraform)

The Terraform code provisions a complete observability and security enforcement platform for Amazon Bedrock LLM applications across 8 modules:

| Module | What It Does |
|--------|-------------|
| **IAM** | Creates 3 IAM roles: LLMOps monitoring role (Bedrock invoke + CloudWatch), Log analyzer Lambda role (log reading + Bedrock invoke + metrics), Bedrock logging role (CloudWatch + S3 write) |
| **Logging** | Creates a CloudWatch Log Group for Bedrock model invocation logs, an S3 bucket (versioned, encrypted, public-access-blocked) for log storage, and configures Bedrock model invocation logging to both destinations |
| **Guardrails** | Creates an Amazon Bedrock Guardrail with content filtering, topic restrictions, PII anonymization, word blocking, and optional contextual grounding. Stores guardrail ID/version/ARN in Secrets Manager |
| **Dashboards** | Creates 2 CloudWatch dashboards: Core (invocations, errors, latency, tokens, throttles, guardrail blocks, slow requests) and Identity (API calls by IAM role/user session) |
| **Log Analysis** | Deploys a Lambda function triggered by EventBridge on a schedule, a CloudWatch anomaly detector for error patterns, and a third dashboard for log analysis metrics. The Lambda uses Bedrock Claude to analyze invocation logs and publish metrics (errors, latency, token usage, AI severity score) to CloudWatch |
| **Alarms** | Creates CloudWatch alarms with SNS notifications for: Bedrock invocation errors, throttling, per-model high latency (p99), guardrail intervention spikes, Lambda analyzer failures, log volume drops, and AI severity score thresholds. Supports existing SNS topics or creates a new one with email subscriptions |
| **Cross-Account** (optional) | Enables multi-account monitoring via cross-account IAM roles, CloudWatch log destinations for centralized log aggregation, and CloudWatch Observability Access Manager (OAM) sinks for cross-account metric/log sharing. Controlled by `enable_cross_account` variable |
| **Grafana** (optional) | Creates an Amazon Managed Grafana workspace (or uses existing) with 3 dashboards mirroring CloudWatch: Core Monitoring, Identity Tracking, Log Analysis. Includes IAM role with CloudWatch/Logs read permissions. Controlled by `enable_grafana` variable |

### 1.2 Python Wrapper (guardrail_bedrock_wrapper.py)

A security enforcement layer that intercepts all Bedrock API calls and injects guardrail configuration:

- Fetches guardrail config (ID, version) from Secrets Manager and caches it
- Wraps `invoke_model()` and `converse()` APIs with guardrail injection
- Logs guardrail interventions with detailed trace info (content policy violations, confidence, filter strength)
- Provides `prevent_bypass()` to monkey-patch boto3 and warn on direct bedrock-runtime client creation
- Fails safely (raises ValueError) if guardrails are enabled but config is missing

### 1.3 Guardrail Configuration (config/guardrails.yaml)

YAML-driven security policies applied to all Bedrock calls:

- **Content Filtering**: HATE (HIGH), VIOLENCE (HIGH), SEXUAL (HIGH), MISCONDUCT (MEDIUM), PROMPT_ATTACK (configurable)
- **Topic Restrictions**: Denies financial advice, legal advice, medical advice, personal information requests, illegal activities
- **PII Anonymization**: 19 entity types (EMAIL, PHONE, CREDIT_CARD, SSN, AWS_KEYS, etc.) + custom regex patterns (EmployeeID, ProjectCode)
- **Word Blocking**: Managed profanity list + custom words (confidential, proprietary, classified, etc.)

### 1.4 Multi-Environment Support

Three environment configs (dev/test/prod) with different:
- Log retention (dev: 30 days, test: 14 days, prod: 90 days)
- Model lists (prod includes Claude Sonnet 4)
- Analysis frequency (dev/test: hourly, prod: every 30 min)
- Contextual grounding (disabled in dev/test, enabled in prod at 0.80 threshold)
- Alarm thresholds (lenient in dev, strict in prod)
- Tags (different Owner per environment)

### 1.5 Configuration Flow — Model IDs

The `model_ids` list in `environments/*.tfvars` propagates automatically to:
1. **IAM** — scopes `bedrock:InvokeModel` permissions to listed models
2. **CloudWatch Dashboards** — generates per-model metric widgets (invocations, latency)
3. **Alarms** — creates per-model high latency alarms
4. **Log Analysis** — per-model dashboard panels + Lambda invoke permissions
5. **Grafana** (if enabled) — per-model panel targets mirroring CloudWatch

Adding or removing a model and running `terraform apply` updates all dashboards, alarms, and IAM policies automatically. No manual editing required.

---

## 2. Customization Guide

### 2.1 Required Before Deployment

| Item | File | What to Change | Impact |
|------|------|----------------|--------|
| **Terraform backend** | `main.tf` | Add S3 backend block for remote state | Enables team collaboration and state safety |
| **Model IDs** | `environments/*.tfvars` | Set `model_ids` to your Bedrock-enabled models | Scopes IAM permissions and populates all dashboards and alarms |
| **AWS Region** | `environments/*.tfvars` | Set `aws_region` to your target region | All resources deploy to this region |
| **Project name** | `environments/*.tfvars` | Set `project_name` to your project identifier | Affects all resource naming |
| **Tags** | `environments/*.tfvars` | Set `CostCenter`, `Owner`, `Application` | Resource tagging for cost allocation and ownership |

### 2.2 Recommended Customizations

| Item | File | What to Change | Impact |
|------|------|----------------|--------|
| **Alarm email endpoints** | `environments/*.tfvars` | Set `alarm_email_endpoints` to your team's email addresses | Enables alarm notifications via SNS |
| **Alarm thresholds** | `environments/*.tfvars` | Tune `error_rate_threshold`, `throttle_rate_threshold`, `latency_threshold_ms`, `guardrail_block_threshold` | Controls alarm sensitivity per environment |
| **Existing SNS topic** | `environments/*.tfvars` | Set `alarm_sns_topic_arn` to use an existing topic | Integrates with existing notification pipelines (PagerDuty, Slack, etc.) |
| **Content filter strengths** | `config/guardrails.yaml` | Adjust input_strength/output_strength per filter type | Controls how aggressively content is filtered |
| **Topic restrictions** | `config/guardrails.yaml` | Add/remove/modify denied topics and examples | Domain-specific content restrictions |
| **PII entity list** | `config/guardrails.yaml` | Add/remove PII types based on compliance needs | Country-specific PII detection (e.g., Aadhaar, NI number) |
| **Custom regex patterns** | `config/guardrails.yaml` | Update patterns for your organization's data formats | Catches org-specific sensitive data |
| **Custom blocked words** | `config/guardrails.yaml` | Update word list for your organization | Blocks org-specific sensitive terms |
| **Log retention** | `environments/*.tfvars` | Adjust `log_retention_days` per compliance | Cost vs compliance trade-off |
| **Lambda schedule** | `environments/*.tfvars` | Adjust `log_analysis_schedule` | Analysis frequency vs cost |
| **Contextual grounding** | `environments/*.tfvars` | Tune threshold (0.0–1.0) | Controls hallucination detection sensitivity |
| **Slow request threshold** | `modules/dashboards/main.tf` | Change the >2000ms threshold | Aligns with your SLA requirements |
| **Grafana enablement** | `environments/*.tfvars` | Set `enable_grafana = true` | Adds Grafana dashboards alongside CloudWatch |
| **Analysis model** | `environments/*.tfvars` | Set `analysis_model_id` / `fallback_model_id` | Controls which Bedrock model the Lambda uses for log analysis |
| **Guardrail version** | `modules/guardrails/main.tf` | Publish and reference a specific version | Use published version instead of DRAFT for production |
| **Cross-account monitoring** | `environments/*.tfvars` | Set `enable_cross_account = true` and configure `trusted_account_ids` | Enables centralized multi-account monitoring |

---

## 3. Use Cases

### UC-01: Enforce Security Guardrails on All LLM Calls
- All Bedrock API calls (invoke_model, converse) are intercepted by the Python wrapper
- Guardrail config (ID, version) is injected into every request
- Content filtering, topic restrictions, PII anonymization, and word blocking are applied
- Blocked responses return `stopReason: guardrail_intervened` with trace details

### UC-02: Prevent Guardrail Bypass
- `prevent_bypass()` monkey-patches boto3.client to log warnings on direct bedrock-runtime usage
- Wrapper raises ValueError if guardrails are enabled but Secrets Manager config is missing
- Decorator pattern (`@require_guardrails`) ensures guardrails are active before function execution

### UC-03: Monitor Bedrock Model Usage
- CloudWatch dashboards show invocations per model, error rates, latency (avg + p99), token usage, and throttling
- Log Insights queries surface recent guardrail blocks and slow requests
- All metrics are per-environment and per-model (driven by `model_ids`)

### UC-04: Track User Identity for Audit
- Identity dashboard parses IAM assumed-role ARNs from Bedrock logs
- Shows all API calls by role name and user session
- Aggregates call counts by role for usage analysis

### UC-05: AI-Powered Log Analysis
- Lambda function (scheduled via EventBridge) reads Bedrock invocation logs
- Uses Bedrock Claude to analyze patterns, anomalies, and issues
- Prioritizes error and throttle logs, truncates large messages to stay within model limits
- Falls back to a smaller model if input exceeds token limits
- Publishes metrics (invocations, errors, tokens, latency, AI severity score) to CloudWatch
- Results stored in the Lambda's CloudWatch log group
- Anomaly detector flags unusual error patterns every 15 minutes

### UC-06: PII Detection and Anonymization
- 19 PII entity types automatically anonymized in both input and output
- Custom regex patterns catch organization-specific sensitive data
- All anonymization happens at the Bedrock guardrail level before response reaches the application

### UC-07: Multi-Environment Deployment
- Same Terraform code deploys to dev, test, and prod with different configurations
- Environment-specific log retention, model lists, analysis frequency, alarm thresholds, and security strictness
- Resource naming includes environment suffix for isolation

### UC-08: Centralized Guardrail Configuration Management
- Guardrail policies defined in a single YAML file (config/guardrails.yaml)
- Terraform reads YAML and provisions Bedrock guardrail resource
- Guardrail details stored in Secrets Manager for runtime access by the Python wrapper
- Changes to YAML are applied via `terraform apply`

### UC-09: Comprehensive Logging and Storage
- Bedrock model invocation logs sent to both CloudWatch and S3
- S3 bucket is versioned, encrypted (AES256), and public-access-blocked
- CloudWatch log retention is configurable per environment
- Supports text, image, embedding, and video data delivery

### UC-10: Application Integration
- Python wrapper provides drop-in replacement for direct boto3 Bedrock calls
- Supports Flask, Lambda, and async integration patterns
- Environment-aware (reads ENV, AWS_REGION, GUARDRAIL_ENABLED from environment variables)
- Comprehensive error handling with specific ClientError code handling

### UC-11: Grafana Dashboard Integration
- Optional Amazon Managed Grafana dashboards alongside CloudWatch dashboards (controlled by `enable_grafana`)
- Supports two modes: create a new Grafana workspace OR use an existing one
- Three Grafana dashboards mirror CloudWatch: Core Monitoring, Identity Tracking, Log Analysis
- IAM role creation is optional — can use an existing role
- All settings fully parameterized: workspace version, auth providers, permission type, data sources, slow request threshold
- CloudWatch dashboards are always retained regardless of Grafana enablement

### UC-12: CloudWatch Alarms and Notifications
- Seven alarm types covering the full Bedrock operational surface:
  - **Invocation Errors**: Fires when combined client + server errors exceed threshold (math expression alarm)
  - **Throttling**: Fires when throttled requests exceed threshold
  - **High Latency (per model)**: Fires when p99 latency exceeds threshold for any monitored model — one alarm per model, auto-generated from `model_ids`
  - **Guardrail Interventions**: Uses a CloudWatch metric filter on the Bedrock log group to count `guardrail_intervened` stop reasons, fires when count exceeds threshold
  - **Lambda Analyzer Errors**: Fires when the log analysis Lambda itself fails
  - **Log Volume Drop**: Fires when incoming log bytes drops to zero for 3 consecutive periods (logging may be broken) — uses `treat_missing_data = breaching`
  - **AI Severity Score**: Fires when the AI-powered log analysis reports severity >= 7 (HIGH)
- SNS notification support: creates a new topic with email subscriptions, or uses an existing SNS topic ARN
- All thresholds are configurable per environment (lenient in dev, strict in prod)
- Alarms can be disabled entirely via `enable_alarms = false`

### UC-13: Multi-Account Centralized Monitoring
- Enables a central AWS account to monitor Bedrock usage across multiple accounts
- Three cross-account mechanisms:
  - **Cross-Account IAM Role**: Trusted accounts can assume a role in the central account to read CloudWatch metrics, logs, S3 log data, guardrail config, and Bedrock guardrail details. Protected by an external ID condition
  - **CloudWatch Log Destinations**: Remote accounts can send their Bedrock invocation logs to the central account's CloudWatch log group via subscription filters
  - **CloudWatch Observability Access Manager (OAM)**: Creates an OAM sink that allows trusted accounts to link their CloudWatch metrics and log groups for native cross-account observability in the CloudWatch console
- Configuration:
  - `enable_cross_account = true` activates the module
  - `trusted_account_ids` lists accounts that can assume the monitoring role and link to the OAM sink
  - `remote_account_configs` lists accounts that will send logs to this central account
- All cross-account resources are environment-scoped and tagged consistently
- Remote accounts need to create corresponding OAM links and subscription filters on their side

---

## 4. Production Readiness Checklist

- [ ] Configure S3 backend for Terraform remote state
- [ ] Verify model IDs match your Bedrock account access
- [ ] Review and tune guardrail policy strengths
- [ ] Set appropriate log retention per compliance requirements
- [ ] Configure alarm email endpoints or SNS topic ARN
- [ ] Tune alarm thresholds per environment (error rate, latency, throttle, guardrail blocks)
- [ ] Enable Grafana if needed (`enable_grafana = true`)
- [ ] Configure cross-account monitoring if multi-account (`enable_cross_account = true`)
- [ ] Provide trusted account IDs for cross-account access
- [ ] Review IAM policy scoping for least-privilege
- [ ] Add S3 lifecycle policies for log expiration
- [ ] Publish guardrail version (replace DRAFT for production)
- [ ] Add Lambda dead-letter queue for failed invocations
- [ ] Conduct security review of IAM policies and guardrail config
- [ ] Verify OAM links are created in remote accounts (if multi-account)
