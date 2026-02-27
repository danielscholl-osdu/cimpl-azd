#!/bin/bash
# Helm postrender script to apply kustomize patches to cert-manager
# This allows injecting health probes into the cainjector deployment
# which the upstream Helm chart doesn't support natively

set -e

# Verify kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is required but not found in PATH" >&2
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kustomize"

# Verify kustomize directory exists
if [ ! -d "${KUSTOMIZE_DIR}" ]; then
    echo "Error: kustomize directory '${KUSTOMIZE_DIR}' does not exist." >&2
    exit 1
fi

# Read Helm output from stdin and save to temporary file
HELM_OUTPUT=$(mktemp)

# Create a temporary kustomize directory to avoid concurrent access conflicts
KUSTOMIZE_TEMP_DIR=$(mktemp -d)
cp -R "${KUSTOMIZE_DIR}/." "${KUSTOMIZE_TEMP_DIR}/"

# Set up cleanup trap to ensure temporary files and directories are removed
trap 'rm -f "${HELM_OUTPUT}"; [ -n "${KUSTOMIZE_TEMP_DIR:-}" ] && rm -rf "${KUSTOMIZE_TEMP_DIR}"' EXIT

# Capture Helm output from stdin; fail if the read/write operation fails
if ! cat > "${HELM_OUTPUT}"; then
    echo "Error: failed to read Helm output from stdin" >&2
    exit 1
fi

# Ensure we actually received some Helm output
if [ ! -s "${HELM_OUTPUT}" ]; then
    echo "Error: no Helm output received on stdin" >&2
    exit 1
fi

# Copy Helm output to the temporary kustomize directory
cp "${HELM_OUTPUT}" "${KUSTOMIZE_TEMP_DIR}/all.yaml"

# Apply kustomize patches
kubectl kustomize "${KUSTOMIZE_TEMP_DIR}"
