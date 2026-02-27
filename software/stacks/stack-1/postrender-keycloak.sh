#!/bin/sh
# Helm postrender script to apply kustomize patches to Keycloak
# Adds unique service selector labels for AKS Deployment Safeguards compliance (ADR-0010)

set -e

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required but not found in PATH" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kustomize/keycloak"

if [ ! -d "${KUSTOMIZE_DIR}" ]; then
    echo "Error: kustomize directory '${KUSTOMIZE_DIR}' does not exist." >&2
    exit 1
fi

HELM_OUTPUT=$(mktemp)
KUSTOMIZE_TEMP_DIR=$(mktemp -d)
cp -R "${KUSTOMIZE_DIR}/." "${KUSTOMIZE_TEMP_DIR}/"

trap 'rm -f "${HELM_OUTPUT}"; [ -n "${KUSTOMIZE_TEMP_DIR:-}" ] && rm -rf "${KUSTOMIZE_TEMP_DIR}"' EXIT

if ! cat > "${HELM_OUTPUT}"; then
    echo "Error: failed to read Helm output from stdin" >&2
    exit 1
fi

if [ ! -s "${HELM_OUTPUT}" ]; then
    echo "Error: no Helm output received on stdin" >&2
    exit 1
fi

cp "${HELM_OUTPUT}" "${KUSTOMIZE_TEMP_DIR}/all.yaml"

kubectl kustomize "${KUSTOMIZE_TEMP_DIR}"
