#!/bin/bash

# Script to install OpenTelemetry packages locally for Lambda deployment using Docker
set -e

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "Installing OpenTelemetry packages for Lambda 1 using Docker..."
cd /Users/marcuseder/eon/code/otelALML/lambda1

# Remove existing packages directory
rm -rf packages

# Use Docker with Python 3.9 on x86_64 platform (matching Lambda runtime) to install packages
docker run --platform linux/amd64 --rm \
    -v "$PWD":/workspace \
    -w /workspace \
    python:3.9-slim \
    bash -c "pip install -r requirements.txt -t packages/ && chown -R $(id -u):$(id -g) packages/"

echo "Installing OpenTelemetry packages for Lambda 2 using Docker..."
cd /Users/marcuseder/eon/code/otelALML/lambda2

# Remove existing packages directory
rm -rf packages

# Use Docker with Python 3.9 on x86_64 platform (matching Lambda runtime) to install packages
docker run --platform linux/amd64 --rm \
    -v "$PWD":/workspace \
    -w /workspace \
    python:3.9-slim \
    bash -c "pip install -r requirements.txt -t packages/ && chown -R $(id -u):$(id -g) packages/"

echo "Packages installed successfully using Docker!"
echo "Lambda functions will now include OpenTelemetry packages built for Linux runtime."