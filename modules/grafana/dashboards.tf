# ─────────────────────────────────────────────────────────────
# Grafana Dashboards — mirrors CloudWatch dashboards
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# Core Monitoring Dashboard
# ─────────────────────────────────────────────────────────────
locals {
  # Build model invocation targets for Grafana
  model_invocation_targets = [
    for i, model_id in var.model_ids : {
      refId      = "model_${i}"
      namespace  = "AWS/Bedrock"
      metricName = "Invocations"
      dimensions = { ModelId = [model_id] }
      region     = var.aws_region
      period     = "300"
      stat       = "Sum"
      label      = model_id
    }
  ]

  model_latency_targets = [
    for i, model_id in var.model_ids : {
      refId      = "latency_${i}"
      namespace  = "AWS/Bedrock"
      metricName = "InvocationLatency"
      dimensions = { ModelId = [model_id] }
      region     = var.aws_region
      period     = "300"
      stat       = "Average"
      label      = model_id
    }
  ]

  core_dashboard_json = jsonencode({
    annotations = { list = [] }
    editable    = true
    title       = "LLMOps Bedrock Core - ${var.environment}"
    tags        = ["llmops", "bedrock", var.environment]
    timezone    = "browser"
    panels = [
      # Row 1: Invocations, Errors, Latency
      {
        id      = 1
        type    = "timeseries"
        title   = "Model Invocations by Type"
        gridPos = { h = 8, w = 8, x = 0, y = 0 }
        targets = local.model_invocation_targets
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            unit   = "short"
          }
        }
      },
      {
        id      = 2
        type    = "timeseries"
        title   = "Error Rate Overview"
        gridPos = { h = 8, w = 8, x = 8, y = 0 }
        targets = [
          {
            refId      = "client_errors"
            namespace  = "AWS/Bedrock"
            metricName = "InvocationClientErrors"
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Client Errors"
          },
          {
            refId      = "server_errors"
            namespace  = "AWS/Bedrock"
            metricName = "InvocationServerErrors"
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Server Errors"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            color  = { mode = "palette-classic" }
            unit   = "short"
          }
        }
      },
      {
        id      = 3
        type    = "timeseries"
        title   = "Latency (Avg & P99)"
        gridPos = { h = 8, w = 8, x = 16, y = 0 }
        targets = [
          {
            refId      = "avg_latency"
            namespace  = "AWS/Bedrock"
            metricName = "InvocationLatency"
            region     = var.aws_region
            period     = "300"
            stat       = "Average"
            label      = "Average"
          },
          {
            refId      = "p99_latency"
            namespace  = "AWS/Bedrock"
            metricName = "InvocationLatency"
            region     = var.aws_region
            period     = "300"
            stat       = "p99"
            label      = "P99"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            unit   = "ms"
          }
        }
      },
      # Row 2: Token Usage, Throttling
      {
        id      = 4
        type    = "timeseries"
        title   = "Total Token Usage"
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
        targets = [
          {
            refId      = "input_tokens"
            namespace  = "AWS/Bedrock"
            metricName = "InputTokenCount"
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Input Tokens"
          },
          {
            refId      = "output_tokens"
            namespace  = "AWS/Bedrock"
            metricName = "OutputTokenCount"
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Output Tokens"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "bars", lineWidth = 1, fillOpacity = 50 }
            unit   = "short"
          }
        }
      },
      {
        id      = 5
        type    = "timeseries"
        title   = "Throttling Events"
        gridPos = { h = 8, w = 12, x = 12, y = 8 }
        targets = [
          {
            refId      = "throttles"
            namespace  = "AWS/Bedrock"
            metricName = "InvocationThrottles"
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Throttles"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 20 }
            color  = { fixedColor = "red", mode = "fixed" }
            unit   = "short"
          }
        }
      },
      # Row 3: Log-based panels
      {
        id      = 6
        type    = "table"
        title   = "Recent Guardrail Blocks"
        gridPos = { h = 8, w = 12, x = 0, y = 16 }
        targets = [
          {
            refId         = "guardrail_blocks"
            queryMode     = "Logs"
            region        = var.aws_region
            logGroupNames = [var.cloudwatch_log_group_name]
            expression    = "fields @timestamp, @message\n| parse @message /\"stopReason\":\\s*\"(?<stopReason>[^\"]+)\"/\n| filter stopReason == \"guardrail_intervened\"\n| sort @timestamp desc\n| limit 10"
          }
        ]
      },
      {
        id      = 7
        type    = "table"
        title   = "Slow Requests (>${var.slow_request_threshold_ms}ms)"
        gridPos = { h = 8, w = 12, x = 12, y = 16 }
        targets = [
          {
            refId         = "slow_requests"
            queryMode     = "Logs"
            region        = var.aws_region
            logGroupNames = [var.cloudwatch_log_group_name]
            expression    = "fields @timestamp as Timestamp, modelId as Model, input.inputTokenCount as InputTokens, output.outputTokenCount as OutputTokens, output.outputBodyJson.metrics.latencyMs as LatencyMs\n| filter output.outputBodyJson.metrics.latencyMs > ${var.slow_request_threshold_ms}\n| sort @timestamp desc\n| limit 20"
          }
        ]
      }
    ]
    time    = { from = "now-6h", to = "now" }
    refresh = "5m"
  })

  # ─────────────────────────────────────────────────────────────
  # Identity Tracking Dashboard
  # ─────────────────────────────────────────────────────────────
  identity_dashboard_json = jsonencode({
    annotations = { list = [] }
    editable    = true
    title       = "LLMOps Bedrock Identity - ${var.environment}"
    tags        = ["llmops", "bedrock", "identity", var.environment]
    timezone    = "browser"
    panels = [
      {
        id      = 1
        type    = "table"
        title   = "All Bedrock API Calls by Role and User"
        gridPos = { h = 10, w = 24, x = 0, y = 0 }
        targets = [
          {
            refId         = "identity_calls"
            queryMode     = "Logs"
            region        = var.aws_region
            logGroupNames = [var.cloudwatch_log_group_name]
            expression    = "parse @message /arn:aws:sts::[0-9]+:assumed-role\\/(?<role_name>[^\\/]+)\\/(?<user_session>[^\",]+)/\n| fields @timestamp as timestamp, operation as api_call, role_name, user_session\n| filter ispresent(role_name)\n| sort @timestamp desc\n| limit 100"
          }
        ]
      },
      {
        id      = 2
        type    = "barchart"
        title   = "API Call Count by Role"
        gridPos = { h = 8, w = 12, x = 0, y = 10 }
        targets = [
          {
            refId         = "role_counts"
            queryMode     = "Logs"
            region        = var.aws_region
            logGroupNames = [var.cloudwatch_log_group_name]
            expression    = "parse @message /arn:aws:sts::[0-9]+:assumed-role\\/(?<role_name>[^\\/]+)\\/(?<user_session>[^\",]+)/\n| stats count() as call_count by role_name, user_session\n| sort call_count desc"
          }
        ]
      }
    ]
    time    = { from = "now-24h", to = "now" }
    refresh = "5m"
  })

  # ─────────────────────────────────────────────────────────────
  # Log Analysis Dashboard
  # ─────────────────────────────────────────────────────────────
  log_analysis_dashboard_json = jsonencode({
    annotations = { list = [] }
    editable    = true
    title       = "LLMOps Log Analysis - ${var.environment}"
    tags        = ["llmops", "bedrock", "log-analysis", var.environment]
    timezone    = "browser"
    panels = [
      {
        id      = 1
        type    = "timeseries"
        title   = "Log Analysis Metrics"
        gridPos = { h = 8, w = 12, x = 0, y = 0 }
        targets = [
          {
            refId      = "total_invocations"
            namespace  = "LLMOps/LogAnalysis"
            metricName = "TotalInvocations"
            dimensions = { Environment = [var.environment] }
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Total Invocations"
          },
          {
            refId      = "error_count"
            namespace  = "LLMOps/LogAnalysis"
            metricName = "ErrorCount"
            dimensions = { Environment = [var.environment] }
            region     = var.aws_region
            period     = "300"
            stat       = "Sum"
            label      = "Errors"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            unit   = "short"
          }
        }
      },
      {
        id      = 2
        type    = "timeseries"
        title   = "Average Latency from Logs"
        gridPos = { h = 8, w = 12, x = 12, y = 0 }
        targets = [
          {
            refId         = "avg_latency"
            queryMode     = "Logs"
            region        = var.aws_region
            logGroupNames = [var.cloudwatch_log_group_name]
            expression    = "fields @timestamp, output.outputBodyJson.metrics.latencyMs as latency\n| filter ispresent(latency)\n| stats avg(latency) as AvgLatencyMs by bin(5m)\n| sort @timestamp desc"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ms"
          }
        }
      },
      {
        id      = 3
        type    = "timeseries"
        title   = "Model Invocations"
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
        targets = local.model_invocation_targets
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            unit   = "short"
          }
        }
      },
      {
        id      = 4
        type    = "timeseries"
        title   = "Model Latency"
        gridPos = { h = 8, w = 12, x = 12, y = 8 }
        targets = local.model_latency_targets
        fieldConfig = {
          defaults = {
            custom = { drawStyle = "line", lineWidth = 2, fillOpacity = 10 }
            unit   = "ms"
          }
        }
      }
    ]
    time    = { from = "now-6h", to = "now" }
    refresh = "5m"
  })
}
