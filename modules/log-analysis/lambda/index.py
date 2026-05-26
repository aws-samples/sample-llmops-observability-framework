#!/usr/bin/env python3
"""
AI-Powered Log Analyzer using Amazon Bedrock
Analyzes CloudWatch logs using Claude to extract intelligent insights.

All configuration is driven by environment variables set via Terraform.
"""

import json
import logging
import os
import re
from datetime import datetime, timedelta
from typing import Any, Dict, List

import boto3

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class AILogAnalyzer:
    def __init__(self):
        """Initialize from environment variables (set by Terraform)."""
        self.region = os.environ.get("AWS_REGION", "us-east-1")
        self.environment = os.environ.get("ENVIRONMENT", "dev")
        self.log_group_name = os.environ.get("LOG_GROUP_NAME")
        self.hours_back = int(os.environ.get("HOURS_BACK", "1"))
        self.analysis_model_id = os.environ.get(
            "ANALYSIS_MODEL_ID", "anthropic.claude-3-5-sonnet-20241022-v2:0"
        )
        self.fallback_model_id = os.environ.get(
            "FALLBACK_MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0"
        )
        self.max_log_chars = int(os.environ.get("MAX_LOG_CHARS", "50000"))
        self.max_tokens = int(os.environ.get("MAX_TOKENS", "2000"))
        self.metrics_namespace = os.environ.get("METRICS_NAMESPACE", "LLMOps/LogAnalysis")

        self.logs_client = boto3.client("logs", region_name=self.region)
        self.bedrock_client = boto3.client("bedrock-runtime", region_name=self.region)
        self.cloudwatch_client = boto3.client("cloudwatch", region_name=self.region)

        logger.info(
            f"Initialized AILogAnalyzer: env={self.environment}, "
            f"region={self.region}, model={self.analysis_model_id}"
        )

    def fetch_logs(self, limit: int = 100) -> List[Dict]:
        """Fetch recent logs from CloudWatch."""
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=self.hours_back)

        try:
            logger.info(f"Fetching logs from {self.log_group_name}...")
            response = self.logs_client.filter_log_events(
                logGroupName=self.log_group_name,
                startTime=int(start_time.timestamp() * 1000),
                endTime=int(end_time.timestamp() * 1000),
                limit=limit,
            )
            events = response.get("events", [])
            logger.info(f"Found {len(events)} log events")
            return events
        except Exception as e:
            logger.error(f"Error fetching logs: {e}")
            return []

    def prepare_logs_for_analysis(self, logs: List[Dict]) -> str:
        """Format logs for Bedrock analysis with smart prioritization."""
        error_logs = []
        throttle_logs = []
        normal_logs = []

        for log in logs:
            message = log.get("message", "")
            error_terms = [
                "error", "exception", "failed",
                '"statuscode": 4', '"statuscode": 5',
            ]
            is_error = any(term in message.lower() for term in error_terms)
            is_throttle = "throttle" in message.lower()

            if is_error:
                error_logs.append(log)
            elif is_throttle:
                throttle_logs.append(log)
            else:
                normal_logs.append(log)

        prioritized_logs = error_logs[:20] + throttle_logs[:10] + normal_logs[:20]

        log_messages = []
        total_chars = 0

        for log in prioritized_logs:
            timestamp = datetime.fromtimestamp(log["timestamp"] / 1000).isoformat()
            message = log.get("message", "")

            if len(message) > 3000:
                try:
                    log_data = json.loads(message)
                    essential_keys = [
                        "modelId", "error", "errorMessage", "errorCode",
                        "statusCode", "latency", "inputTokens", "outputTokens",
                    ]
                    essential_fields = {
                        k: log_data[k] for k in essential_keys if k in log_data
                    }
                    message = json.dumps(essential_fields)
                except (json.JSONDecodeError, TypeError):
                    truncated = "\n... [middle truncated] ...\n"
                    message = message[:1500] + truncated + message[-1500:]

            log_entry = f"[{timestamp}] {message}"
            if total_chars + len(log_entry) > self.max_log_chars:
                logger.info(f"Reached character limit at {len(log_messages)} logs")
                break

            log_messages.append(log_entry)
            total_chars += len(log_entry)

        error_count = len(
            [l for l in prioritized_logs[: len(log_messages)] if l in error_logs]
        )
        throttle_count = len(
            [l for l in prioritized_logs[: len(log_messages)] if l in throttle_logs]
        )
        logger.info(
            f"Prepared {len(log_messages)} logs ({total_chars} chars): "
            f"{error_count} errors, {throttle_count} throttles"
        )
        return "\n".join(log_messages)

    def analyze_logs_with_bedrock(self, log_content: str) -> Dict[str, Any]:
        """Send logs to Bedrock for AI analysis."""
        prompt = (
            "Analyze these CloudWatch logs from an LLM application "
            "using Amazon Bedrock. Provide insights on:\n\n"
            "1. Error patterns and root causes\n"
            "2. Performance issues (latency, throttling)\n"
            "3. Usage patterns (models, token consumption)\n"
            "4. Security concerns or anomalies\n"
            "5. Recommendations for improvement\n\n"
            f"Logs:\n{log_content}\n\n"
            "Provide a structured JSON response with these keys:\n"
            "- error_summary: Brief summary of errors found\n"
            "- error_patterns: List of error patterns\n"
            "- performance_issues: List of performance concerns\n"
            "- usage_insights: Key usage statistics and trends\n"
            "- security_concerns: Any security issues detected\n"
            "- recommendations: List of actionable recommendations\n"
            "- severity: Overall severity (low/medium/high/critical)"
        )

        try:
            logger.info("Sending logs to Bedrock for AI analysis...")
            body = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": self.max_tokens,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3,
            })

            try:
                response = self.bedrock_client.invoke_model(
                    modelId=self.analysis_model_id, body=body
                )
            except Exception as e:
                if "too long" in str(e).lower():
                    logger.warning(
                        f"Input too long for {self.analysis_model_id}, "
                        f"trying {self.fallback_model_id}"
                    )
                    response = self.bedrock_client.invoke_model(
                        modelId=self.fallback_model_id, body=body
                    )
                else:
                    raise

            result = json.loads(response["body"].read())
            analysis_text = result["content"][0]["text"]

            try:
                start_idx = analysis_text.find("{")
                end_idx = analysis_text.rfind("}") + 1
                if start_idx != -1 and end_idx > start_idx:
                    analysis_json = json.loads(analysis_text[start_idx:end_idx])
                else:
                    analysis_json = {"raw_analysis": analysis_text}
            except (json.JSONDecodeError, TypeError):
                analysis_json = {"raw_analysis": analysis_text}

            logger.info("AI analysis completed")
            return analysis_json
        except Exception as e:
            logger.error(f"Error during Bedrock analysis: {e}")
            return {"error": str(e)}

    def extract_basic_metrics(self, logs: List[Dict]) -> Dict[str, Any]:
        """Extract basic metrics from logs without AI."""
        metrics = {
            "total_invocations": len(logs),
            "error_count": 0,
            "models_used": {},
            "avg_latency": 0,
            "token_usage": {"input": 0, "output": 0},
        }
        latencies = []

        for log in logs:
            message = log.get("message", "")

            try:
                log_data = json.loads(message)
                if (
                    ("error" in log_data and log_data["error"])
                    or ("statusCode" in log_data and log_data["statusCode"] >= 400)
                    or ("errorCode" in log_data)
                    or ("errorMessage" in log_data)
                ):
                    metrics["error_count"] += 1
            except (json.JSONDecodeError, KeyError, TypeError):
                if any(
                    term in message.lower()
                    for term in ["error:", "exception:", "failed:", "throttled"]
                ):
                    metrics["error_count"] += 1

            model_match = re.search(r'"modelId":\s*"([^"]+)"', message)
            if model_match:
                model = model_match.group(1)
                metrics["models_used"][model] = metrics["models_used"].get(model, 0) + 1

            latency_match = re.search(r'"latency":\s*(\d+)', message)
            if latency_match:
                latencies.append(int(latency_match.group(1)))

            input_tokens = re.search(r'"inputTokens":\s*(\d+)', message)
            if input_tokens:
                metrics["token_usage"]["input"] += int(input_tokens.group(1))

            output_tokens = re.search(r'"outputTokens":\s*(\d+)', message)
            if output_tokens:
                metrics["token_usage"]["output"] += int(output_tokens.group(1))

        if latencies:
            metrics["avg_latency"] = sum(latencies) / len(latencies)

        return metrics

    def send_metrics_to_cloudwatch(self, basic_metrics: Dict, ai_insights: Dict):
        """Send metrics to CloudWatch."""
        try:
            dimensions = [{"Name": "Environment", "Value": self.environment}]

            metric_data = [
                {
                    "MetricName": "TotalInvocations",
                    "Value": basic_metrics["total_invocations"],
                    "Unit": "Count",
                    "Dimensions": dimensions,
                },
                {
                    "MetricName": "ErrorCount",
                    "Value": basic_metrics["error_count"],
                    "Unit": "Count",
                    "Dimensions": dimensions,
                },
                {
                    "MetricName": "InputTokens",
                    "Value": basic_metrics["token_usage"]["input"],
                    "Unit": "Count",
                    "Dimensions": dimensions,
                },
                {
                    "MetricName": "OutputTokens",
                    "Value": basic_metrics["token_usage"]["output"],
                    "Unit": "Count",
                    "Dimensions": dimensions,
                },
            ]

            if basic_metrics["avg_latency"] > 0:
                metric_data.append({
                    "MetricName": "AverageLatency",
                    "Value": basic_metrics["avg_latency"],
                    "Unit": "Milliseconds",
                    "Dimensions": dimensions,
                })

            severity_map = {"low": 1, "medium": 2, "high": 3, "critical": 4}
            severity = ai_insights.get("severity", "low")
            metric_data.append({
                "MetricName": "AISeverityScore",
                "Value": severity_map.get(severity, 1),
                "Unit": "None",
                "Dimensions": dimensions,
            })

            self.cloudwatch_client.put_metric_data(
                Namespace=self.metrics_namespace, MetricData=metric_data
            )
            logger.info(f"Sent {len(metric_data)} metrics to CloudWatch")
        except Exception as e:
            logger.error(f"Error sending metrics: {e}")

    def store_analysis_results(self, basic_metrics: Dict, ai_insights: Dict):
        """Store analysis results in the Lambda's own CloudWatch log group."""
        result = {
            "basic_metrics": basic_metrics,
            "ai_insights": ai_insights,
            "timestamp": datetime.now().isoformat(),
            "environment": self.environment,
        }
        # Log to stdout — CloudWatch Logs captures Lambda output automatically
        logger.info(f"ANALYSIS_RESULT: {json.dumps(result, default=str)}")

    def analyze(self) -> Dict[str, Any]:
        """Main analysis workflow."""
        logger.info(
            f"Starting AI-powered log analysis for {self.log_group_name} "
            f"(last {self.hours_back}h)"
        )

        logs = self.fetch_logs()
        if not logs:
            logger.warning("No logs found")
            return {"status": "no_logs", "message": "No logs found to analyze"}

        basic_metrics = self.extract_basic_metrics(logs)
        logger.info(f"Basic metrics: {json.dumps(basic_metrics, indent=2)}")

        log_content = self.prepare_logs_for_analysis(logs)
        ai_insights = self.analyze_logs_with_bedrock(log_content)
        logger.info(f"AI insights severity: {ai_insights.get('severity', 'unknown')}")

        self.send_metrics_to_cloudwatch(basic_metrics, ai_insights)
        self.store_analysis_results(basic_metrics, ai_insights)

        return {
            "status": "success",
            "logs_analyzed": len(logs),
            "basic_metrics": basic_metrics,
            "ai_insights": ai_insights,
        }


def lambda_handler(event, context):
    """Lambda entry point. All config comes from environment variables."""
    analyzer = AILogAnalyzer()

    try:
        result = analyzer.analyze()
        return {"statusCode": 200, "body": json.dumps(result, default=str)}
    except Exception as e:
        logger.error(f"Error in lambda handler: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
