#!/bin/bash

# Master script to build both OpenTelemetry layers and update Terraform configuration

set -e

REGION="eu-central-1"
ACCOUNT_ID=$(aws --profile ProjectAdmin-339712788047 sts get-caller-identity --query Account --output text)

echo "Building OpenTelemetry layers for account: $ACCOUNT_ID in region: $REGION"

# Build auto-instrumentation layer
echo "=== Building Python Auto-instrumentation Layer ==="
./build-otel-python-layer.sh

# Build collector layer  
echo "=== Building Collector Layer ==="
./build-otel-collector-layer.sh

echo "=== Layers built successfully! ==="

# Get the layer ARNs (they will be version 1 since they're new)
PYTHON_LAYER_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:layer:opentelemetry-python-auto:1"
COLLECTOR_LAYER_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:layer:opentelemetry-collector:1"

echo "Python Auto Layer ARN: $PYTHON_LAYER_ARN"
echo "Collector Layer ARN: $COLLECTOR_LAYER_ARN"

# Update Terraform locals.tf with new layer ARNs
echo "=== Updating Terraform configuration ==="

# Create a temporary file with the updated locals.tf
cat > ../terraform/locals_update.tf << EOF
# Update these lines in your locals.tf:

# Replace the community_otel_auto and community_otel_collector lines with:
    community_otel_auto = "$PYTHON_LAYER_ARN"
    community_otel_collector = "$COLLECTOR_LAYER_ARN"
EOF

echo "Layer ARNs saved to terraform/locals_update.tf"
echo "Please update your terraform/locals.tf with these ARNs:"
echo "  community_otel_auto = \"$PYTHON_LAYER_ARN\""
echo "  community_otel_collector = \"$COLLECTOR_LAYER_ARN\""