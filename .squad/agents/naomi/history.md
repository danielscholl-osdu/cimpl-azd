# Naomi — History

## Status: RETIRED (2026-02-27)

Infra layer complete and stable. Scope absorbed by Holden (Lead).

## What Was Delivered
- AKS Automatic cluster (K8s 1.32, Istio asm-1-28, Standard_D4lds_v5 system pool, zones 1 & 3)
- Karpenter `platform` NodePool for stateful workloads (D-series 4-8 vCPU)
- ExternalDNS with UAMI + federated credentials
- PowerShell deployment scripts (pre-provision, post-provision, pre-deploy)
- Two-phase deployment gate for Gatekeeper convergence (ADR-0005)
- Pre-down cleanup script for DNS record removal

## Key Learnings (preserved for future reference)
- Pre-down cleanup in `scripts/pre-down.ps1` identifies ExternalDNS-owned records via TXT stamps
- `infra/main.tfvars.json` must map DNS_ZONE_* variables for azd passthrough
- `scripts/pre-provision.ps1` sets both TF_VAR_dns_zone_* and DNS_ZONE_* env vars
- AKS Automatic overrides VM SKUs (e.g., Standard_D4s_v5 → Standard_D4lds_v5)
- OverconstrainedZonalAllocationRequest fixed by configurable availability zones
