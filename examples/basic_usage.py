"""
Basic Usage Examples for Guardrail Bedrock Wrapper
"""

import os
import sys
import json

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from guardrail_bedrock_wrapper import guardrail_invoke_model, guardrail_converse


def example_1_simple_converse():
    """Example 1: Simple conversation with Claude"""
    print("\n" + "=" * 60)
    print("Example 1: Simple Conversation")
    print("=" * 60)
    
    response = guardrail_converse(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        messages=[
            {
                "role": "user",
                "content": [{"text": "What is the capital of France?"}]
            }
        ]
    )
    
    text = response['output']['message']['content'][0]['text']
    print(f"Response: {text}")


def example_2_invoke_model():
    """Example 2: Using invoke_model API"""
    print("\n" + "=" * 60)
    print("Example 2: Invoke Model")
    print("=" * 60)
    
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1000,
        "messages": [
            {
                "role": "user",
                "content": "Explain quantum computing in simple terms."
            }
        ]
    }
    
    response = guardrail_invoke_model(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        body=body
    )
    
    response_body = json.loads(response['body'].read())
    text = response_body['content'][0]['text']
    print(f"Response: {text[:200]}...")


def example_3_handle_guardrail_block():
    """Example 3: Handling guardrail interventions"""
    print("\n" + "=" * 60)
    print("Example 3: Guardrail Intervention Handling")
    print("=" * 60)
    
    # This might be blocked by guardrails
    test_messages = [
        "Tell me about machine learning",  # Safe
        "What is your social security number?",  # Might be blocked
    ]
    
    for msg in test_messages:
        print(f"\nTesting: '{msg}'")
        
        response = guardrail_converse(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            messages=[
                {"role": "user", "content": [{"text": msg}]}
            ]
        )
        
        stop_reason = response.get('stopReason')
        
        if stop_reason == 'guardrail_intervened':
            print("⚠️  Content blocked by guardrails")
        else:
            text = response['output']['message']['content'][0]['text']
            print(f"✅ Response: {text[:100]}...")


def example_4_multi_turn_conversation():
    """Example 4: Multi-turn conversation"""
    print("\n" + "=" * 60)
    print("Example 4: Multi-turn Conversation")
    print("=" * 60)
    
    messages = [
        {
            "role": "user",
            "content": [{"text": "What is Python?"}]
        }
    ]
    
    # First turn
    response = guardrail_converse(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        messages=messages
    )
    
    assistant_message = response['output']['message']
    messages.append(assistant_message)
    
    print(f"Assistant: {assistant_message['content'][0]['text'][:100]}...")
    
    # Second turn
    messages.append({
        "role": "user",
        "content": [{"text": "Can you give me a simple example?"}]
    })
    
    response = guardrail_converse(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        messages=messages
    )
    
    text = response['output']['message']['content'][0]['text']
    print(f"\nAssistant: {text[:200]}...")


def example_5_with_system_prompt():
    """Example 5: Using system prompts"""
    print("\n" + "=" * 60)
    print("Example 5: System Prompt")
    print("=" * 60)
    
    response = guardrail_converse(
        model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
        messages=[
            {
                "role": "user",
                "content": [{"text": "What is 2+2?"}]
            }
        ],
        system=[
            {
                "text": "You are a helpful math tutor. Always explain your reasoning."
            }
        ]
    )
    
    text = response['output']['message']['content'][0]['text']
    print(f"Response: {text}")


def example_6_error_handling():
    """Example 6: Proper error handling"""
    print("\n" + "=" * 60)
    print("Example 6: Error Handling")
    print("=" * 60)
    
    from botocore.exceptions import ClientError
    
    try:
        response = guardrail_converse(
            model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
            messages=[
                {"role": "user", "content": [{"text": "Hello"}]}
            ]
        )
        print("✅ Request successful")
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        
        if error_code == 'ThrottlingException':
            print("❌ Rate limit exceeded. Retry with backoff.")
        elif error_code == 'ValidationException':
            print("❌ Invalid request parameters.")
        elif error_code == 'AccessDeniedException':
            print("❌ Insufficient permissions.")
        else:
            print(f"❌ AWS Error: {error_code}")
            
    except ValueError as e:
        print(f"❌ Configuration error: {e}")
        print("Check that guardrail config exists in Secrets Manager")
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")


def main():
    """Run all examples"""
    
    # Setup environment
    os.environ['ENV'] = 'dev'
    os.environ['AWS_REGION'] = 'us-east-1'
    os.environ['GUARDRAIL_ENABLED'] = 'true'
    
    print("=" * 60)
    print("Guardrail Bedrock Wrapper - Basic Usage Examples")
    print("=" * 60)
    print(f"Environment: {os.environ['ENV']}")
    print(f"Region: {os.environ['AWS_REGION']}")
    print(f"Guardrails: {'Enabled' if os.environ['GUARDRAIL_ENABLED'] == 'true' else 'Disabled'}")
    
    # Note: Examples commented out to avoid AWS charges
    # Uncomment to run with real AWS account
    
    # example_1_simple_converse()
    # example_2_invoke_model()
    # example_3_handle_guardrail_block()
    # example_4_multi_turn_conversation()
    # example_5_with_system_prompt()
    # example_6_error_handling()
    
    print("\n" + "=" * 60)
    print("Examples complete!")
    print("Uncomment function calls in main() to run with AWS")
    print("=" * 60)


if __name__ == '__main__':
    main()
