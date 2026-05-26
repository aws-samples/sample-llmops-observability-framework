output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.bedrock_model_invocation_logging_log_group.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.bedrock_model_invocation_logging_log_group.arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for logs"
  value       = aws_s3_bucket.bedrock_logs.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for logs"
  value       = aws_s3_bucket.bedrock_logs.arn
}
