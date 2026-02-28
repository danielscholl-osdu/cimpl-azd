#!/bin/sh
# Helm postrenderer script for ECK operator
# This script applies kustomize patches to inject health probes for AKS Automatic safeguards compliance

set -e

# Verify kubectl is available (kubectl kustomize is bundled with kubectl)
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required but not found in PATH" >&2
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KUSTOMIZE_DIR="$SCRIPT_DIR/kustomize"

# Create a temporary directory for kustomize processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Save stdin (Helm chart output) to a file
cat > "$TEMP_DIR/all.yaml"

# Create a temporary kustomization that includes the Helm output
cat > "$TEMP_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - all.yaml

patches:
  - path: statefulset-probes.yaml
    target:
      kind: StatefulSet
      name: elastic-operator
EOF

# Copy the patch file to the temp directory
cp "$KUSTOMIZE_DIR/statefulset-probes.yaml" "$TEMP_DIR/"

# Apply kustomize and output the result (using kubectl kustomize which is bundled with kubectl)
kubectl kustomize "$TEMP_DIR"
