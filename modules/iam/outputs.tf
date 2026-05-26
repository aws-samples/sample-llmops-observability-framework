output "llmops_role_arn" {
  description = "ARN of the LLMOps monitoring role"
  value       = aws_iam_role.llmops_role.arn
}

output "llmops_role_name" {
  description = "Name of the LLMOps monitoring role"
  value       = aws_iam_role.llmops_role.name
}

output "log_analyzer_role_arn" {
  description = "ARN of the log analyzer Lambda role"
  value       = aws_iam_role.log_analyzer_lambda_role.arn
}

output "log_analyzer_role_name" {
  description = "Name of the log analyzer Lambda role"
  value       = aws_iam_role.log_analyzer_lambda_role.name
}

output "bedrock_logging_role_arn" {
  description = "ARN of the Bedrock logging role"
  value       = aws_iam_role.bedrock_logging_role.arn
}

output "bedrock_logging_role_name" {
  description = "Name of the Bedrock logging role"
  value       = aws_iam_role.bedrock_logging_role.name
}
