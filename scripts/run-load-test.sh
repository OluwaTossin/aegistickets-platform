#!/bin/bash
set -e

echo "🔬 AegisTickets Load Test Runner"
echo "================================"
echo ""

# Configuration
TEST_TYPE=${1:-happy}
TARGET_HOST=${2}

if [ -z "$TARGET_HOST" ]; then
  echo "Error: Target host not specified"
  echo "Usage: ./run-load-test.sh [happy|stress] <ALB_DNS>"
  echo "Example: ./run-load-test.sh happy http://my-alb-123.eu-west-1.elb.amazonaws.com"
  exit 1
fi

if [ "$TEST_TYPE" != "happy" ] && [ "$TEST_TYPE" != "stress" ]; then
  echo "Error: Test type must be 'happy' or 'stress'"
  exit 1
fi

echo "Test Type: $TEST_TYPE"
echo "Target Host: $TARGET_HOST"
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
  echo "❌ k6 is not installed"
  echo "Install: https://k6.io/docs/getting-started/installation/"
  exit 1
fi

echo "🚀 Starting load test..."
echo ""

# Run test
k6 run --env HOST=$TARGET_HOST scripts/${TEST_TYPE}.js

echo ""
echo "✅ Load test complete!"
echo ""
echo "Review metrics above or check Grafana dashboards:"
echo "  - Golden Signals dashboard"
echo "  - SLO Overview dashboard"
echo ""
