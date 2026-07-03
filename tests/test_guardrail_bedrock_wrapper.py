"""
Unit tests for guardrail_bedrock_wrapper.py
"""

import json
import os
import unittest
from unittest.mock import MagicMock, patch

import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from guardrail_bedrock_wrapper import (
    GuardrailBedrockWrapper,
    get_wrapper,
    guardrail_converse,
    guardrail_invoke_model,
)


class TestGuardrailBedrockWrapper(unittest.TestCase):
    """Tests for the GuardrailBedrockWrapper class."""

    def setUp(self):
        """Set up test fixtures."""
        self.env_patcher = patch.dict(os.environ, {
            "AWS_REGION": "us-east-1",
            "ENV": "dev",
            "GUARDRAIL_ENABLED": "true",
        })
        self.env_patcher.start()

        self.mock_bedrock = MagicMock()
        self.mock_secrets = MagicMock()

        with patch("boto3.client") as mock_client:
            mock_client.side_effect = lambda service, **kwargs: {
                "bedrock-runtime": self.mock_bedrock,
                "secretsmanager": self.mock_secrets,
            }[service]
            self.wrapper = GuardrailBedrockWrapper()

    def tearDown(self):
        self.env_patcher.stop()

    def _set_guardrail_config(self, guardrail_id="gr-123", version="1"):
        """Helper to set a valid guardrail config in the mock."""
        secret_value = json.dumps({
            "guardrail_id": guardrail_id,
            "guardrail_version": version,
            "guardrail_arn": f"arn:aws:bedrock:us-east-1:123456789012:guardrail/{guardrail_id}",
        })
        self.mock_secrets.get_secret_value.return_value = {
            "SecretString": secret_value
        }

    # ─────────────────────────────────────────────────────────────
    # invoke_model tests
    # ─────────────────────────────────────────────────────────────

    def test_invoke_model_passes_guardrail_as_api_params(self):
        """Guardrail config must be passed as top-level API parameters, not in body."""
        self._set_guardrail_config(guardrail_id="gr-abc", version="2")
        self.mock_bedrock.invoke_model.return_value = {
            "body": MagicMock(read=lambda: b'{"content": [{"text": "hi"}]}')
        }

        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "messages": [{"role": "user", "content": "Hello"}],
        }

        self.wrapper.invoke_model(model_id="anthropic.claude-3-5-sonnet-20241022-v2:0", body=body)

        call_kwargs = self.mock_bedrock.invoke_model.call_args
        # Guardrail params should be top-level kwargs
        assert call_kwargs.kwargs["guardrailIdentifier"] == "gr-abc"
        assert call_kwargs.kwargs["guardrailVersion"] == "2"
        assert call_kwargs.kwargs["trace"] == "ENABLED"

        # Body should NOT contain guardrailConfig
        sent_body = json.loads(call_kwargs.kwargs["body"])
        assert "guardrailConfig" not in sent_body
        assert "guardrailIdentifier" not in sent_body

    def test_invoke_model_body_string_input(self):
        """invoke_model accepts body as a JSON string."""
        self._set_guardrail_config()
        self.mock_bedrock.invoke_model.return_value = {
            "body": MagicMock(read=lambda: b'{"content": [{"text": "ok"}]}')
        }

        body_str = json.dumps({"messages": [{"role": "user", "content": "Hi"}]})
        self.wrapper.invoke_model(model_id="test-model", body=body_str)

        call_kwargs = self.mock_bedrock.invoke_model.call_args
        sent_body = json.loads(call_kwargs.kwargs["body"])
        assert sent_body["messages"][0]["content"] == "Hi"

    def test_invoke_model_raises_when_config_missing(self):
        """invoke_model raises ValueError when guardrails enabled but config is empty."""
        self.mock_secrets.get_secret_value.return_value = {
            "SecretString": json.dumps({})
        }

        with self.assertRaises(ValueError) as ctx:
            self.wrapper.invoke_model(model_id="test-model", body={"prompt": "hi"})

        assert "security violation" in str(ctx.exception).lower()

    def test_invoke_model_no_guardrails_when_disabled(self):
        """invoke_model skips guardrail params when GUARDRAIL_ENABLED=false."""
        self.wrapper._guardrail_enabled = False
        self.mock_bedrock.invoke_model.return_value = {
            "body": MagicMock(read=lambda: b'{"content": [{"text": "ok"}]}')
        }

        self.wrapper.invoke_model(model_id="test-model", body={"prompt": "hi"})

        call_kwargs = self.mock_bedrock.invoke_model.call_args
        assert "guardrailIdentifier" not in call_kwargs.kwargs
        assert "guardrailVersion" not in call_kwargs.kwargs

    # ─────────────────────────────────────────────────────────────
    # converse tests
    # ─────────────────────────────────────────────────────────────

    def test_converse_passes_guardrail_config_in_kwargs(self):
        """converse passes guardrailConfig as a top-level kwarg."""
        self._set_guardrail_config(guardrail_id="gr-xyz", version="3")
        self.mock_bedrock.converse.return_value = {
            "output": {"message": {"content": [{"text": "hello"}]}},
            "stopReason": "end_turn",
        }

        messages = [{"role": "user", "content": [{"text": "Hi"}]}]
        self.wrapper.converse(model_id="test-model", messages=messages)

        call_kwargs = self.mock_bedrock.converse.call_args
        guardrail_cfg = call_kwargs.kwargs.get("guardrailConfig")
        assert guardrail_cfg is not None
        assert guardrail_cfg["guardrailIdentifier"] == "gr-xyz"
        assert guardrail_cfg["guardrailVersion"] == "3"
        assert guardrail_cfg["trace"] == "enabled"

    def test_converse_raises_when_config_missing(self):
        """converse raises ValueError when guardrails enabled but config is empty."""
        self.mock_secrets.get_secret_value.return_value = {
            "SecretString": json.dumps({})
        }

        with self.assertRaises(ValueError):
            self.wrapper.converse(
                model_id="test-model",
                messages=[{"role": "user", "content": [{"text": "Hi"}]}],
            )

    def test_converse_no_guardrails_when_disabled(self):
        """converse skips guardrailConfig when disabled."""
        self.wrapper._guardrail_enabled = False
        self.mock_bedrock.converse.return_value = {
            "output": {"message": {"content": [{"text": "hi"}]}},
            "stopReason": "end_turn",
        }

        self.wrapper.converse(
            model_id="test-model",
            messages=[{"role": "user", "content": [{"text": "Hi"}]}],
        )

        call_kwargs = self.mock_bedrock.converse.call_args
        assert "guardrailConfig" not in call_kwargs.kwargs

    # ─────────────────────────────────────────────────────────────
    # Guardrail config caching tests
    # ─────────────────────────────────────────────────────────────

    def test_guardrail_config_cached_after_first_call(self):
        """Secrets Manager is only called once; subsequent calls use cache."""
        self._set_guardrail_config()

        self.wrapper._get_guardrail_config()
        self.wrapper._get_guardrail_config()
        self.wrapper._get_guardrail_config()

        self.mock_secrets.get_secret_value.assert_called_once()

    def test_guardrail_config_returns_empty_on_not_found(self):
        """Returns empty dict when secret doesn't exist."""
        from botocore.exceptions import ClientError

        self.mock_secrets.get_secret_value.side_effect = ClientError(
            {"Error": {"Code": "ResourceNotFoundException", "Message": "Not found"}},
            "GetSecretValue",
        )

        config = self.wrapper._get_guardrail_config()
        assert config == {}

    # ─────────────────────────────────────────────────────────────
    # Response logging tests
    # ─────────────────────────────────────────────────────────────

    def test_log_response_details_handles_guardrail_intervened(self):
        """_log_response_details handles guardrail_intervened stop reason without error."""
        response = {
            "output": {"message": {"content": [{"text": "blocked"}]}},
            "stopReason": "guardrail_intervened",
            "trace": {
                "guardrail": {
                    "inputAssessment": {
                        "gr-123": {
                            "contentPolicy": {
                                "filters": [
                                    {
                                        "type": "HATE",
                                        "confidence": "HIGH",
                                        "filterStrength": "HIGH",
                                        "action": "BLOCKED",
                                        "detected": True,
                                    }
                                ]
                            }
                        }
                    }
                }
            },
        }

        # Should not raise
        self.wrapper._log_response_details(response)

    def test_log_response_details_handles_normal_response(self):
        """_log_response_details handles normal end_turn without error."""
        response = {
            "output": {"message": {"content": [{"text": "Hello there!"}]}},
            "stopReason": "end_turn",
        }

        # Should not raise
        self.wrapper._log_response_details(response)

    def test_log_response_details_handles_empty_response(self):
        """_log_response_details handles malformed response gracefully."""
        # Should not raise even with empty/weird structure
        self.wrapper._log_response_details({})
        self.wrapper._log_response_details({"output": {}})

    # ─────────────────────────────────────────────────────────────
    # Initialization tests
    # ─────────────────────────────────────────────────────────────

    def test_init_reads_environment_variables(self):
        """Wrapper reads config from environment variables."""
        assert self.wrapper.region == "us-east-1"
        assert self.wrapper.environment == "dev"
        assert self.wrapper._guardrail_enabled is True

    def test_init_guardrail_disabled_from_env(self):
        """GUARDRAIL_ENABLED=false disables guardrails."""
        with patch.dict(os.environ, {"GUARDRAIL_ENABLED": "false"}):
            with patch("boto3.client"):
                wrapper = GuardrailBedrockWrapper()
        assert wrapper._guardrail_enabled is False


class TestConvenienceFunctions(unittest.TestCase):
    """Tests for module-level convenience functions."""

    def setUp(self):
        self.env_patcher = patch.dict(os.environ, {
            "AWS_REGION": "us-east-1",
            "ENV": "dev",
            "GUARDRAIL_ENABLED": "true",
        })
        self.env_patcher.start()

        # Reset global wrapper between tests
        import guardrail_bedrock_wrapper
        guardrail_bedrock_wrapper._global_wrapper = None

    def tearDown(self):
        self.env_patcher.stop()
        import guardrail_bedrock_wrapper
        guardrail_bedrock_wrapper._global_wrapper = None

    @patch("boto3.client")
    def test_get_wrapper_returns_singleton(self, mock_client):
        """get_wrapper returns the same instance on repeated calls."""
        wrapper1 = get_wrapper()
        wrapper2 = get_wrapper()
        assert wrapper1 is wrapper2

    @patch("boto3.client")
    def test_guardrail_invoke_model_delegates_to_wrapper(self, mock_client):
        """guardrail_invoke_model calls the global wrapper's invoke_model."""
        mock_bedrock = MagicMock()
        mock_secrets = MagicMock()
        mock_client.side_effect = lambda service, **kwargs: {
            "bedrock-runtime": mock_bedrock,
            "secretsmanager": mock_secrets,
        }[service]

        mock_secrets.get_secret_value.return_value = {
            "SecretString": json.dumps({"guardrail_id": "gr-1", "guardrail_version": "1"})
        }
        mock_bedrock.invoke_model.return_value = {
            "body": MagicMock(read=lambda: b'{"content": [{"text": "ok"}]}')
        }

        guardrail_invoke_model(model_id="test-model", body={"prompt": "hi"})
        mock_bedrock.invoke_model.assert_called_once()

    @patch("boto3.client")
    def test_guardrail_converse_delegates_to_wrapper(self, mock_client):
        """guardrail_converse calls the global wrapper's converse."""
        mock_bedrock = MagicMock()
        mock_secrets = MagicMock()
        mock_client.side_effect = lambda service, **kwargs: {
            "bedrock-runtime": mock_bedrock,
            "secretsmanager": mock_secrets,
        }[service]

        mock_secrets.get_secret_value.return_value = {
            "SecretString": json.dumps({"guardrail_id": "gr-1", "guardrail_version": "1"})
        }
        mock_bedrock.converse.return_value = {
            "output": {"message": {"content": [{"text": "hi"}]}},
            "stopReason": "end_turn",
        }

        guardrail_converse(
            model_id="test-model",
            messages=[{"role": "user", "content": [{"text": "Hi"}]}],
        )
        mock_bedrock.converse.assert_called_once()


class TestPreventBypass(unittest.TestCase):
    """Tests for the prevent_bypass function."""

    def test_prevent_bypass_logs_warning_on_bedrock_client(self):
        """prevent_bypass monkey-patches boto3.client to warn on bedrock-runtime."""
        import boto3
        from guardrail_bedrock_wrapper import prevent_bypass

        original_client = boto3.client

        try:
            prevent_bypass()

            with patch("guardrail_bedrock_wrapper.logger") as mock_logger:
                # Should still return a client (not block), but log a warning
                with patch.object(original_client, "__call__", return_value=MagicMock()) as _:
                    try:
                        boto3.client("bedrock-runtime", region_name="us-east-1")
                    except Exception:
                        pass
                    mock_logger.warning.assert_called()
        finally:
            # Restore original to not break other tests
            boto3.client = original_client


if __name__ == "__main__":
    unittest.main()
