#!/bin/bash

# Script to build OpenTelemetry Python auto-instrumentation layer
# This recreates the functionality of the community layer in your account

set -e

LAYER_NAME="opentelemetry-python-auto"
PYTHON_VERSION="3.9"
REGION="eu-central-1"

echo "Building OpenTelemetry Python auto-instrumentation layer..."

# Create build directory
mkdir -p build/python/lib/python${PYTHON_VERSION}/site-packages

# Install OpenTelemetry packages
pip3 install \
    --target build/python/lib/python${PYTHON_VERSION}/site-packages \
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
    opentelemetry-distro==0.42b0

# Create wrapper script for auto-instrumentation
mkdir -p build/opt
cat > build/opt/otel-instrument << 'EOF'
#!/bin/bash
export PYTHONPATH="/opt/python/lib/python3.9/site-packages:$PYTHONPATH"
exec /opt/python/bin/opentelemetry-instrument "$@"
EOF

# Make wrapper executable
chmod +x build/opt/otel-instrument

# Create Lambda runtime wrapper
cat > build/opt/otel-handler << 'EOF'
#!/bin/bash
export PYTHONPATH="/opt/python/lib/python3.9/site-packages:$PYTHONPATH"
exec /opt/python/bin/opentelemetry-instrument "$@"
EOF

# Make wrapper executable
chmod +x build/opt/otel-handler

# Copy the opentelemetry-instrument script
mkdir -p build/python/bin
cp build/python/lib/python${PYTHON_VERSION}/site-packages/bin/opentelemetry-instrument build/python/bin/ 2>/dev/null || \
find build/python/lib/python${PYTHON_VERSION}/site-packages -name "opentelemetry-instrument" -exec cp {} build/python/bin/ \; || \
cat > build/python/bin/opentelemetry-instrument << 'EOF'
#!/usr/bin/env python3
import sys
from opentelemetry.instrumentation.auto_instrumentation import run
if __name__ == '__main__':
    run()
EOF

chmod +x build/python/bin/opentelemetry-instrument

# Create zip file
cd build
zip -r ../otel-python-auto-layer.zip python opt

cd ..
echo "Layer zip created: otel-python-auto-layer.zip"

# Publish layer to AWS
echo "Publishing layer to AWS..."
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --zip-file fileb://otel-python-auto-layer.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 python3.12 \
    --compatible-architectures x86_64 arm64 \
    --description "OpenTelemetry Python Auto-instrumentation Layer" \
    --region $REGION \
    --profile ProjectAdmin-339712788047 \
    --query 'LayerVersionArn' \
    --output text)

echo "Layer published: $LAYER_ARN"

# Clean up
rm -rf build otel-python-auto-layer.zip

echo "Auto-instrumentation layer ARN: $LAYER_ARN"