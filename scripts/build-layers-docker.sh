#!/bin/bash

# Docker-based build for consistent layer creation
# This approach uses Docker to ensure consistent builds across environments

set -e

REGION="eu-central-1"
PYTHON_VERSION="3.9"

echo "Building OpenTelemetry layers using Docker..."

# Create Dockerfile for Python layer
cat > Dockerfile.python << 'EOF'
FROM public.ecr.aws/lambda/python:3.9

# Install OpenTelemetry packages
RUN pip install \
    opentelemetry-api==1.21.0 \
    opentelemetry-sdk==1.21.0 \
    opentelemetry-exporter-otlp==1.21.0 \
    opentelemetry-exporter-otlp-proto-grpc==1.21.0 \
    opentelemetry-exporter-otlp-proto-http==1.21.0 \
    opentelemetry-instrumentation==0.42b0 \
    opentelemetry-instrumentation-boto3sqs==0.42b0 \
    opentelemetry-instrumentation-botocore==0.42b0 \
    opentelemetry-instrumentation-logging==0.42b0 \
    opentelemetry-instrumentation-requests==0.42b0 \
    opentelemetry-instrumentation-urllib3==0.42b0 \
    opentelemetry-propagator-b3==1.21.0 \
    opentelemetry-distro==0.42b0 \
    --target /opt/python

# Create wrapper scripts
RUN mkdir -p /opt/bin
RUN echo '#!/bin/bash\nexport PYTHONPATH="/opt/python:$PYTHONPATH"\nexec opentelemetry-instrument "$@"' > /opt/otel-instrument
RUN echo '#!/bin/bash\nexport PYTHONPATH="/opt/python:$PYTHONPATH"\nexec opentelemetry-instrument "$@"' > /opt/otel-handler
RUN chmod +x /opt/otel-instrument /opt/otel-handler

# Create the layer structure
RUN mkdir -p /layer
RUN cp -r /opt /layer/

CMD ["tar", "czf", "/output/python-layer.tar.gz", "-C", "/layer", "."]
EOF

# Build Docker image and extract layer
docker build -f Dockerfile.python -t otel-python-layer .
mkdir -p output
docker run --rm -v $(pwd)/output:/output otel-python-layer

# Extract and create zip
cd output
tar xzf python-layer.tar.gz
zip -r otel-python-auto-layer.zip opt
cd ..

echo "Python layer created: output/otel-python-auto-layer.zip"

# Cleanup
rm Dockerfile.python
rm output/python-layer.tar.gz

echo "Layer ready for deployment!"
echo "To publish: aws lambda publish-layer-version --layer-name opentelemetry-python-auto --zip-file fileb://output/otel-python-auto-layer.zip --compatible-runtimes python3.9 --region $REGION"