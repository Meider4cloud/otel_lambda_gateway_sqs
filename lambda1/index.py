import sys
import os
# Add packages directory to Python path for locally installed packages
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'packages'))

import json
import boto3
import logging
import socket

# OpenTelemetry imports for force_flush
try:
    from opentelemetry import trace, metrics
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry import propagate
    from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
    OTEL_AVAILABLE = True
    
    # Initialize manual instrumentation for community OTel configurations
    if os.environ.get('AWS_LAMBDA_EXEC_WRAPPER') is None:
        # This is a community OTel config, initialize manually
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
        from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
        from opentelemetry.instrumentation.boto3sqs import Boto3SQSInstrumentor
        from opentelemetry.instrumentation.botocore import BotocoreInstrumentor
        from opentelemetry.instrumentation.logging import LoggingInstrumentor
        from opentelemetry.sdk.resources import Resource
        
        # Create resource
        resource = Resource.create({
            "service.name": os.environ.get('OTEL_SERVICE_NAME', 'lambda-function'),
            "service.version": os.environ.get('OTEL_SERVICE_VERSION', '1.0.0'),
        })
        
        # Set up tracing with environment variable configuration
        trace_provider = TracerProvider(resource=resource)
        
        # Configure OTLP exporter with headers if provided
        endpoint = os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318')
        headers_str = os.environ.get('OTEL_EXPORTER_OTLP_HEADERS', '')
        headers = {}
        if headers_str:
            # Parse headers from "key1=value1,key2=value2" format
            for header in headers_str.split(','):
                if '=' in header:
                    key, value = header.split('=', 1)
                    headers[key.strip()] = value.strip()
        
        otlp_exporter = OTLPSpanExporter(
            endpoint=endpoint,
            headers=headers,
            timeout=5  # 5 second timeout
        )
        trace_provider.add_span_processor(BatchSpanProcessor(otlp_exporter, max_export_batch_size=50, schedule_delay_millis=1000))
        trace.set_tracer_provider(trace_provider)
        
        # Set up metrics with same configuration
        metric_reader = PeriodicExportingMetricReader(
            OTLPMetricExporter(
                endpoint=endpoint,
                headers=headers,
                timeout=5  # 5 second timeout
            ),
            export_interval_millis=5000  # Export every 5 seconds
        )
        metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
        
        # Auto-instrument
        LoggingInstrumentor().instrument()
        Boto3SQSInstrumentor().instrument()
        BotocoreInstrumentor().instrument()
        
except ImportError as e:
    OTEL_AVAILABLE = False
    print(f"OpenTelemetry import error: {e}")
    # Note: logger not configured yet, use print for now

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
sqs = boto3.client('sqs')
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def test_connectivity():
    """Test network connectivity to New Relic OTLP endpoint"""
    try:
        # Test DNS resolution and connectivity to New Relic OTLP endpoint
        hostname = 'otlp.eu01.nr-data.net'
        port = 4318
        
        logger.info(f"Testing DNS resolution for {hostname}")
        ip = socket.gethostbyname(hostname)
        logger.info(f"Resolved {hostname} to {ip}")
        
        logger.info(f"Testing TCP connectivity to {hostname}:{port}")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((hostname, port))
        sock.close()
        
        if result == 0:
            logger.info(f"Successfully connected to {hostname}:{port}")
            return True
        else:
            logger.warning(f"Failed to connect to {hostname}:{port}, error code: {result}")
            return False
    except Exception as e:
        logger.error(f"Connectivity test failed: {e}")
        return False

def handler(event, context):
    """
    Lambda function to handle API Gateway requests and send messages to SQS
    """
    try:
        # Log OpenTelemetry status
        logger.info(f"OTEL_AVAILABLE = {OTEL_AVAILABLE}")
        
        # Test network connectivity first
        connectivity_ok = test_connectivity()
        
        # Log the incoming event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract body from API Gateway event
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = {"message": "Hello from API"}
        
        # Get current trace context
        trace_context = {}
        if OTEL_AVAILABLE:
            # Extract current trace context for propagation
            propagator = TraceContextTextMapPropagator()
            propagate.inject(trace_context)
            
        # Create message for SQS
        message = {
            "requestId": context.aws_request_id,
            "timestamp": context.get_remaining_time_in_millis(),
            "data": body,
            "traceContext": trace_context  # Add trace context to message body
        }
        
        # Prepare message attributes with trace information
        message_attributes = {
            'RequestId': {
                'StringValue': context.aws_request_id,
                'DataType': 'String'
            }
        }
        
        # Add trace context as message attributes if available
        if OTEL_AVAILABLE and trace_context:
            current_span = trace.get_current_span()
            if current_span.is_recording():
                span_context = current_span.get_span_context()
                message_attributes['TraceId'] = {
                    'StringValue': format(span_context.trace_id, '032x'),
                    'DataType': 'String'
                }
                message_attributes['SpanId'] = {
                    'StringValue': format(span_context.span_id, '016x'),
                    'DataType': 'String'
                }
                message_attributes['TraceFlags'] = {
                    'StringValue': str(span_context.trace_flags),
                    'DataType': 'String'
                }
                
        # Send message to SQS
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message),
            MessageAttributes=message_attributes
        )
        
        logger.info(f"Message sent to SQS: {response['MessageId']}")
        
        # Force flush telemetry before Lambda freeze
        _force_flush_telemetry()
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Request processed successfully',
                'messageId': response['MessageId'],
                'requestId': context.aws_request_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        
        # Force flush telemetry even on error
        _force_flush_telemetry()
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }

def _force_flush_telemetry():
    """Force flush OpenTelemetry data before Lambda freeze"""
    if not OTEL_AVAILABLE:
        return
    
    try:
        # Force flush traces with shorter timeout
        tracer_provider = trace.get_tracer_provider()
        if hasattr(tracer_provider, 'force_flush'):
            success = tracer_provider.force_flush(timeout_millis=500)
            logger.info(f"Trace flush success: {success}")
        
        # Force flush metrics with shorter timeout
        meter_provider = metrics.get_meter_provider()
        if hasattr(meter_provider, 'force_flush'):
            success = meter_provider.force_flush(timeout_millis=500)
            logger.info(f"Metrics flush success: {success}")
            
    except Exception as e:
        logger.warning(f"Error during force_flush: {str(e)}")