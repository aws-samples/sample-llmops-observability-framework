data "aws_region" "current" {}

# Core Bedrock Monitoring Dashboard
resource "aws_cloudwatch_dashboard" "bedrock_core_dashboard" {
  dashboard_name = var.core_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            for i, model_id in var.model_ids : ["AWS/Bedrock", "Invocations", "ModelId", model_id]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Model Invocations by Type"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Bedrock", "InvocationClientErrors"],
            ["AWS/Bedrock", "InvocationServerErrors"]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Error Rate Overview"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", { stat = "Average" }],
            [".", ".", { stat = "p99" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Latency (Avg & P99)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Bedrock", "InputTokenCount"],
            ["AWS/Bedrock", "OutputTokenCount"]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Total Token Usage"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Bedrock", "InvocationThrottles"]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Throttling Events"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp, @message\n| parse @message /\"stopReason\":\\s*\"(?<stopReason>[^\"]+)\"/\n| filter stopReason == \"guardrail_intervened\"\n| sort @timestamp desc\n| limit 10"
          region = data.aws_region.current.name
          title  = "Recent Guardrail Blocks"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp, requestId, latencyMs, inputTokenCount, outputTokenCount\n| sort @timestamp desc\n| limit 10"
          region = data.aws_region.current.name
          title  = "Recent Model Invocations"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp as Timestamp, modelId as Model, input.inputTokenCount as `Input Token Count`, output.outputTokenCount as `Output Token Count`, output.outputBodyJson.metrics.latencyMs as `Latency (ms)`\n| filter output.outputBodyJson.metrics.latencyMs > 2000\n| sort @timestamp desc\n| limit 20"
          region = data.aws_region.current.name
          title  = "Slow Requests (>2s)"
          view   = "table"
        }
      }
    ]
  })
}

# Identity Tracking Dashboard
resource "aws_cloudwatch_dashboard" "bedrock_identity_tracking" {
  dashboard_name = var.identity_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 24
        height = 8
        properties = {
          query  = <<-EOQ
            SOURCE '${var.log_group_name}'
            | parse @message /arn:aws:sts::[0-9]+:assumed-role\/(?<role_name>[^\/]+)\/(?<user_session>[^",]+)/
            | fields @timestamp as timestamp, operation as api_call, @message as message
            | filter ispresent(role_name)
            | sort @timestamp desc
            | limit 100
          EOQ
          region = data.aws_region.current.name
          title  = "All Bedrock API Calls by Role and User"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          query  = <<-EOQ
            SOURCE '${var.log_group_name}'
            | parse @message /arn:aws:sts::[0-9]+:assumed-role\/(?<role_name>[^\/]+)\/(?<user_session>[^",]+)/
            | stats count() as call_count by role_name, user_session
            | sort call_count desc
          EOQ
          region = data.aws_region.current.name
          title  = "API Call Count by Role"
          view   = "table"
        }
      }
    ]
  })
}
