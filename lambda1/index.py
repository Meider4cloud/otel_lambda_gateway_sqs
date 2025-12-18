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
    from opentelemetry.trace import SpanKind
    OTEL_AVAILABLE = True
    
    # Initialize manual instrumentation for community OTel configurations
    # Skip OTEL setup if using New Relic native layer
    observability_config = os.environ.get('OBSERVABILITY_CONFIG', '')
    if os.environ.get('AWS_LAMBDA_EXEC_WRAPPER') is None and observability_config != 'newrelic_native':
        # This is a community OTel config, initialize manually
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
        from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
        from opentelemetry.instrumentation.boto3sqs import Boto3SQSInstrumentor
        from opentelemetry.instrumentation.botocore import BotocoreInstrumentor
        from opentelemetry.sdk.resources import Resource
        
        # Create resource with Lambda identification
        resource = Resource.create({
            "service.name": os.environ.get('OTEL_SERVICE_NAME', 'lambda1-api-handler'),
            "service.version": os.environ.get('OTEL_SERVICE_VERSION', '1.0.0'),
            "lambda.function": "api-handler",
            "lambda.name": os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'lambda1-api-handler')
        })
        
        # Set up tracing with environment variable configuration
        trace_provider = TracerProvider(resource=resource)
        
        # Configure OTLP exporter with specific endpoints and headers
        traces_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 
                                        os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318'))
        metrics_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', 
                                         os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318'))
        headers_str = os.environ.get('OTEL_EXPORTER_OTLP_HEADERS', '')
        headers = {}
        if headers_str:
            # Parse headers from "key1=value1,key2=value2" format
            for header in headers_str.split(','):
                if '=' in header:
                    key, value = header.split('=', 1)
                    headers[key.strip()] = value.strip()
        
        otlp_exporter = OTLPSpanExporter(
            endpoint=traces_endpoint,
            headers=headers,
            timeout=5  # 5 second timeout
        )
        trace_provider.add_span_processor(BatchSpanProcessor(otlp_exporter, max_export_batch_size=50, schedule_delay_millis=1000))
        trace.set_tracer_provider(trace_provider)
        
        # Set up propagation - use both X-Ray and W3C for AWS compatibility
        try:
            from opentelemetry.propagators.composite import CompositePropagator
            from opentelemetry.propagators.aws import AwsXRayPropagator
            composite_propagator = CompositePropagator([
                AwsXRayPropagator(),
                TraceContextTextMapPropagator()
            ])
            propagate.set_global_textmap(composite_propagator)
            print("Using X-Ray + W3C propagation")
        except ImportError:
            # Fall back to W3C propagation only
            propagate.set_global_textmap(TraceContextTextMapPropagator())
            print("Using W3C propagation only (X-Ray propagator not available)")
        
        # Set up metrics with specific endpoint
        metric_reader = PeriodicExportingMetricReader(
            OTLPMetricExporter(
                endpoint=metrics_endpoint,
                headers=headers,
                timeout=5  # 5 second timeout
            ),
            export_interval_millis=5000  # Export every 5 seconds
        )
        metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
        
        # Auto-instrument
        Boto3SQSInstrumentor().instrument()
        BotocoreInstrumentor().instrument()
        print(f"Lambda1: Initialized OpenTelemetry manual instrumentation (config: {observability_config})")
        
    elif observability_config == 'newrelic_native':
        print(f"Lambda1: Skipping OpenTelemetry setup - using New Relic native layer (config: {observability_config})")
    else:
        print(f"Lambda1: Using ADOT layer - skipping manual instrumentation (config: {observability_config})")
        
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

def process_within_span(event, context, span):
    """Process the request within the provided span context"""
    
    # Extract body from API Gateway event
    if 'body' in event:
        if isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event['body']
    else:
        body = {"message": "Hello from API"}
    
    # Create message for SQS
    message = {
        "requestId": context.aws_request_id,
        "timestamp": context.get_remaining_time_in_millis(),
        "data": body
    }
    
    # Prepare message attributes with trace information
    message_attributes = {
        'RequestId': {
            'StringValue': context.aws_request_id,
            'DataType': 'String'
        }
    }
    
    # Get current trace context for manual propagation to SQS message
    trace_context = {}
    propagate.inject(trace_context)
    
    # Add trace context to message body for Lambda2 to extract
    message["traceContext"] = trace_context
    
    # Also add as message attributes for redundancy
    if trace_context:
        if 'traceparent' in trace_context:
            message_attributes['traceparent'] = {
                'StringValue': trace_context['traceparent'],
                'DataType': 'String'
            }
        if 'tracestate' in trace_context:
            message_attributes['tracestate'] = {
                'StringValue': trace_context['tracestate'],
                'DataType': 'String'
            }
        if 'X-Amzn-Trace-Id' in trace_context:
            message_attributes['X-Amzn-Trace-Id'] = {
                'StringValue': trace_context['X-Amzn-Trace-Id'],
                'DataType': 'String'
            }
    
    logger.info(f"Injected trace context: {trace_context}")
            
    # Send message to SQS - instrumentation will create producer spans automatically
    response = sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(message),
        MessageAttributes=message_attributes
    )
    
    logger.info(f"Message sent to SQS: {response['MessageId']}")
    
    # Add span attributes for SQS operation
    span.set_attribute("messaging.system", "sqs")
    span.set_attribute("messaging.operation", "publish")
    span.set_attribute("messaging.destination", SQS_QUEUE_URL.split('/')[-1])
    span.set_attribute("messaging.message_id", response['MessageId'])
    span.set_attribute("messaging.url", SQS_QUEUE_URL)
    # Mark this as the root span of the distributed trace
    span.set_attribute("span.kind", "server")
    
    # Force flush telemetry before Lambda freeze
    force_flush_telemetry()
    
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

def process_without_span(event, context):
    """Process the request without OpenTelemetry tracing"""
    
    # Extract body from API Gateway event
    if 'body' in event:
        if isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event['body']
    else:
        body = {"message": "Hello from API"}
        
    # Create message for SQS
    message = {
        "requestId": context.aws_request_id,
        "timestamp": context.get_remaining_time_in_millis(),
        "data": body,
        "traceContext": {}
    }
    
    # Send message to SQS
    response = sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(message),
        MessageAttributes={
            'RequestId': {
                'StringValue': context.aws_request_id,
                'DataType': 'String'
            }
        }
    )
    
    logger.info(f"Message sent to SQS: {response['MessageId']}")
    
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
        
        # Create spans for processing with Lambda identification
        if OTEL_AVAILABLE:
            tracer = trace.get_tracer(__name__)
            
            # Extract existing X-Ray trace context from Lambda environment
            trace_header = os.environ.get('_X_AMZN_TRACE_ID')
            parent_context = None
            
            if trace_header:
                # Extract X-Ray trace context
                carrier = {'X-Amzn-Trace-Id': trace_header}
                parent_context = propagate.extract(carrier)
                logger.info(f"Extracted X-Ray trace context: {trace_header}")
            
            # Create a SERVER span continuing the X-Ray trace
            with tracer.start_as_current_span(
                "api_request_processing",
                kind=SpanKind.SERVER,
                context=parent_context
            ) as span:
                span.set_attribute("lambda.function", "api-handler")
                span.set_attribute("lambda.name", os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'lambda1-api-handler'))
                span.set_attribute("http.method", event.get('httpMethod', 'POST'))
                span.set_attribute("http.path", event.get('path', '/process'))
                span.set_attribute("faas.execution", context.aws_request_id)
                span.set_attribute("faas.id", context.function_name)
                
                # All processing within span context
                return process_within_span(event, context, span)
        else:
            # Process without tracing
            return process_without_span(event, context)

        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        
        # Force flush telemetry even on error
        force_flush_telemetry()
        
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

def force_flush_telemetry():
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