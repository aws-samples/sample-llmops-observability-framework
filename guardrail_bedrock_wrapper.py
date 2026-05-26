"""
Guardrail Bedrock Wrapper - Enforces guardrails on all Bedrock API calls

This wrapper ensures that ALL Bedrock API calls go through guardrail validation.
It provides a centralized enforcement point for security policies.

Usage:
    from guardrail_bedrock_wrapper import guardrail_invoke_model, guardrail_converse
    
    # Instead of bedrock_client.invoke_model()
    response = guardrail_invoke_model(model_id="...", body={...})
    
    # Instead of bedrock_client.converse()
    response = guardrail_converse(model_id="...", messages=[...])
"""

import json
import logging
import os
from typing import Dict, List, Optional, Union

import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GuardrailBedrockWrapper:
    """
    Wrapper class that enforces guardrails on all Bedrock API calls.
    
    This class acts as a security enforcement layer, ensuring that no Bedrock
    calls bypass the configured guardrails.
    """
    
    def __init__(self, region_name: Optional[str] = None, environment: Optional[str] = None):
        """
        Initialize the Guardrail Bedrock Wrapper.
        
        Args:
            region_name: AWS region (defaults to environment variable or us-east-1)
            environment: Environment name (dev/test/prod, defaults to ENV variable)
        """
        self.region = region_name or os.environ.get("AWS_REGION", "us-east-1")
        self.environment = environment or os.environ.get("ENV", "dev")
        self.bedrock_rt = boto3.client("bedrock-runtime", region_name=self.region)
        self.secrets_client = boto3.client("secretsmanager", region_name=self.region)
        self._guardrail_cache = None
        self._guardrail_enabled = os.environ.get("GUARDRAIL_ENABLED", "true").lower() == "true"
        
        logger.info(f"Initialized GuardrailBedrockWrapper for {self.environment} in {self.region}")
        logger.info(f"Guardrails enabled: {self._guardrail_enabled}")

    def _get_guardrail_config(self) -> Dict:
        """
        Get guardrail configuration from AWS Secrets Manager.
        
        Returns:
            Dict containing guardrail_id, guardrail_version, and guardrail_arn
        """
        if self._guardrail_cache:
            return self._guardrail_cache

        try:
            secret_name = f"llmops-guardrail-config-{self.environment}"
            logger.info(f"Fetching guardrail config from secret: {secret_name}")
            
            response = self.secrets_client.get_secret_value(SecretId=secret_name)
            self._guardrail_cache = json.loads(response["SecretString"])
            
            logger.info(f"Successfully loaded guardrail config: {self._guardrail_cache.get('guardrail_id')}")
            return self._guardrail_cache
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'ResourceNotFoundException':
                logger.error(f"Guardrail secret not found: {secret_name}")
            else:
                logger.error(f"Failed to get guardrail config: {e}")
            return {}
        except Exception as e:
            logger.error(f"Unexpected error getting guardrail config: {e}")
            return {}

    def _add_guardrails(self, params: Dict) -> Dict:
        """
        Add guardrail configuration to API parameters.
        
        Args:
            params: Dictionary of API parameters
            
        Returns:
            Updated parameters with guardrail config
        """
        if not self._guardrail_enabled:
            logger.warning("⚠️ GUARDRAILS DISABLED - Proceeding without guardrails")
            return params

        guardrail_config = self._get_guardrail_config()
        
        if not guardrail_config or not guardrail_config.get("guardrail_id"):
            logger.error("❌ GUARDRAIL CONFIG MISSING - Cannot proceed safely")
            raise ValueError(
                "Guardrails are enabled but configuration is missing. "
                "This is a security violation. Check Secrets Manager."
            )
        
        params["guardrailConfig"] = {
            "guardrailIdentifier": guardrail_config.get("guardrail_id"),
            "guardrailVersion": guardrail_config.get("guardrail_version", "DRAFT"),
            "trace": "enabled",
        }
        
        logger.info(f"✅ GUARDRAILS ACTIVE - ID: {guardrail_config.get('guardrail_id')}")
        return params

    def invoke_model(
        self, 
        model_id: str, 
        body: Union[str, Dict], 
        **kwargs
    ) -> Dict:
        """
        Invoke Bedrock model with guardrails enforced.
        
        Args:
            model_id: Bedrock model identifier
            body: Request body (string or dict)
            **kwargs: Additional parameters for invoke_model
            
        Returns:
            Response from Bedrock API
            
        Raises:
            ValueError: If guardrails are enabled but config is missing
        """
        logger.info(f"🔒 Intercepting invoke_model call for {model_id}")
        
        # Convert body to dict if string
        body_dict = json.loads(body) if isinstance(body, str) else body.copy()
        
        # Add guardrails
        body_dict = self._add_guardrails(body_dict)

        # Enable trace to see guardrail blocking details
        extra_headers = kwargs.get("ExtraHeaders", {})
        extra_headers["X-Amzn-Bedrock-Trace"] = "ENABLED"
        kwargs["ExtraHeaders"] = extra_headers

        try:
            response = self.bedrock_rt.invoke_model(
                modelId=model_id, 
                body=json.dumps(body_dict), 
                **kwargs
            )
            logger.info(f"✅ Model invocation successful for {model_id}")
            return response
        except ClientError as e:
            logger.error(f"❌ Model invocation failed: {e}")
            raise

    def converse(
        self, 
        model_id: str, 
        messages: List[Dict], 
        **kwargs
    ) -> Dict:
        """
        Converse with Bedrock model with guardrails enforced.
        
        Args:
            model_id: Bedrock model identifier
            messages: List of conversation messages
            **kwargs: Additional parameters for converse
            
        Returns:
            Response from Bedrock API
            
        Raises:
            ValueError: If guardrails are enabled but config is missing
        """
        logger.info(f"🔒 Intercepting converse call for {model_id}")
        
        # Add guardrails
        kwargs = self._add_guardrails(kwargs)

        try:
            response = self.bedrock_rt.converse(
                modelId=model_id, 
                messages=messages, 
                **kwargs
            )
            
            # Check for guardrail intervention
            self._log_response_details(response)
            
            return response
        except ClientError as e:
            logger.error(f"❌ Converse call failed: {e}")
            raise
    
    def _log_response_details(self, response: Dict) -> None:
        """
        Log response details including guardrail interventions.
        
        Args:
            response: Response from Bedrock API
        """
        try:
            # Extract response text
            response_text = (
                response.get("output", {})
                .get("message", {})
                .get("content", [{}])[0]
                .get("text", "")
            )
            truncated = "..." if len(response_text) > 500 else ""
            logger.debug(f"Response preview: {response_text[:500]}{truncated}")

            # Check if response was blocked by guardrail
            stop_reason = response.get("stopReason")
            if stop_reason == "guardrail_intervened":
                logger.warning("⚠️ GUARDRAIL BLOCKED RESPONSE")
                self._log_guardrail_intervention(response)
            else:
                logger.info(f"✅ Response completed with stop_reason: {stop_reason}")

        except Exception as e:
            logger.warning(f"Failed to log response details: {e}")
    
    def _log_guardrail_intervention(self, response: Dict) -> None:
        """
        Log details about guardrail intervention.
        
        Args:
            response: Response from Bedrock API containing trace info
        """
        try:
            trace = response.get("trace", {})
            guardrail_trace = trace.get("guardrail", {})
            input_assessment = guardrail_trace.get("inputAssessment", {})

            for guardrail_id, assessment in input_assessment.items():
                logger.warning(f"Guardrail ID: {guardrail_id}")
                
                # Log content policy violations
                content_policy = assessment.get("contentPolicy", {})
                filters = content_policy.get("filters", [])

                for filter_info in filters:
                    if filter_info.get("detected"):
                        ftype = filter_info.get("type")
                        conf = filter_info.get("confidence")
                        strength = filter_info.get("filterStrength")
                        action = filter_info.get("action")
                        logger.warning(
                            f"🚫 BLOCKED: Type={ftype}, Confidence={conf}, "
                            f"Strength={strength}, Action={action}"
                        )

                # Log processing metrics
                metrics = assessment.get("invocationMetrics", {})
                if metrics:
                    latency = metrics.get("guardrailProcessingLatency")
                    coverage = metrics.get("guardrailCoverage", {})
                    logger.info(f"Processing: {latency}ms, Coverage: {coverage}")

        except Exception as e:
            logger.warning(f"Failed to log guardrail intervention: {e}")


# Global instance and convenience functions
_global_wrapper = None


def get_wrapper() -> GuardrailBedrockWrapper:
    """
    Get or create the global GuardrailBedrockWrapper instance.
    
    Returns:
        GuardrailBedrockWrapper instance
    """
    global _global_wrapper
    if _global_wrapper is None:
        _global_wrapper = GuardrailBedrockWrapper()
    return _global_wrapper


def guardrail_invoke_model(
    model_id: str, 
    body: Union[str, Dict], 
    **kwargs
) -> Dict:
    """
    Invoke Bedrock model with guardrails enforced.
    
    This is the primary function that should be used instead of direct
    bedrock_client.invoke_model() calls.
    
    Args:
        model_id: Bedrock model identifier
        body: Request body (string or dict)
        **kwargs: Additional parameters
        
    Returns:
        Response from Bedrock API
        
    Example:
        response = guardrail_invoke_model(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            body={"prompt": "Hello"}
        )
    """
    logger.info("🔒 Bedrock invoke_model call intercepted by guardrail wrapper")
    return get_wrapper().invoke_model(model_id, body, **kwargs)


def guardrail_converse(
    model_id: str, 
    messages: List[Dict], 
    **kwargs
) -> Dict:
    """
    Converse with Bedrock model with guardrails enforced.
    
    This is the primary function that should be used instead of direct
    bedrock_client.converse() calls.
    
    Args:
        model_id: Bedrock model identifier
        messages: List of conversation messages
        **kwargs: Additional parameters
        
    Returns:
        Response from Bedrock API
        
    Example:
        response = guardrail_converse(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            messages=[{"role": "user", "content": [{"text": "Hello"}]}]
        )
    """
    logger.info("🔒 Bedrock converse call intercepted by guardrail wrapper")
    response = get_wrapper().converse(model_id, messages, **kwargs)
    return response


# Monkey-patch prevention
def prevent_bypass():
    """
    Prevent direct access to boto3 bedrock-runtime client.
    
    This function can be called at application startup to ensure
    all Bedrock calls go through the guardrail wrapper.
    
    Note: This is an advanced security measure and may break
    legitimate use cases. Use with caution.
    """
    import sys
    
    original_boto3_client = boto3.client
    
    def guarded_client(service_name, *args, **kwargs):
        if service_name == "bedrock-runtime":
            logger.warning(
                "⚠️ Direct bedrock-runtime client creation detected. "
                "Use guardrail_invoke_model() or guardrail_converse() instead."
            )
        return original_boto3_client(service_name, *args, **kwargs)
    
    boto3.client = guarded_client
    logger.info("🔒 Boto3 client monkey-patch applied for guardrail enforcement")
