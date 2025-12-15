import sys
import os
# Add packages directory to Python path for locally installed packages
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'packages'))

import json
import logging
from datetime import datetime

# OpenTelemetry imports for force_flush
try:
    from opentelemetry import trace, metrics
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry import propagate
    from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
    from opentelemetry.trace import SpanKind, Status, StatusCode
    OTEL_AVAILABLE = True
except ImportError as e:
    OTEL_AVAILABLE = False
    print(f"OpenTelemetry import error: {e}")
    # Note: logger not configured yet, use print for now

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda function to process messages from SQS
    """
    try:
        # Log OpenTelemetry status
        logger.info(f"OTEL_AVAILABLE = {OTEL_AVAILABLE}")
        
        # Log the incoming event
        logger.info(f"Received SQS event: {json.dumps(event)}")
        
        # Process each record from SQS
        for record in event['Records']:
            # Extract message body
            message_body = json.loads(record['body'])
            receipt_handle = record['receiptHandle']
            
            # Extract trace context from SQS message and continue the trace
            parent_span_context = None
            if OTEL_AVAILABLE:
                try:
                    # First, try to get trace context from AWS X-Ray trace header in attributes
                    attributes = record.get('attributes', {})
                    aws_trace_header = attributes.get('AWSTraceHeader')
                    
                    if aws_trace_header:
                        logger.info(f"Found AWSTraceHeader: {aws_trace_header}")
                        # Parse AWS X-Ray trace header: Root=1-trace_id-parent_id;Parent=span_id;Sampled=1
                        parent_span_context = _parse_xray_trace_header(aws_trace_header)
                        
                    # Fallback: Try custom message attributes (for community OTel configs)
                    if not parent_span_context:
                        message_attributes = record.get('messageAttributes', {})
                        if 'TraceId' in message_attributes and 'SpanId' in message_attributes:
                            trace_id_hex = message_attributes['TraceId']['stringValue']
                            span_id_hex = message_attributes['SpanId']['stringValue']
                            trace_flags = int(message_attributes.get('TraceFlags', {}).get('stringValue', '1'))
                            
                            # Reconstruct span context
                            from opentelemetry.trace import TraceFlags, SpanContext
                            parent_span_context = SpanContext(
                                trace_id=int(trace_id_hex, 16),
                                span_id=int(span_id_hex, 16),
                                is_remote=True,
                                trace_flags=TraceFlags(trace_flags)
                            )
                    
                    # Last resort: try to get from message body trace context
                    if not parent_span_context and 'traceContext' in message_body and message_body['traceContext']:
                        propagator = TraceContextTextMapPropagator()
                        parent_context = propagate.extract(message_body['traceContext'])
                        parent_span_context = trace.get_current_span(parent_context).get_span_context()
                        
                except Exception as e:
                    logger.warning(f"Failed to extract trace context: {e}")
            
            logger.info(f"Processing message: {message_body}")
            
            # Create a child span that continues the trace chain
            if OTEL_AVAILABLE and parent_span_context:
                tracer = trace.get_tracer(__name__)
                with tracer.start_as_current_span(
                    "sqs_message_processing",
                    kind=SpanKind.CONSUMER,
                    context=trace.set_span_in_context(trace.NonRecordingSpan(parent_span_context))
                ) as span:
                    span.set_attribute("sqs.receipt_handle", receipt_handle)
                    span.set_attribute("message.request_id", message_body.get('requestId', 'unknown'))
                    # Your business logic here
                    process_message(message_body)
            else:
                # Fallback if trace context is not available
                process_message(message_body)
            
            logger.info(f"Successfully processed message with receipt handle: {receipt_handle}")
        
        # Force flush telemetry before Lambda freeze
        _force_flush_telemetry()
        
        return {
            'statusCode': 200,
            'body': json.dumps('Messages processed successfully')
        }
        
    except Exception as e:
        logger.error(f"Error processing SQS messages: {str(e)}")
        # Force flush telemetry even on error
        _force_flush_telemetry()
        # Re-raise the exception to trigger SQS retry mechanism
        raise e

def process_message(message):
    """
    Process individual message - implement your business logic here
    """
    try:
        request_id = message.get('requestId', 'unknown')
        timestamp = message.get('timestamp', 'unknown')
        data = message.get('data', {})
        
        logger.info(f"Processing request {request_id} with data: {data}")
        
        # Simulate some processing time
        import time
        time.sleep(1)
        
        # Example processing logic
        if 'action' in data:
            action = data['action']
            logger.info(f"Executing action: {action}")
            
            if action == 'process_order':
                process_order(data)
            elif action == 'send_notification':
                send_notification(data)
            else:
                logger.info(f"Unknown action: {action}")
        
        logger.info(f"Completed processing for request {request_id}")
        
    except Exception as e:
        logger.error(f"Error in process_message: {str(e)}")
        raise e

def process_order(data):
    """Example order processing logic"""
    order_id = data.get('orderId', 'unknown')
    logger.info(f"Processing order: {order_id}")
    # Add your order processing logic here

def send_notification(data):
    """Example notification sending logic"""
    recipient = data.get('recipient', 'unknown')
    message = data.get('message', 'No message')
    logger.info(f"Sending notification to {recipient}: {message}")
    # Add your notification logic here

def _parse_xray_trace_header(trace_header):
    """
    Parse AWS X-Ray trace header and return OpenTelemetry SpanContext
    Format: Root=1-trace_id-parent_id;Parent=span_id;Sampled=1;Lineage=...
    """
    try:
        from opentelemetry.trace import TraceFlags, SpanContext
        
        # Split header by semicolon
        parts = trace_header.split(';')
        
        trace_id = None
        parent_id = None
        sampled = True
        
        for part in parts:
            if part.startswith('Root='):
                # Extract trace ID from Root=1-trace_id-parent_id format
                root_value = part.split('=')[1]
                root_parts = root_value.split('-')
                if len(root_parts) >= 3:
                    # trace_id is the second part (after version)
                    trace_id = int(root_parts[1], 16)
            elif part.startswith('Parent='):
                # Parent span ID
                parent_id = int(part.split('=')[1], 16)
            elif part.startswith('Sampled='):
                sampled = part.split('=')[1] == '1'
        
        if trace_id and parent_id:
            logger.info(f"Parsed trace context: trace_id={trace_id:032x}, parent_id={parent_id:016x}, sampled={sampled}")
            return SpanContext(
                trace_id=trace_id,
                span_id=parent_id,
                is_remote=True,
                trace_flags=TraceFlags(0x01 if sampled else 0x00)
            )
        else:
            logger.warning(f"Failed to parse trace header: {trace_header}")
            return None
            
    except Exception as e:
        logger.warning(f"Error parsing X-Ray trace header '{trace_header}': {e}")
        return None

def _force_flush_telemetry():
    """Force flush OpenTelemetry data before Lambda freeze"""
    if not OTEL_AVAILABLE:
        return
    
    try:
        # Force flush traces
        tracer_provider = trace.get_tracer_provider()
        if hasattr(tracer_provider, 'force_flush'):
            tracer_provider.force_flush(timeout_millis=1000)
            logger.debug("Forced flush of trace data")
        
        # Force flush metrics
        meter_provider = metrics.get_meter_provider()
        if hasattr(meter_provider, 'force_flush'):
            meter_provider.force_flush(timeout_millis=1000)
            logger.debug("Forced flush of metrics data")
            
    except Exception as e:
        logger.warning(f"Error during force_flush: {str(e)}")