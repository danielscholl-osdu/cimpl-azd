#!/bin/sh
# Helm postrender script to apply kustomize patches to PostgreSQL
# This adds unique labels to differentiate service selectors for AKS policy compliance
# (K8sAzureV1UniqueServiceSelector requires unique selectors per service)

set -e

# Verify kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required but not found in PATH" >&2
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kustomize/postgresql"

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

# Capture Helm output from stdin
if ! cat > "${HELM_OUTPUT}"; then
    echo "Error: failed to read Helm output from stdin" >&2
    exit 1
fi

# Ensure we actually received some Helm output
if [ ! -s "${HELM_OUTPUT}" ]; then
    echo "Error: no Helm output received on stdin" >&2
    exit 1
fi

# Basic validation of Helm-rendered YAML to catch obvious issues early
if ! grep -qE '^[[:space:]]*apiVersion:[[:space:]]+[A-Za-z0-9./-]+' "${HELM_OUTPUT}"; then
    echo "Error: Helm output does not appear to contain valid Kubernetes resources (missing apiVersion)" >&2
    exit 1
fi

if ! grep -qE '^[[:space:]]*kind:[[:space:]]+[A-Za-z0-9]+' "${HELM_OUTPUT}"; then
    echo "Error: Helm output does not appear to contain valid Kubernetes resources (missing kind)" >&2
    exit 1
fi

# Copy Helm output to the temporary kustomize directory
cp "${HELM_OUTPUT}" "${KUSTOMIZE_TEMP_DIR}/all.yaml"

# Apply kustomize patches
kubectl kustomize "${KUSTOMIZE_TEMP_DIR}"
