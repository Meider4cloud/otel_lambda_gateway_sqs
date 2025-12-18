# Local values for different observability configurations
locals {
  # Layer ARNs for different configurations
  layer_arns = {
    # ADOT layers by region
    adot = "arn:aws:lambda:${data.aws_region.current.id}:901920570463:layer:aws-otel-python-amd64-ver-1-20-0:1"

    # Community OpenTelemetry layers (instrumentation + collector) build by script into account 339712788047

    community_otel_auto      = "arn:aws:lambda:eu-central-1:339712788047:layer:opentelemetry-python-auto:1"
    community_otel_collector = "arn:aws:lambda:eu-central-1:339712788047:layer:opentelemetry-collector:1"
  }

  # Configuration-specific settings
  observability_configs = {
    # Configuration 1: X-Ray with ADOT layer
    xray_adot = {
      layers = [local.layer_arns.adot]
      environment_variables = {
        AWS_LAMBDA_EXEC_WRAPPER     = "/opt/otel-instrument"
        OTEL_PROPAGATORS            = "tracecontext,baggage,xray"
        OTEL_PYTHON_DISTRO          = "aws_distro"
        OTEL_PYTHON_CONFIGURATOR    = "aws_lambda_configurator"
        OTEL_EXPORTER_OTLP_ENDPOINT = ""
        # Enable SQS message attribute propagation for X-Ray
        OTEL_PYTHON_LOG_CORRELATION = "true"
        # Ensure all instrumentations are enabled for X-Ray
        OTEL_PYTHON_DISABLED_INSTRUMENTATIONS = ""
      }
      iam_permissions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
    }

    # Configuration 2: X-Ray with community OpenTelemetry (via requirements.txt)
    xray_community = {
      layers = []
      environment_variables = {
        OTEL_PROPAGATORS                   = "tracecontext,baggage,xray"
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = ""
        OTEL_PYTHON_LOG_CORRELATION        = "true"
        OTEL_TRACES_EXPORTER               = "console,otlp"
        OTEL_EXPORTER_OTLP_PROTOCOL        = "grpc"
        PYTHONPATH                         = "/var/runtime:/var/task:/opt/python"
        # Enable all instrumentations including SQS for proper trace propagation
        OTEL_PYTHON_DISABLED_INSTRUMENTATIONS = ""
        # Explicitly enable SQS instrumentation
        AWS_XRAY_TRACING_NAME = "${var.project_name}-${var.environment}"
      }
      iam_permissions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
    }

    # Configuration 3: New Relic with ADOT layer
    newrelic_adot = {
      layers = [local.layer_arns.adot]
      environment_variables = {
        AWS_LAMBDA_EXEC_WRAPPER  = "/opt/otel-instrument"
        OTEL_PROPAGATORS         = "tracecontext,baggage"
        OTEL_PYTHON_DISTRO       = "aws_distro"
        OTEL_PYTHON_CONFIGURATOR = "aws_lambda_configurator"
        # Force OTLP exporter instead of X-Ray
        OTEL_TRACES_EXPORTER  = "otlp"
        OTEL_METRICS_EXPORTER = "otlp"
        OTEL_LOGS_EXPORTER    = "otlp"
        # New Relic OTLP endpoint
        OTEL_EXPORTER_OTLP_ENDPOINT         = "https://otlp.eu01.nr-data.net/v1/traces"
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT  = "https://otlp.eu01.nr-data.net/v1/traces"
        OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://otlp.eu01.nr-data.net/v1/metrics"
        OTEL_EXPORTER_OTLP_HEADERS          = "api-key=${var.newrelic_license_key}"
        OTEL_EXPORTER_OTLP_PROTOCOL         = "http/protobuf"
        # Disable X-Ray exporter explicitly
        OTEL_PYTHON_DISABLED_INSTRUMENTATIONS = "aws-xray"
        # Resource attributes for New Relic
        OTEL_RESOURCE_ATTRIBUTES = "service.name=${var.project_name}-${var.environment},service.version=1.0.0"
        NEW_RELIC_ACCOUNT_ID     = var.newrelic_account_id
      }
      iam_permissions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
    }

    # Configuration 4: New Relic with community OpenTelemetry (using requirements.txt, direct export)
    newrelic_community = {
      layers = []
      environment_variables = {
        # Use manual instrumentation instead of wrapper (wrapper path not working)
        # AWS_LAMBDA_EXEC_WRAPPER = "/opt/otel-instrument"
        # Auto-instrumentation configuration
        OTEL_PYTHON_DISABLED_INSTRUMENTATIONS = ""
        OTEL_PYTHON_LOG_CORRELATION           = "true"
        # Propagation
        OTEL_PROPAGATORS = "tracecontext,baggage"
        # Service identification
        #OTEL_SERVICE_NAME        = "${var.project_name}-${var.environment}"
        OTEL_SERVICE_VERSION = "1.0.0"
        #OTEL_RESOURCE_ATTRIBUTES = "service.name=${var.project_name}-${var.environment},service.version=1.0.0,deployment.environment=${var.environment}"
        # Exporter configuration - Send directly to New Relic OTLP endpoint
        OTEL_TRACES_EXPORTER  = "otlp"
        OTEL_METRICS_EXPORTER = "otlp"
        OTEL_LOGS_EXPORTER    = "otlp"
        # New Relic OTLP endpoint (direct export, bypassing collector) - correct EU endpoint  
        OTEL_EXPORTER_OTLP_ENDPOINT = "https://otlp.eu01.nr-data.net/v1/"
        # Set specific endpoints for each signal type
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT  = "https://otlp.eu01.nr-data.net/v1/traces"
        OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://otlp.eu01.nr-data.net/v1/metrics"
        OTEL_EXPORTER_OTLP_HEADERS          = "api-key=${var.newrelic_license_key}"
        OTEL_EXPORTER_OTLP_PROTOCOL         = "http/protobuf"
        # New Relic credentials (for collector configuration)
        NEW_RELIC_ACCOUNT_ID  = var.newrelic_account_id
        NEW_RELIC_LICENSE_KEY = var.newrelic_license_key


      }
      iam_permissions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
    }

    # Configuration 5: New Relic native Lambda layer (APM mode)
    newrelic_native = {
      layers = ["arn:aws:lambda:eu-central-1:451483290750:layer:NewRelicPython39:107"]
      environment_variables = {
        NEW_RELIC_LAMBDA_HANDLER               = "index.handler"
        NEW_RELIC_ACCOUNT_ID                   = var.newrelic_account_id
        NEW_RELIC_TRUSTED_ACCOUNT_KEY          = var.newrelic_account_id
        NEW_RELIC_LICENSE_KEY                  = var.newrelic_license_key
        NEW_RELIC_APM_LAMBDA_MODE              = "true"
        NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "false"
        NEW_RELIC_LAMBDA_EXTENSION_ENABLED     = "true"
        NEW_RELIC_DATA_COLLECTION_TIMEOUT      = "10s"
      }
      iam_permissions = []
      # Note: Handler needs to be changed to "newrelic_lambda_wrapper.handler" when using this config
    }
  }

  # Current configuration based on variable
  current_config = local.observability_configs[var.observability_config]

  # Merge current config environment variables with base Lambda environment variables
  lambda1_env_vars = merge({
    SQS_QUEUE_URL        = module.lambda_otel.sqs_queue_url
    ENVIRONMENT          = var.environment
    OBSERVABILITY_CONFIG = var.observability_config
    }, local.current_config.environment_variables, {
    # Override service identification for Lambda1
    OTEL_SERVICE_NAME        = "${var.project_name}-api-handler"
    OTEL_RESOURCE_ATTRIBUTES = "service.name=${var.project_name}-api-handler,service.version=1.0.0,deployment.environment=${var.environment},lambda.function=api-handler,aws.sqs.QueueName=otel-alml-poc-queue"
  })

  lambda2_env_vars = merge({
    ENVIRONMENT          = var.environment
    OBSERVABILITY_CONFIG = var.observability_config
    }, local.current_config.environment_variables, {
    # Override service identification for Lambda2
    OTEL_SERVICE_NAME        = "${var.project_name}-worker"
    OTEL_RESOURCE_ATTRIBUTES = "service.name=${var.project_name}-worker,service.version=1.0.0,deployment.environment=${var.environment},lambda.function=worker,aws.sqs.QueueName=otel-alml-poc-queue"
  })
}
