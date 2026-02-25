# Orchestration Log: Naomi — Public Ingress Toggle (Task #69)

**Date:** 2026-02-25 14:48 UTC  
**Agent:** Naomi (gpt-5.2-codex)  
**Mode:** background  
**Task:** Issue #69 — Public vs private ingress configuration  
**Outcome:** SUCCESS

## Files Modified
- `platform/k8s_gateway.tf` — Updated Istio Gateway config:
  - Added conditional `disabled` field based on ingress toggle variable
  - Support for public HTTPS (port 443) and private HTTP (port 80) modes
  - Selector-based routing to aks-istio-ingressgateway

- `platform/variables.tf` — Added ingress control variable:
  - `enable_public_ingress` (boolean, default `true`)

- `scripts/pre-provision.ps1` — Added validation:
  - Optional check for public ingress flag

- `scripts/deploy-platform.ps1` — Added conditional deployment:
  - Gateway deployed only if `enable_public_ingress = true`

## Decision Record
- File: `.squad/decisions/inbox/naomi-public-ingress.md` (NOT YET CREATED)
- Expected content: Rationale for toggling ingress between public HTTPS and private modes

## PR Opened
- #132 — "feat: Add public ingress toggle for gateway configuration"

## Notes
- Allows environment-specific ingress strategy (public in production, private in dev)
- Maintains existing VirtualService routing regardless of gateway state
- Uses `disabled = true` to gracefully disable gateway without destroying resources
