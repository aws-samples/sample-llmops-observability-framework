data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Bedrock Guardrails for LLM Security
resource "aws_bedrock_guardrail" "content_filter" {
  name                      = var.guardrail_name
  blocked_input_messaging   = try(var.guardrail_config.guardrail.blocked_input_messaging, lookup(var.guardrail_config, "blocked_input_messaging", "This request violates our content policy."))
  blocked_outputs_messaging = try(var.guardrail_config.guardrail.blocked_outputs_messaging, lookup(var.guardrail_config, "blocked_outputs_messaging", "This response was blocked by our content policy."))
  description               = try(var.guardrail_config.guardrail.description, lookup(var.guardrail_config, "description", "Content filtering for LLM applications"))

  # Content Policy Configuration
  content_policy_config {
    dynamic "filters_config" {
      for_each = try(var.guardrail_config.content_policy.filters, try(var.guardrail_config.guardrail.content_policy.filters, []))
      content {
        input_strength  = filters_config.value.input_strength
        output_strength = filters_config.value.output_strength
        type            = filters_config.value.type
      }
    }
  }

  # Topic Policy Configuration
  dynamic "topic_policy_config" {
    for_each = try(length(var.guardrail_config.topic_policy.topics), try(length(var.guardrail_config.guardrail.topic_policy.topics), 0)) > 0 ? [1] : []
    content {
      dynamic "topics_config" {
        for_each = try(var.guardrail_config.topic_policy.topics, try(var.guardrail_config.guardrail.topic_policy.topics, []))
        content {
          name       = topics_config.value.name
          definition = topics_config.value.definition
          examples   = topics_config.value.examples
          type       = topics_config.value.type
        }
      }
    }
  }

  # Sensitive Information Policy Configuration
  dynamic "sensitive_information_policy_config" {
    for_each = try(length(var.guardrail_config.sensitive_information_policy.pii_entities), try(length(var.guardrail_config.guardrail.sensitive_information_policy.pii_entities), 0)) > 0 ? [1] : []
    content {
      dynamic "pii_entities_config" {
        for_each = try(var.guardrail_config.sensitive_information_policy.pii_entities, try(var.guardrail_config.guardrail.sensitive_information_policy.pii_entities, []))
        content {
          action = pii_entities_config.value.action
          type   = pii_entities_config.value.type
        }
      }

      dynamic "regexes_config" {
        for_each = try(var.guardrail_config.sensitive_information_policy.regex_patterns, try(var.guardrail_config.guardrail.sensitive_information_policy.regex_patterns, []))
        content {
          action      = regexes_config.value.action
          description = regexes_config.value.description
          name        = regexes_config.value.name
          pattern     = regexes_config.value.pattern
        }
      }
    }
  }

  # Word Policy Configuration
  dynamic "word_policy_config" {
    for_each = try(length(var.guardrail_config.word_policy.managed_word_lists), try(length(var.guardrail_config.guardrail.word_policy.managed_word_lists), 0)) > 0 || try(length(var.guardrail_config.word_policy.custom_words), try(length(var.guardrail_config.guardrail.word_policy.custom_words), 0)) > 0 ? [1] : []
    content {
      dynamic "managed_word_lists_config" {
        for_each = try(var.guardrail_config.word_policy.managed_word_lists, try(var.guardrail_config.guardrail.word_policy.managed_word_lists, []))
        content {
          type = managed_word_lists_config.value.type
        }
      }

      dynamic "words_config" {
        for_each = try(var.guardrail_config.word_policy.custom_words, try(var.guardrail_config.guardrail.word_policy.custom_words, []))
        content {
          text = words_config.value
        }
      }
    }
  }

  # Contextual Grounding Policy (optional)
  dynamic "contextual_grounding_policy_config" {
    for_each = var.contextual_grounding_enabled ? [1] : []
    content {
      filters_config {
        type      = "GROUNDING"
        threshold = var.contextual_grounding_threshold
      }
    }
  }

  tags = var.tags
}

# Secrets Manager for guardrail details
resource "aws_secretsmanager_secret" "guardrail_details" {
  name                    = var.guardrail_secret_name
  description             = "Bedrock guardrail configuration details"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "guardrail_details" {
  secret_id = aws_secretsmanager_secret.guardrail_details.id
  secret_string = jsonencode({
    guardrail_id      = aws_bedrock_guardrail.content_filter.guardrail_id
    guardrail_version = "DRAFT"
    guardrail_arn     = aws_bedrock_guardrail.content_filter.guardrail_arn
    environment       = var.environment
  })
}
