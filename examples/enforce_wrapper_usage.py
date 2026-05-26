"""
Example: Enforcing Guardrail Wrapper Usage

This example shows different strategies to ensure all Bedrock calls
go through the guardrail wrapper and cannot be bypassed.
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from guardrail_bedrock_wrapper import (
    guardrail_invoke_model,
    guardrail_converse,
    prevent_bypass
)


# Strategy 1: Application-Level Enforcement
# ==========================================
# Call this at application startup to log direct boto3 usage

def setup_enforcement():
    """Setup guardrail enforcement at application startup"""
    print("🔒 Setting up guardrail enforcement...")
    prevent_bypass()
    print("✅ Guardrail enforcement active")


# Strategy 2: Wrapper Module
# ===========================
# Create a wrapper module that your team imports

class BedrockClient:
    """
    Wrapper class that enforces guardrail usage.
    
    This replaces direct boto3 bedrock-runtime client usage.
    """
    
    def __init__(self, region_name=None):
        self.region = region_name or os.environ.get('AWS_REGION', 'us-east-1')
        print(f"🔒 BedrockClient initialized with guardrails for {self.region}")
    
    def invoke_model(self, model_id, body, **kwargs):
        """Invoke model with guardrails enforced"""
        return guardrail_invoke_model(model_id, body, **kwargs)
    
    def converse(self, model_id, messages, **kwargs):
        """Converse with guardrails enforced"""
        return guardrail_converse(model_id, messages, **kwargs)


# Strategy 3: Import Hook
# =======================
# Prevent importing boto3 bedrock-runtime directly

class GuardrailImportHook:
    """
    Import hook that warns when boto3 is imported.
    
    This is an advanced technique for strict enforcement.
    """
    
    def find_module(self, fullname, path=None):
        if fullname == 'boto3':
            print("⚠️  Warning: boto3 imported. Use BedrockClient instead.")
        return None


# Strategy 4: Environment Validation
# ===================================

def validate_environment():
    """Validate that required environment variables are set"""
    required_vars = ['ENV', 'AWS_REGION']
    missing = [var for var in required_vars if not os.environ.get(var)]
    
    if missing:
        raise EnvironmentError(
            f"Missing required environment variables: {', '.join(missing)}\n"
            f"Set these before using Bedrock:\n"
            f"  export ENV=dev\n"
            f"  export AWS_REGION=us-east-1"
        )
    
    print(f"✅ Environment validated: ENV={os.environ['ENV']}, "
          f"REGION={os.environ['AWS_REGION']}")


# Strategy 5: Decorator Pattern
# ==============================

def require_guardrails(func):
    """
    Decorator that ensures guardrails are enabled.
    
    Usage:
        @require_guardrails
        def my_bedrock_function():
            response = guardrail_converse(...)
    """
    def wrapper(*args, **kwargs):
        if os.environ.get('GUARDRAIL_ENABLED', 'true').lower() != 'true':
            raise RuntimeError(
                "Guardrails are disabled! This is a security violation.\n"
                "Set GUARDRAIL_ENABLED=true to proceed."
            )
        return func(*args, **kwargs)
    return wrapper


# Example Usage
# =============

@require_guardrails
def chat_with_claude(message: str) -> str:
    """
    Chat with Claude using guardrails.
    
    This function is decorated to ensure guardrails are enabled.
    """
    response = guardrail_converse(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        messages=[
            {"role": "user", "content": [{"text": message}]}
        ]
    )
    
    # Check for guardrail intervention
    if response.get('stopReason') == 'guardrail_intervened':
        return "⚠️ Your message was blocked by content policy."
    
    return response['output']['message']['content'][0]['text']


def main():
    """Main example demonstrating enforcement strategies"""
    
    print("=" * 60)
    print("Guardrail Enforcement Examples")
    print("=" * 60)
    
    # Setup environment
    os.environ['ENV'] = 'dev'
    os.environ['AWS_REGION'] = 'us-east-1'
    os.environ['GUARDRAIL_ENABLED'] = 'true'
    
    # Strategy 1: Application-level enforcement
    print("\n1. Application-Level Enforcement")
    print("-" * 60)
    setup_enforcement()
    
    # Strategy 2: Wrapper class
    print("\n2. Wrapper Class Usage")
    print("-" * 60)
    client = BedrockClient()
    print("✅ BedrockClient ready for use")
    
    # Strategy 4: Environment validation
    print("\n3. Environment Validation")
    print("-" * 60)
    validate_environment()
    
    # Strategy 5: Decorator pattern
    print("\n4. Decorator Pattern")
    print("-" * 60)
    try:
        result = chat_with_claude("Hello, how are you?")
        print(f"✅ Chat successful (guardrails active)")
        print(f"Response preview: {result[:100]}...")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print("\n" + "=" * 60)
    print("All enforcement strategies demonstrated")
    print("=" * 60)


# Team Guidelines
# ===============

TEAM_GUIDELINES = """
BEDROCK USAGE GUIDELINES
========================

DO ✅:
- Use guardrail_invoke_model() for all Bedrock calls
- Use guardrail_converse() for conversation API
- Use BedrockClient wrapper class
- Set ENV and AWS_REGION environment variables
- Check stopReason for guardrail interventions
- Log all Bedrock interactions

DON'T ❌:
- Import boto3.client('bedrock-runtime') directly
- Bypass guardrail wrapper
- Disable GUARDRAIL_ENABLED in production
- Ignore guardrail_intervened responses
- Hard-code credentials or regions

EXAMPLE:
--------
from guardrail_bedrock_wrapper import guardrail_converse

response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}]
)

if response.get('stopReason') == 'guardrail_intervened':
    # Handle blocked content
    pass
else:
    # Process response
    text = response['output']['message']['content'][0]['text']

SUPPORT:
--------
- Documentation: README.md
- Wrapper Guide: PYTHON_WRAPPER_GUIDE.md
- Issues: Contact platform team
"""


if __name__ == '__main__':
    # Print guidelines
    print(TEAM_GUIDELINES)
    
    # Run examples
    print("\n" + "=" * 60)
    print("Running Examples...")
    print("=" * 60)
    
    # Note: Actual Bedrock calls commented out to avoid AWS charges
    # Uncomment to test with real AWS account
    
    # main()
    
    print("\n✅ Examples complete. Uncomment main() to run with AWS.")
