output "guardrail_id" {
  description = "The ID of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.content_filter.guardrail_id
}

output "guardrail_arn" {
  description = "The ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.content_filter.guardrail_arn
}

output "guardrail_secret_name" {
  description = "The name of the secret containing guardrail details"
  value       = aws_secretsmanager_secret.guardrail_details.name
}

output "guardrail_secret_arn" {
  description = "The ARN of the secret containing guardrail details"
  value       = aws_secretsmanager_secret.guardrail_details.arn
}
