#!/usr/bin/env bash
# Helm postrender script to apply kustomize patches for a service

set -e

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is required but not found in PATH" >&2
  exit 1
fi

if [ -z "${SERVICE_NAME:-}" ]; then
  echo "Error: SERVICE_NAME environment variable is required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_ROOT="${SCRIPT_DIR}"
SERVICE_DIR="${KUSTOMIZE_ROOT}/services/${SERVICE_NAME}"

if [ ! -d "${SERVICE_DIR}" ]; then
  echo "Error: kustomize service directory '${SERVICE_DIR}' does not exist." >&2
  exit 1
fi

HELM_OUTPUT=$(mktemp)
KUSTOMIZE_TEMP_DIR=$(mktemp -d)

trap 'rm -f "${HELM_OUTPUT}"; [ -n "${KUSTOMIZE_TEMP_DIR:-}" ] && rm -rf "${KUSTOMIZE_TEMP_DIR}"' EXIT

if ! cat > "${HELM_OUTPUT}"; then
  echo "Error: failed to read Helm output from stdin" >&2
  exit 1
fi

if [ ! -s "${HELM_OUTPUT}" ]; then
  echo "Error: no Helm output received on stdin" >&2
  exit 1
fi

mkdir -p "${KUSTOMIZE_TEMP_DIR}/components" "${KUSTOMIZE_TEMP_DIR}/services/${SERVICE_NAME}"
cp -R "${KUSTOMIZE_ROOT}/components/." "${KUSTOMIZE_TEMP_DIR}/components/"
cp -R "${SERVICE_DIR}/." "${KUSTOMIZE_TEMP_DIR}/services/${SERVICE_NAME}/"
cp "${HELM_OUTPUT}" "${KUSTOMIZE_TEMP_DIR}/services/${SERVICE_NAME}/all.yaml"

while IFS= read -r -d '' file; do
  perl -pi -e "s/__SERVICE_NAME__/${SERVICE_NAME}/g" "$file"
done < <(find "${KUSTOMIZE_TEMP_DIR}" -type f -name '*.yaml' -print0)

kubectl kustomize "${KUSTOMIZE_TEMP_DIR}/services/${SERVICE_NAME}"
