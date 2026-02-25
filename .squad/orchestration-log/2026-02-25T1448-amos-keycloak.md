# Orchestration Log: Amos — Keycloak Deployment (Task #79)

**Date:** 2026-02-25 14:48 UTC  
**Agent:** Amos (gpt-5.2-codex)  
**Mode:** background  
**Task:** Issue #79 — Keycloak deployment on AKS  
**Outcome:** SUCCESS

## Files Created
- `platform/helm_keycloak.tf` — Helm release for Bitnami Keycloak chart with:
  - AKS safeguards compliance (probes, resources, seccomp)
  - Built-in realm import via ConfigMap mount
  - Istio PeerAuthentication for mTLS

## Files Updated
- `platform/variables.tf` — Added Keycloak input variables:
  - `keycloak_hostname` (string)
  - `keycloak_admin_password` (sensitive string)
  - `keycloak_realm_config` (object with realm JSON)

- `scripts/pre-provision.ps1` — Added validation for:
  - `TF_VAR_keycloak_hostname` environment variable
  - `TF_VAR_keycloak_admin_password` environment variable

## Decision Record
- File: `.squad/decisions/inbox/amos-keycloak.md`
- Title: "Decision: Keycloak realm import strategy"
- Summary: Use Keycloak's built-in realm import with ConfigMap mounting instead of risky keycloak-config-cli Job

## PR Opened
- #134 — "feat: Add Keycloak identity provider"

## Notes
- Realm import ConfigMap is populated with sample OSDU realm JSON
- JWKS endpoint is polled via init container to gate downstream services
- Follows existing AKS safeguards patterns (postrender not needed; Bitnami chart is already compliant)
