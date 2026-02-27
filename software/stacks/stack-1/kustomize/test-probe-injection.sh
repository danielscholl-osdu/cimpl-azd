#!/bin/bash
# Validation script for ECK operator probe injection
# This script tests that the kustomize postrenderer correctly injects probes

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/.."

echo "=== Testing ECK Operator Probe Injection ==="
echo

# Test 1: Check that kustomize files exist
echo "[1/4] Checking kustomize files exist..."
if [ ! -f "$PLATFORM_DIR/kustomize/eck-operator/kustomization.yaml" ]; then
    echo "FAIL: kustomization.yaml not found"
    exit 1
fi
if [ ! -f "$PLATFORM_DIR/kustomize/eck-operator/statefulset-probes.yaml" ]; then
    echo "FAIL: statefulset-probes.yaml not found"
    exit 1
fi
if [ ! -x "$PLATFORM_DIR/kustomize/eck-operator-postrender.sh" ]; then
    echo "FAIL: eck-operator-postrender.sh not found or not executable"
    exit 1
fi
echo "  ✓ All files exist"
echo

# Test 2: Check that kustomize is installed
echo "[2/4] Checking kustomize is available..."
if ! command -v kustomize &> /dev/null; then
    echo "FAIL: kustomize not found in PATH"
    exit 1
fi
echo "  ✓ kustomize found: $(kustomize version --short 2>/dev/null || kustomize version)"
echo

# Test 3: Create a sample StatefulSet and test the postrenderer
echo "[3/4] Testing postrenderer with sample StatefulSet..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cat > "$TEMP_DIR/sample-sts.yaml" <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elastic-operator
  namespace: platform
spec:
  serviceName: elastic-operator
  replicas: 1
  selector:
    matchLabels:
      app: elastic-operator
  template:
    metadata:
      labels:
        app: elastic-operator
    spec:
      containers:
      - name: manager
        image: docker.elastic.co/eck/eck-operator:2.16.0
        ports:
        - containerPort: 9443
          name: webhook-server
        resources:
          requests:
            cpu: 100m
            memory: 150Mi
          limits:
            cpu: 1
            memory: 1Gi
EOF

OUTPUT=$(cat "$TEMP_DIR/sample-sts.yaml" | "$PLATFORM_DIR/kustomize/eck-operator-postrender.sh")

# Test 4: Verify probes were injected
echo "[4/4] Verifying probes were injected..."
if ! echo "$OUTPUT" | grep -q "livenessProbe:"; then
    echo "FAIL: livenessProbe not found in output"
    exit 1
fi
if ! echo "$OUTPUT" | grep -q "readinessProbe:"; then
    echo "FAIL: readinessProbe not found in output"
    exit 1
fi
if ! echo "$OUTPUT" | grep -q "tcpSocket:"; then
    echo "FAIL: tcpSocket probe type not found"
    exit 1
fi
if ! echo "$OUTPUT" | grep -q "port: 9443"; then
    echo "FAIL: probe port 9443 not found"
    exit 1
fi
echo "  ✓ Both livenessProbe and readinessProbe found"
echo "  ✓ tcpSocket probe type on port 9443"
echo

echo "=== All Tests Passed ==="
echo
echo "Summary:"
echo "  - Kustomize files are properly configured"
echo "  - Postrenderer script is executable"
echo "  - Probes are correctly injected into StatefulSet"
echo
