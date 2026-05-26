# Security Policy

## Reporting a Vulnerability

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our
[vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public
GitHub issue.

## Production Recommendations

This project is provided as sample code for educational purposes. Before using in production, consider the following hardening measures:

### Encryption

| Resource | Current | Recommended for Production |
|----------|---------|---------------------------|
| CloudWatch Log Groups | AWS-managed encryption | AWS KMS Customer Managed Key (CMK) |
| Lambda environment variables | AWS-managed encryption | AWS KMS CMK |
| Secrets Manager | AWS-managed encryption | AWS KMS CMK |
| S3 bucket | SSE-S3 (AES256) | SSE-KMS with CMK |

### Network

| Resource | Current | Recommended for Production |
|----------|---------|---------------------------|
| Lambda function | Not in VPC (only calls AWS APIs) | Deploy in VPC with VPC endpoints for AWS services if compliance requires it |

### Reliability

| Resource | Current | Recommended for Production |
|----------|---------|---------------------------|
| Lambda function | No Dead Letter Queue (failures are alarmed) | Add SQS DLQ for failed invocations |
| Lambda function | No concurrency limit | Set reserved concurrency to prevent runaway invocations |
| Lambda function | No code signing | Enable code signing for supply chain integrity |

### Observability

| Resource | Current | Recommended for Production |
|----------|---------|---------------------------|
| Lambda function | CloudWatch Logs only | Enable X-Ray tracing for distributed tracing |
| S3 bucket | No access logging | Enable S3 server access logging to a separate bucket |

### Data Lifecycle

| Resource | Current | Recommended for Production |
|----------|---------|---------------------------|
| S3 bucket | No lifecycle policy | Add lifecycle rules to transition to Glacier/expire old logs |
| S3 bucket | No cross-region replication | Enable CRR for disaster recovery if required |

## Known Security Considerations

The following items use AWS-managed encryption rather than customer-managed KMS keys. This is acceptable for sample code but should be evaluated for production deployments based on your compliance requirements:

1. **CloudWatch Log Groups** — Use AWS-managed encryption. For sensitive workloads, configure `kms_key_id` on the log group resource.
2. **Lambda environment variables** — Use AWS-managed encryption. For sensitive configuration, use Secrets Manager (already used for guardrail config) or configure a KMS key on the Lambda function.
3. **Secrets Manager secrets** — Use AWS-managed encryption. For regulated workloads, specify a CMK ARN on the secret resource.
4. **S3 bucket** — Uses SSE-S3 (AES256). For compliance requirements mandating key management, switch to SSE-KMS with a dedicated CMK.
5. **Lambda not in VPC** — The Lambda function only calls AWS APIs (CloudWatch Logs, Amazon Bedrock, CloudWatch Metrics). VPC deployment adds cold start latency and requires VPC endpoints. Acceptable for this use case unless compliance mandates VPC-only access.
6. **Lambda missing DLQ** — Failed Lambda invocations are detected by the CloudWatch alarm (`lambda_error_threshold`). For production, add an SQS DLQ to capture and retry failed events.
7. **S3 missing access logging** — Server access logging is not enabled. For audit requirements, enable logging to a separate S3 bucket.

## Dependency Management

- All Terraform providers use version constraints (`~> 5.0` for AWS provider)
- Python dependencies are limited to `boto3` (AWS SDK, managed by AWS Lambda runtime)
- No third-party packages with known vulnerabilities are used
