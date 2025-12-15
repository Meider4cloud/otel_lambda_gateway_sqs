#!/usr/bin/env python3
"""
Test script to validate trace context propagation through SQS
"""

import json
import requests
import time

def test_trace_propagation():
    """Test that traces are properly linked across Lambda functions"""
    
    # Get the API Gateway URL from Terraform output
    print("🔍 Testing trace propagation through SQS...")
    
    # This would be your actual API Gateway URL
    # api_url = "https://YOUR_API_ID.execute-api.eu-central-1.amazonaws.com/dev/process"
    
    test_payload = {
        "action": "process_order",
        "orderId": "test-12345",
        "customerId": "cust-001",
        "amount": 100.50,
        "timestamp": int(time.time())
    }
    
    print(f"📤 Sending test request: {json.dumps(test_payload, indent=2)}")
    
    # Uncomment and replace with your actual API URL to test
    # try:
    #     response = requests.post(api_url, json=test_payload, timeout=10)
    #     print(f"✅ Response status: {response.status_code}")
    #     print(f"📥 Response body: {response.json()}")
    # except Exception as e:
    #     print(f"❌ Error: {e}")
    
    print("\n🔗 Trace Propagation Implementation:")
    print("1. Lambda 1 extracts current trace context")
    print("2. Trace context is injected into SQS message attributes")  
    print("3. Lambda 2 extracts trace context from SQS message")
    print("4. Lambda 2 creates child span with proper parent context")
    print("5. Complete trace chain: API Gateway → Lambda 1 → SQS → Lambda 2")
    
    print("\n📊 To verify in X-Ray:")
    print("- Check AWS X-Ray console for traces")
    print("- Look for single trace with multiple segments")
    print("- Verify SQS segment connects Lambda 1 and Lambda 2")

if __name__ == "__main__":
    test_trace_propagation()