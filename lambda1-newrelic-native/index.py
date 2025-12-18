import json
import boto3
import logging
import os
import time
import socket

# Configure logging first
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# New Relic imports for trace linking
try:
    import newrelic.agent
    logger.info("New Relic agent imported successfully")
except ImportError:
    newrelic = None
    logger.warning("New Relic agent not available")

# Initialize SQS client
sqs = boto3.client('sqs')
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

logger.info("Lambda1-NewRelic-Native: Initialized with New Relic layer")

def test_connectivity():
    """Test network connectivity for debugging"""
    try:
        logger.info("Testing DNS resolution for otlp.eu01.nr-data.net")
        host_ip = socket.gethostbyname('otlp.eu01.nr-data.net')
        logger.info(f"Resolved otlp.eu01.nr-data.net to {host_ip}")
        
        logger.info("Testing TCP connectivity to otlp.eu01.nr-data.net:4318")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex(('otlp.eu01.nr-data.net', 4318))
        sock.close()
        
        if result == 0:
            logger.info("Successfully connected to otlp.eu01.nr-data.net:4318")
        else:
            logger.warning(f"Failed to connect to otlp.eu01.nr-data.net:4318, error code: {result}")
    except Exception as e:
        logger.error(f"Connectivity test failed: {e}")

def extract_trace_context(event):
    """Extract trace context from API Gateway event for propagation"""
    trace_context = {}
    
    # Extract X-Ray trace context from headers
    headers = event.get('headers', {})
    x_amzn_trace_id = headers.get('X-Amzn-Trace-Id')
    
    if x_amzn_trace_id:
        logger.info(f"Extracted X-Ray trace context: {x_amzn_trace_id}")
        trace_context['X-Amzn-Trace-Id'] = x_amzn_trace_id
    
    # Extract New Relic trace context
    if newrelic:
        try:
            # Get current transaction for trace linking
            transaction = newrelic.agent.current_transaction()
            if transaction:
                # Get trace ID and span ID for linking
                trace_id = newrelic.agent.current_trace_id()
                span_id = newrelic.agent.current_span_id()
                
                if trace_id:
                    trace_context['newrelic_trace_id'] = trace_id
                    logger.info(f"Extracted New Relic trace ID: {trace_id}")
                
                if span_id:
                    trace_context['newrelic_span_id'] = span_id
                    logger.info(f"Extracted New Relic span ID: {span_id}")
        except Exception as e:
            logger.error(f"Failed to extract New Relic trace context: {e}")
    
    return trace_context

def handler(event, context):
    """
    Lambda 1 - API Handler (New Relic Native)
    Receives API Gateway requests and forwards to SQS
    """
    
    logger.info("Lambda1-NewRelic-Native: Starting request processing")
    
    # Test connectivity (for debugging)
    test_connectivity()
    
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract trace context for propagation
        trace_context = extract_trace_context(event)
        logger.info(f"Injected trace context: {trace_context}")
        
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Create message for SQS
        message_body = {
            'requestId': context.aws_request_id,
            'timestamp': int(time.time() * 1000),  # milliseconds
            'data': body,
            'traceContext': trace_context
        }
        
        # Send message to SQS with trace context as message attributes
        message_attributes = {
            'RequestId': {
                'StringValue': context.aws_request_id,
                'DataType': 'String'
            }
        }
        
        # Add trace context as message attributes if available
        if 'X-Amzn-Trace-Id' in trace_context:
            message_attributes['X-Amzn-Trace-Id'] = {
                'StringValue': trace_context['X-Amzn-Trace-Id'],
                'DataType': 'String'
            }
        
        # Add New Relic trace context for linking
        if 'newrelic_trace_id' in trace_context:
            message_attributes['newrelic_trace_id'] = {
                'StringValue': trace_context['newrelic_trace_id'],
                'DataType': 'String'
            }
            
        if 'newrelic_span_id' in trace_context:
            message_attributes['newrelic_span_id'] = {
                'StringValue': trace_context['newrelic_span_id'],
                'DataType': 'String'
            }
        
        # Add SQS queue name as custom attribute
        queue_name = SQS_QUEUE_URL.split('/')[-1] if SQS_QUEUE_URL else 'unknown'
        message_attributes['sqs_queue_name'] = {
            'StringValue': queue_name,
            'DataType': 'String'
        }

        
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_body),
            MessageAttributes=message_attributes
        )
        
        message_id = response['MessageId']
        logger.info(f"Message sent to SQS: {message_id}")
        
        # Add New Relic custom attributes for better traceability
        if newrelic:
            try:
                newrelic.agent.add_custom_attribute('aws.sqs.QueueName', queue_name)
                newrelic.agent.add_custom_attribute('message_id', message_id)
                newrelic.agent.add_custom_attribute('service_name', 'api-handler')
                logger.info("Added New Relic custom attributes")
            except Exception as e:
                logger.error(f"Failed to add custom attributes: {str(e)}")
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Request processed successfully',
                'messageId': message_id,
                'requestId': context.aws_request_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'requestId': context.aws_request_id
            })
        }