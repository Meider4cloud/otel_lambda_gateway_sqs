import json
import boto3
import logging
import os
from datetime import datetime

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

logger.info("Lambda2-NewRelic-Native: Initialized with New Relic layer")

def handler(event, context):
    """
    Lambda 2 - Worker (New Relic Native)
    Processes messages from SQS
    """
    
    logger.info("Lambda2-NewRelic-Native: Starting SQS message processing")
    logger.info(f"Received SQS event: {json.dumps(event)}")
    
    try:
        # Process each SQS record
        for record in event.get('Records', []):
            # Extract AWS trace header if present
            attributes = record.get('attributes', {})
            aws_trace_header = attributes.get('AWSTraceHeader')
            
            if aws_trace_header:
                logger.info(f"Found SQS AWS trace header: {aws_trace_header}")
                logger.info(f"Successfully extracted trace context: ['X-Amzn-Trace-Id']")
            
            # Extract New Relic trace context from message attributes
            message_attributes = record.get('messageAttributes', {})
            newrelic_trace_id = None
            newrelic_span_id = None
            
            if 'newrelic_trace_id' in message_attributes:
                newrelic_trace_id = message_attributes['newrelic_trace_id'].get('stringValue')
                logger.info(f"Found New Relic trace ID: {newrelic_trace_id}")
                
            if 'newrelic_span_id' in message_attributes:
                newrelic_span_id = message_attributes['newrelic_span_id'].get('stringValue')
                logger.info(f"Found New Relic span ID: {newrelic_span_id}")
            
            # Extract SQS queue name from message attributes
            sqs_queue_name = 'unknown'
            if 'sqs_queue_name' in message_attributes:
                sqs_queue_name = message_attributes['sqs_queue_name'].get('stringValue', 'unknown')
            
            # Link to parent trace if New Relic context is available
            if newrelic and newrelic_trace_id:
                try:
                    # Add custom attributes to link traces
                    current_txn = newrelic.agent.current_transaction()
                    if current_txn:
                        newrelic.agent.add_custom_attribute('parent_trace_id', newrelic_trace_id)
                        if newrelic_span_id:
                            newrelic.agent.add_custom_attribute('parent_span_id', newrelic_span_id)
                        newrelic.agent.add_custom_attribute('trace_link_method', 'sqs_propagation')
                        newrelic.agent.add_custom_attribute('aws.sqs.QueueName', sqs_queue_name)
                        newrelic.agent.add_custom_attribute('service_name', 'worker')
                        newrelic.agent.add_custom_attribute('message_source', 'sqs')
                        newrelic.agent.add_custom_attribute('trace_relationship', 'child')
                        logger.info(f"Linked trace to parent trace ID: {newrelic_trace_id}")
                except Exception as e:
                    logger.error(f"Failed to link New Relic trace: {e}")
            elif newrelic:
                # Add attributes even if no parent trace
                try:
                    newrelic.agent.add_custom_attribute('aws.sqs.QueueName', sqs_queue_name)
                    newrelic.agent.add_custom_attribute('service_name', 'worker')
                    newrelic.agent.add_custom_attribute('message_source', 'sqs')
                    newrelic.agent.add_custom_attribute('trace_relationship', 'standalone')
                except Exception as e:
                    logger.error(f"Failed to add custom attributes: {e}")
            
            # Parse message body
            try:
                body = json.loads(record['body'])
                data = body.get('data', {})
                request_id = body.get('requestId', 'unknown')
                trace_context = body.get('traceContext', {})
                
                # Extract test_id if available
                test_id = data.get('test_id', 'no-id')
                original_message = data.get('message', 'No message')
                source = data.get('source', 'unknown')
                
                logger.info(f"Message processing completed for test_id: {test_id}")
                
                # Simulate message processing
                processed_data = {
                    'original_message': original_message,
                    'source': source,
                    'test_id': test_id,
                    'processed_at': datetime.now().isoformat(),
                    'processing_status': 'completed'
                }
                
                logger.info(f"Message processed successfully: {processed_data}")
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse message body: {e}")
                continue
            except Exception as e:
                logger.error(f"Error processing message: {e}", exc_info=True)
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({'status': 'Messages processed successfully'})
        }
        
    except Exception as e:
        logger.error(f"Error processing SQS event: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }