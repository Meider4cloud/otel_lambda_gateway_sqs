#!/bin/bash

# Script to build OpenTelemetry layers locally (without AWS publishing)
# Run this first, then publish manually with AWS CLI

set -e

PYTHON_VERSION="3.9"

echo "Building OpenTelemetry Python auto-instrumentation layer..."

# Clean up any previous builds
rm -rf build otel-*.zip

# Create build directory
mkdir -p build/python/lib/python${PYTHON_VERSION}/site-packages

# Install OpenTelemetry packages
echo "Installing OpenTelemetry packages..."
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
echo "Creating layer zip file..."
cd build
zip -r ../otel-python-auto-layer.zip python opt

cd ..
echo "Layer zip created: otel-python-auto-layer.zip"

# Get file size
SIZE=$(ls -lh otel-python-auto-layer.zip | awk '{print $5}')
echo "Layer size: $SIZE"

# Clean up build directory
rm -rf build

echo ""
echo "✅ Python auto-instrumentation layer built successfully!"
echo ""
echo "To publish this layer to AWS:"
echo "aws lambda publish-layer-version \\"
echo "  --layer-name opentelemetry-python-auto \\"
echo "  --zip-file fileb://otel-python-auto-layer.zip \\"
echo "  --compatible-runtimes python3.9 python3.10 python3.11 python3.12 \\"
echo "  --compatible-architectures x86_64 \\"
echo "  --description 'OpenTelemetry Python Auto-instrumentation Layer' \\"
echo "  --profile ProjectAdmin-339712788047 \\"
echo "  --region eu-central-1"