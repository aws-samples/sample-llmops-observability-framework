data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Package Lambda source code
data "archive_file" "log_analyzer" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda_package.zip"
}

# Lambda function for log analysis
resource "aws_lambda_function" "log_analyzer" {
  function_name = var.lambda_name
  description   = "AI-powered log analysis using Bedrock Claude"
  runtime       = var.lambda_runtime
  handler       = "index.lambda_handler"
  timeout       = var.lambda_timeout
  role          = var.lambda_role_arn

  filename         = data.archive_file.log_analyzer.output_path
  source_code_hash = data.archive_file.log_analyzer.output_base64sha256

  environment {
    variables = {
      LOG_GROUP_NAME    = var.log_group_name
      HOURS_BACK        = tostring(var.hours_back)
      ENVIRONMENT       = var.environment
      ANALYSIS_MODEL_ID = var.analysis_model_id
      FALLBACK_MODEL_ID = var.fallback_model_id
      MAX_LOG_CHARS     = tostring(var.max_log_chars)
      MAX_TOKENS        = tostring(var.max_tokens)
      METRICS_NAMESPACE = var.metrics_namespace
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for analysis results
resource "aws_cloudwatch_log_group" "log_analysis_results" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# EventBridge rule to trigger Lambda
resource "aws_cloudwatch_event_rule" "log_analysis_schedule" {
  name                = "${var.name_prefix}-log-analysis-schedule"
  description         = "Trigger log analysis on schedule"
  schedule_expression = var.schedule_expression

  tags = var.tags
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.log_analysis_schedule.name
  target_id = "LogAnalyzerLambdaTarget"
  arn       = aws_lambda_function.log_analyzer.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.log_analysis_schedule.arn
}

# Enhanced CloudWatch Dashboard with Log Analysis Insights
resource "aws_cloudwatch_dashboard" "log_analysis_dashboard" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["LLMOps/LogAnalysis", "TotalInvocations", "Environment", var.environment],
            [".", "ErrorCount", ".", "."],
            [".", "InputTokens", ".", "."],
            [".", "OutputTokens", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Log Analysis Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp, output.outputBodyJson.metrics.latencyMs as latency\n| filter ispresent(latency)\n| stats avg(latency) as `Average Latency (ms)` by bin(5m)\n| sort @timestamp desc"
          region = data.aws_region.current.name
          title  = "Average Latency from Logs"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/aws/lambda/${var.lambda_name}'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 20"
          region = data.aws_region.current.name
          title  = "Latest Log Analysis Results"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            for i, model_id in var.model_ids : ["AWS/Bedrock", "Invocations", "ModelId", model_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Model Invocations"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            for i, model_id in var.model_ids : ["AWS/Bedrock", "InvocationLatency", "ModelId", model_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Model Latency"
          period  = 300
        }
      }
    ]
  })
}

# Anomaly detection for errors
resource "aws_cloudwatch_log_anomaly_detector" "bedrock_errors" {
  detector_name           = "${var.name_prefix}-anomaly-detector"
  log_group_arn_list      = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/model-invocations-${var.environment}"]
  anomaly_visibility_time = 7
  evaluation_frequency    = "FIFTEEN_MIN"
  enabled                 = true
}
