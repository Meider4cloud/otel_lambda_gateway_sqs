import sys
import os
# Add packages directory to Python path for locally installed packages
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'packages'))

import json
import logging
from datetime import datetime

# OpenTelemetry imports
try:
    from opentelemetry import trace, metrics
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry import propagate
    from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
    from opentelemetry.trace import SpanKind, Status, StatusCode
    
    # Initialize manual instrumentation
    # Skip OTEL setup if using New Relic native layer
    observability_config = os.environ.get('OBSERVABILITY_CONFIG', '')
    if os.environ.get('AWS_LAMBDA_EXEC_WRAPPER') is None and observability_config != 'newrelic_native':
        # Create resource with Lambda identification
        resource = Resource.create({
            "service.name": os.environ.get('OTEL_SERVICE_NAME', 'lambda2-worker'),
            "service.version": os.environ.get('OTEL_SERVICE_VERSION', '1.0.0'),
            "lambda.function": "worker",
            "lambda.name": os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'lambda2-worker')
        })
        
        # Get configuration from environment variables
        traces_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 
                                        os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318'))
        metrics_endpoint = os.environ.get('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', 
                                         os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318'))
        headers_str = os.environ.get('OTEL_EXPORTER_OTLP_HEADERS', '')
        headers = {}
        if headers_str:
            for header in headers_str.split(','):
                if '=' in header:
                    key, value = header.split('=', 1)
                    headers[key.strip()] = value.strip()
        
        # Set up tracing with specific endpoint
        trace_provider = TracerProvider(resource=resource)
        otlp_exporter = OTLPSpanExporter(
            endpoint=traces_endpoint,
            headers=headers,
            timeout=5
        )
        trace_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
        trace.set_tracer_provider(trace_provider)
        
        # Set up metrics with specific endpoint
        metric_reader = PeriodicExportingMetricReader(
            OTLPMetricExporter(
                endpoint=metrics_endpoint,
                headers=headers,
                timeout=5
            ),
            export_interval_millis=5000
        )
        metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
        
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
        
        print(f"Lambda2: Initialized OpenTelemetry manual instrumentation (config: {observability_config})")
        
    elif observability_config == 'newrelic_native':
        print(f"Lambda2: Skipping OpenTelemetry setup - using New Relic native layer (config: {observability_config})")
    else:
        print(f"Lambda2: Using ADOT layer - skipping manual instrumentation (config: {observability_config})")
    
    OTEL_AVAILABLE = True
except ImportError as e:
    OTEL_AVAILABLE = False
    print(f"OpenTelemetry import error: {e}")

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda 2 - Worker
    Processes messages from SQS with OpenTelemetry tracing
    """
    
    logger.info(f"Received SQS event: {json.dumps(event)}")
    
    try:
        # Process each record in the SQS event
        for record in event['Records']:
            # Extract message body
            message_body = json.loads(record['body'])
            
            # Extract trace context - Priority: SQS attributes > message body > Lambda env
            trace_context = {}
            
            # PRIORITY 1: Extract from SQS message attributes (from producer span)
            if 'messageAttributes' in record:
                msg_attrs = record['messageAttributes']
                if 'X-Amzn-Trace-Id' in msg_attrs:
                    trace_context['X-Amzn-Trace-Id'] = msg_attrs['X-Amzn-Trace-Id']['stringValue']
                    logger.info(f"Found SQS message X-Ray trace: {msg_attrs['X-Amzn-Trace-Id']['stringValue']}")
                if 'traceparent' in msg_attrs:
                    trace_context['traceparent'] = msg_attrs['traceparent']['stringValue']
                    logger.info(f"Found SQS message traceparent: {msg_attrs['traceparent']['stringValue']}")
                if 'tracestate' in msg_attrs:
                    trace_context['tracestate'] = msg_attrs['tracestate']['stringValue']
            
            # PRIORITY 2: Extract from SQS record attributes (AWS managed)
            if 'attributes' in record and 'AWSTraceHeader' in record['attributes']:
                if 'X-Amzn-Trace-Id' not in trace_context:  # Only if not already set
                    aws_trace_header = record['attributes']['AWSTraceHeader']
                    trace_context['X-Amzn-Trace-Id'] = aws_trace_header
                    logger.info(f"Found SQS AWS trace header: {aws_trace_header}")
            
            # PRIORITY 3: Fallback to message body trace context
            if not trace_context:
                body_trace_context = message_body.get('traceContext', {})
                if body_trace_context:
                    trace_context.update(body_trace_context)
                    logger.info(f"Using message body trace context: {list(body_trace_context.keys())}")
            
            # PRIORITY 4: Last resort - Lambda environment (should not be used for proper hierarchy)
            if not trace_context:
                trace_header = os.environ.get('_X_AMZN_TRACE_ID')
                if trace_header:
                    trace_context['X-Amzn-Trace-Id'] = trace_header
                    logger.info(f"Fallback to Lambda env X-Ray trace: {trace_header}")
            
            # Create span with Lambda identification and trace propagation
            if OTEL_AVAILABLE:
                tracer = trace.get_tracer(__name__)
                # Extract parent context if available
                parent_context = None
                if trace_context:
                    try:
                        parent_context = propagate.extract(trace_context)
                        logger.info(f"Successfully extracted trace context: {list(trace_context.keys())}")
                    except Exception as e:
                        logger.warning(f"Failed to extract trace context: {e}")
                        logger.info(f"Trace context content: {trace_context}")
                else:
                    logger.info("No trace context found in SQS message")
                
                # Determine the correct context for span creation
                span_context = parent_context if parent_context else None
                
                with tracer.start_as_current_span(
                    "sqs_message_processing",
                    context=span_context,
                    kind=SpanKind.CONSUMER
                ) as span:
                    span.set_attribute("lambda.function", "worker")
                    span.set_attribute("lambda.name", os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'lambda2-worker'))
                    span.set_attribute("messaging.system", "sqs")
                    span.set_attribute("messaging.operation", "process")
                    span.set_attribute("messaging.message_id", record.get('messageId', ''))
                    span.set_attribute("faas.execution", context.aws_request_id)
                    span.set_attribute("faas.id", context.function_name)
                    # Mark this as a consumer span in the distributed trace
                    span.set_attribute("span.kind", "consumer")
                    
                    # Process the message
                    result = process_message_with_span(message_body, span)
            else:
                # Process without tracing
                result = process_message(message_body)
            
            logger.info(f"Message processed successfully: {result}")
        
        # Force flush telemetry before Lambda freeze
        force_flush_telemetry()
        
        return {
            'batchItemFailures': []  # Return empty array to indicate all messages processed successfully
        }
        
    except Exception as e:
        logger.error(f"Error processing SQS messages: {str(e)}")
        
        # Force flush telemetry even on error
        force_flush_telemetry()
        
        # Return the failed message for retry
        return {
            'batchItemFailures': [{'itemIdentifier': record['messageId']} for record in event['Records']]
        }

def process_message_with_span(message_body, span):
    """
    Process individual message with OpenTelemetry span
    """
    
    # Extract message data
    message = message_body.get('message', 'No message')
    test_id = message_body.get('test_id', 'no-id')
    source = message_body.get('source', 'unknown')
    
    # Add message attributes to span
    if span and span.is_recording():
        span.set_attribute("message.test_id", test_id)
        span.set_attribute("message.source", source)
        span.set_attribute("message.size", len(json.dumps(message_body)))
    
    # Simulate some business logic processing
    processing_timestamp = datetime.now().isoformat()
    
    result = {
        'original_message': message,
        'source': source,
        'test_id': test_id,
        'processed_at': processing_timestamp,
        'processing_status': 'completed'
    }
    
    # Log the processing result
    logger.info(f"Message processing completed for test_id: {test_id}")
    
    return result

def process_message(message_body):
    """
    Process individual message without tracing (fallback)
    """
    
    # Extract message data
    message = message_body.get('message', 'No message')
    test_id = message_body.get('test_id', 'no-id')
    source = message_body.get('source', 'unknown')
    
    # Simulate some business logic processing
    processing_timestamp = datetime.now().isoformat()
    
    result = {
        'original_message': message,
        'source': source,
        'test_id': test_id,
        'processed_at': processing_timestamp,
        'processing_status': 'completed'
    }
    
    # Log the processing result
    logger.info(f"Message processing completed for test_id: {test_id}")
    
    return result

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