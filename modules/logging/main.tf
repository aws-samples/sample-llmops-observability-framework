# CloudWatch Log Group for Bedrock model invocations
resource "aws_cloudwatch_log_group" "bedrock_model_invocation_logging_log_group" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# S3 bucket for Bedrock logs
resource "aws_s3_bucket" "bedrock_logs" {
  bucket = var.s3_bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bedrock_logs" {
  bucket = aws_s3_bucket.bedrock_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy to enforce TLS (deny HTTP access)
resource "aws_s3_bucket_policy" "bedrock_logs_tls" {
  bucket = aws_s3_bucket.bedrock_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.bedrock_logs.arn,
          "${aws_s3_bucket.bedrock_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.bedrock_logs]
}

# Bedrock Model Invocation Logging Configuration
resource "aws_bedrock_model_invocation_logging_configuration" "bedrock_model_logging_config" {
  count = var.enable_model_invocation_logging ? 1 : 0

  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = true
    text_data_delivery_enabled      = true
    video_data_delivery_enabled     = true

    s3_config {
      bucket_name = aws_s3_bucket.bedrock_logs.id
      key_prefix  = "bedrock"
    }

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock_model_invocation_logging_log_group.name
      role_arn       = var.bedrock_logging_role_arn
    }
  }

  depends_on = [
    aws_s3_bucket.bedrock_logs,
    aws_cloudwatch_log_group.bedrock_model_invocation_logging_log_group
  ]
}
