#!/bin/bash

# Script to build OpenTelemetry Collector layer
# This recreates the collector layer functionality in your account

set -e

LAYER_NAME="opentelemetry-collector"
REGION="eu-central-1"
COLLECTOR_VERSION="0.102.1"

echo "Building OpenTelemetry Collector layer..."

# Create build directory
mkdir -p build/opt/otelcollector

# Download OpenTelemetry Collector binary
echo "Downloading OpenTelemetry Collector binary..."
COLLECTOR_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${COLLECTOR_VERSION}/otelcol_${COLLECTOR_VERSION}_linux_amd64.tar.gz"

curl -L "$COLLECTOR_URL" | tar -xz -C build/opt/otelcollector

# Make sure binary is executable
chmod +x build/opt/otelcollector/otelcol

# Create wrapper script for Lambda extension
mkdir -p build/opt/extensions
cat > build/opt/extensions/otel-collector << 'EOF'
#!/bin/bash

# OpenTelemetry Collector Lambda Extension

set -euo pipefail

OWN_FILENAME="$(basename $0)"
LAMBDA_EXTENSION_NAME="$OWN_FILENAME" # (external) extension name has to match the filename
COLLECTOR_CONFIG_URI="${OPENTELEMETRY_COLLECTOR_CONFIG_URI:-/var/task/collector.yaml}"

# Graceful shutdown
_term() {
    echo "Received SIGTERM"
    # forward to child processes in process group
    kill -TERM -$$
    wait
    echo "Exited"
}

trap _term SIGTERM

# Lambda Runtime Interface
register() {
    HEADERS="$(mktemp)"
    curl -sS -LD "$HEADERS" -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2020-01-01/extension/register" \
        --header "Lambda-Extension-Name: ${LAMBDA_EXTENSION_NAME}" \
        --data-binary '{"events": ["INVOKE", "SHUTDOWN"]}'
    RESPONSE=$(cat "$HEADERS")
    EXTENSION_ID=$(echo "$RESPONSE" | grep -Fi Lambda-Extension-Identifier | tr -d '\r' | cut -d: -f2 | tr -d " ")
}

event_loop() {
    while true
    do
        HEADERS="$(mktemp)"
        EVENT_DATA=$(curl -sS -LD "$HEADERS" -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2020-01-01/extension/event/next" \
            --header "Lambda-Extension-Identifier: ${EXTENSION_ID}")
        
        EVENT=$(echo "$EVENT_DATA" | jq -r '.eventType')
        echo "[otel-collector] Received event: $EVENT"
        
        if [ "$EVENT" = "SHUTDOWN" ]; then
            echo "[otel-collector] Shutdown event received"
            break
        fi
    done
}

# Start collector in background
start_collector() {
    echo "[otel-collector] Starting OpenTelemetry Collector..."
    
    # Use config from environment or default location
    CONFIG_FILE="$COLLECTOR_CONFIG_URI"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "[otel-collector] Config file not found at $CONFIG_FILE"
        exit 1
    fi
    
    /opt/otelcollector/otelcol --config="$CONFIG_FILE" &
    COLLECTOR_PID=$!
    echo "[otel-collector] Collector started with PID $COLLECTOR_PID"
}

main() {
    echo "[otel-collector] Starting extension"
    
    # Start the collector
    start_collector
    
    # Register with Lambda Runtime
    register
    
    # Enter event loop
    event_loop
    
    # Cleanup
    echo "[otel-collector] Shutting down collector"
    kill $COLLECTOR_PID 2>/dev/null || true
    wait $COLLECTOR_PID 2>/dev/null || true
}

main
EOF

# Make wrapper executable
chmod +x build/opt/extensions/otel-collector

# Create zip file
cd build
zip -r ../otel-collector-layer.zip opt

cd ..
echo "Layer zip created: otel-collector-layer.zip"

# Publish layer to AWS
echo "Publishing collector layer to AWS..."
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --zip-file fileb://otel-collector-layer.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 python3.12 nodejs18.x nodejs20.x \
    --compatible-architectures x86_64 \
    --description "OpenTelemetry Collector Layer" \
    --region $REGION \
    --profile ProjectAdmin-339712788047 \
    --query 'LayerVersionArn' \
    --output text)

echo "Layer published: $LAYER_ARN"

# Clean up
rm -rf build otel-collector-layer.zip

echo "Collector layer ARN: $LAYER_ARN"