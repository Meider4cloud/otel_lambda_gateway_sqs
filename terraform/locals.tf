# Local values for different observability configurations
locals {
  # Layer ARNs for different configurations
  layer_arns = {
    # ADOT layers by region
    adot = "arn:aws:lambda:${data.aws_region.current.name}:901920570463:layer:aws-otel-python-amd64-ver-1-20-0:1"

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
        OTEL_EXPORTER_OTLP_ENDPOINT = "https://otlp.eu01.nr-data.net:4318"
        OTEL_EXPORTER_OTLP_HEADERS  = "api-key=${var.newrelic_license_key}"
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
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
        OTEL_SERVICE_NAME        = "${var.project_name}-${var.environment}"
        OTEL_SERVICE_VERSION     = "1.0.0"
        OTEL_RESOURCE_ATTRIBUTES = "service.name=${var.project_name}-${var.environment},service.version=1.0.0,deployment.environment=${var.environment}"
        # Exporter configuration - Send directly to New Relic OTLP endpoint
        OTEL_TRACES_EXPORTER  = "otlp"
        OTEL_METRICS_EXPORTER = "otlp"
        OTEL_LOGS_EXPORTER    = "otlp"
        # New Relic OTLP endpoint (direct export, bypassing collector) - correct EU endpoint
        OTEL_EXPORTER_OTLP_ENDPOINT = "https://otlp.eu01.nr-data.net:4318"
        OTEL_EXPORTER_OTLP_HEADERS  = "api-key=${var.newrelic_license_key}"
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
        # New Relic credentials (for collector configuration)
        NEW_RELIC_ACCOUNT_ID  = var.newrelic_account_id
        NEW_RELIC_LICENSE_KEY = var.newrelic_license_key


      }
      iam_permissions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
    }
  }

  # Current configuration based on variable
  current_config = local.observability_configs[var.observability_config]

  # Merge current config environment variables with base Lambda environment variables
  lambda1_env_vars = merge({
    SQS_QUEUE_URL = aws_sqs_queue.message_queue.url
    ENVIRONMENT   = var.environment
  }, local.current_config.environment_variables)

  lambda2_env_vars = merge({
    ENVIRONMENT = var.environment
  }, local.current_config.environment_variables)
}
