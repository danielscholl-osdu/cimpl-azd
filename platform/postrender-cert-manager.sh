#!/bin/bash
# Helm postrender script to apply kustomize patches to cert-manager
# This allows injecting health probes into the cainjector deployment
# which the upstream Helm chart doesn't support natively

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kustomize/cert-manager"

# Read Helm output from stdin and save to temporary file
HELM_OUTPUT=$(mktemp)
cat > "${HELM_OUTPUT}"

# Copy Helm output to kustomize directory
cp "${HELM_OUTPUT}" "${KUSTOMIZE_DIR}/all.yaml"

# Apply kustomize patches
kubectl kustomize "${KUSTOMIZE_DIR}"

# Clean up
rm -f "${HELM_OUTPUT}" "${KUSTOMIZE_DIR}/all.yaml"
