# Naomi — Infra Dev (RETIRED)

## Status
**Retired as of v0.2.0.** The infra layer is stable and requires no active development. Naomi's scope (AKS cluster config, Karpenter, networking) has been absorbed by Holden (Lead).

## Original Role
Infrastructure specialist who owned the AKS cluster layer (`infra/`) and cloud-level resources.

## What Was Built (complete)
- AKS Automatic cluster (K8s 1.32, SKU Automatic, Standard tier)
- Istio asm-1-28 managed mesh
- Karpenter `platform` NodePool (D-series 4-8 vCPU) at `software/stack/main.tf`
- Azure CNI Overlay + Cilium networking
- System pool: Standard_D4lds_v5, zones 1 & 3
- ExternalDNS UAMI + federated credentials
- PowerShell deployment scripts (`scripts/*.ps1`)
- Two-phase deployment gate for Gatekeeper convergence

## Key Files (for reference)
- `infra/aks.tf` — AKS cluster definition
- `infra/variables.tf` — Cluster input variables
- `infra/outputs.tf` — Outputs consumed by software/stack layer
- `scripts/pre-provision.ps1` — Pre-provision validation & env defaults
- `scripts/post-provision.ps1` — Safeguards readiness gate
- `scripts/pre-deploy.ps1` — Stack Terraform apply

## Reactivation Criteria
Reactivate Naomi if:
- AKS version upgrade is needed
- Karpenter NodePool changes required
- Networking or RBAC changes needed
- New infra-level resources (Key Vault, storage accounts, etc.)
