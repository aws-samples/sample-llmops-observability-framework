# Python Wrapper Usage Guide

## Overview

The `guardrail_bedrock_wrapper.py` provides a security enforcement layer that ensures ALL Bedrock API calls go through configured guardrails. This prevents bypassing security controls.

## Installation

```bash
pip install boto3
```

## Basic Usage

### Import the Wrapper

```python
from guardrail_bedrock_wrapper import guardrail_invoke_model, guardrail_converse
```

### Invoke Model

```python
response = guardrail_invoke_model(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body={
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1000,
        "messages": [
            {"role": "user", "content": "Hello, how are you?"}
        ]
    }
)

# Parse response
response_body = json.loads(response['body'].read())
print(response_body['content'][0]['text'])
```

### Converse API

```python
response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[
        {
            "role": "user",
            "content": [{"text": "What is the capital of France?"}]
        }
    ]
)

# Extract response
text = response['output']['message']['content'][0]['text']
print(text)
```

## Configuration

### Environment Variables

```bash
export ENV=dev                    # Environment: dev, test, prod
export AWS_REGION=us-east-1       # AWS region
export GUARDRAIL_ENABLED=true     # Enable/disable guardrails
```

### Python Configuration

```python
import os

# Set environment
os.environ['ENV'] = 'prod'
os.environ['AWS_REGION'] = 'us-east-1'
os.environ['GUARDRAIL_ENABLED'] = 'true'

from guardrail_bedrock_wrapper import guardrail_converse
```

## Advanced Usage

### Custom Wrapper Instance

```python
from guardrail_bedrock_wrapper import GuardrailBedrockWrapper

# Create custom instance
wrapper = GuardrailBedrockWrapper(
    region_name='us-west-2',
    environment='prod'
)

# Use instance methods
response = wrapper.invoke_model(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body={"prompt": "Hello"}
)
```

### Handling Guardrail Blocks

```python
response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Sensitive content"}]}]
)

# Check if blocked
if response.get('stopReason') == 'guardrail_intervened':
    print("⚠️ Content was blocked by guardrails")
    
    # Get trace information
    trace = response.get('trace', {})
    guardrail_trace = trace.get('guardrail', {})
    
    # Log intervention details
    print(f"Guardrail trace: {guardrail_trace}")
else:
    # Process normal response
    text = response['output']['message']['content'][0]['text']
    print(text)
```

### Error Handling

```python
from botocore.exceptions import ClientError

try:
    response = guardrail_invoke_model(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        body={"prompt": "Hello"}
    )
except ClientError as e:
    error_code = e.response['Error']['Code']
    
    if error_code == 'ThrottlingException':
        print("Rate limit exceeded")
    elif error_code == 'ValidationException':
        print("Invalid request")
    else:
        print(f"Error: {e}")
except ValueError as e:
    # Guardrail configuration missing
    print(f"Configuration error: {e}")
```

## Integration Patterns

### Flask Application

```python
from flask import Flask, request, jsonify
from guardrail_bedrock_wrapper import guardrail_converse

app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message')
    
    try:
        response = guardrail_converse(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            messages=[
                {"role": "user", "content": [{"text": user_message}]}
            ]
        )
        
        if response.get('stopReason') == 'guardrail_intervened':
            return jsonify({
                'error': 'Content blocked by security policy'
            }), 400
        
        text = response['output']['message']['content'][0]['text']
        return jsonify({'response': text})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run()
```

### Lambda Function

```python
import json
from guardrail_bedrock_wrapper import guardrail_converse

def lambda_handler(event, context):
    """Lambda handler with guardrail enforcement"""
    
    try:
        user_message = event.get('message')
        
        response = guardrail_converse(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            messages=[
                {"role": "user", "content": [{"text": user_message}]}
            ]
        )
        
        if response.get('stopReason') == 'guardrail_intervened':
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Content blocked by guardrails'
                })
            }
        
        text = response['output']['message']['content'][0]['text']
        
        return {
            'statusCode': 200,
            'body': json.dumps({'response': text})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

### Async Usage

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor
from guardrail_bedrock_wrapper import guardrail_converse

async def async_converse(message):
    """Async wrapper for Bedrock calls"""
    loop = asyncio.get_event_loop()
    
    with ThreadPoolExecutor() as executor:
        response = await loop.run_in_executor(
            executor,
            guardrail_converse,
            "anthropic.claude-3-5-sonnet-20241022-v2:0",
            [{"role": "user", "content": [{"text": message}]}]
        )
    
    return response

# Usage
async def main():
    response = await async_converse("Hello")
    print(response)

asyncio.run(main())
```

## Preventing Bypass

### Monkey-Patch Protection

```python
from guardrail_bedrock_wrapper import prevent_bypass

# Call at application startup
prevent_bypass()

# Now direct boto3 bedrock-runtime client creation is logged
import boto3
client = boto3.client('bedrock-runtime')  # Warning logged
```

### Import Enforcement

Add to your application's `__init__.py`:

```python
# Enforce wrapper usage
import sys
from guardrail_bedrock_wrapper import guardrail_invoke_model, guardrail_converse

# Make wrapper functions available globally
sys.modules['bedrock_wrapper'] = sys.modules['guardrail_bedrock_wrapper']

# Prevent direct boto3 usage (optional, aggressive)
# from guardrail_bedrock_wrapper import prevent_bypass
# prevent_bypass()
```

## Testing

### Unit Tests

```python
import unittest
from unittest.mock import patch, MagicMock
from guardrail_bedrock_wrapper import GuardrailBedrockWrapper

class TestGuardrailWrapper(unittest.TestCase):
    
    @patch('boto3.client')
    def test_invoke_model(self, mock_boto_client):
        # Mock Bedrock client
        mock_bedrock = MagicMock()
        mock_boto_client.return_value = mock_bedrock
        
        # Mock response
        mock_bedrock.invoke_model.return_value = {
            'body': MagicMock()
        }
        
        # Test wrapper
        wrapper = GuardrailBedrockWrapper()
        response = wrapper.invoke_model(
            model_id="test-model",
            body={"prompt": "test"}
        )
        
        # Verify guardrails were added
        self.assertTrue(mock_bedrock.invoke_model.called)
    
    def test_guardrail_config_missing(self):
        # Test behavior when config is missing
        wrapper = GuardrailBedrockWrapper()
        wrapper._guardrail_enabled = True
        wrapper._guardrail_cache = {}
        
        with self.assertRaises(ValueError):
            wrapper._add_guardrails({})

if __name__ == '__main__':
    unittest.main()
```

## Logging

### Enable Debug Logging

```python
import logging

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Now wrapper will log detailed information
from guardrail_bedrock_wrapper import guardrail_converse

response = guardrail_converse(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}]
)
```

### Custom Logger

```python
import logging
from guardrail_bedrock_wrapper import GuardrailBedrockWrapper

# Create custom logger
logger = logging.getLogger('my_app.bedrock')
logger.setLevel(logging.INFO)

# Use wrapper with custom logger
wrapper = GuardrailBedrockWrapper()
# Logger is already configured in the module
```

## Best Practices

1. **Always use wrapper functions**: Never call boto3 Bedrock client directly
2. **Handle guardrail blocks gracefully**: Check `stopReason` in responses
3. **Set environment variables**: Configure ENV and AWS_REGION
4. **Enable logging**: Use DEBUG level during development
5. **Test guardrails**: Verify blocking works with test content
6. **Monitor CloudWatch**: Check logs for guardrail interventions
7. **Update configurations**: Keep guardrail YAML in sync with Secrets Manager

## Troubleshooting

### Guardrails Not Working

```python
# Check configuration
from guardrail_bedrock_wrapper import get_wrapper

wrapper = get_wrapper()
config = wrapper._get_guardrail_config()
print(f"Guardrail config: {config}")
print(f"Enabled: {wrapper._guardrail_enabled}")
```

### Secret Not Found

```bash
# Verify secret exists
aws secretsmanager list-secrets | grep guardrail

# Check secret value
aws secretsmanager get-secret-value \
  --secret-id llmops-guardrail-config-dev
```

### Permission Denied

```bash
# Check IAM permissions
aws iam get-role-policy \
  --role-name your-role-name \
  --policy-name your-policy-name
```

## Migration Guide

### From Direct Boto3

Before:
```python
import boto3

bedrock = boto3.client('bedrock-runtime')
response = bedrock.invoke_model(
    modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body=json.dumps({"prompt": "Hello"})
)
```

After:
```python
from guardrail_bedrock_wrapper import guardrail_invoke_model

response = guardrail_invoke_model(
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    body={"prompt": "Hello"}
)
```

## Support

For issues:
1. Check CloudWatch Logs
2. Verify Secrets Manager configuration
3. Enable DEBUG logging
4. Review IAM permissions
