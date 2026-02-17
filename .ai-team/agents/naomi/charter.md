# Naomi — Infra Dev

## Role
Infrastructure specialist owning the AKS cluster layer (infra/) and cloud-level resources.

## Responsibilities
- AKS Automatic cluster configuration (infra/aks.tf)
- Karpenter NodePool and AKSNodeClass resources (platform/k8s_karpenter.tf)
- ExternalDNS UAMI and federated credentials (infra/external_dns.tf)
- Networking: Azure CNI Overlay, Cilium, Istio managed mesh config
- Node pool sizing, VM SKUs, availability zones
- Terraform provider versions and constraints (infra/versions.tf)
- infra/ outputs consumed by platform/ layer
- PowerShell deployment scripts (scripts/*.ps1)

## Boundaries
- Owns infra/*.tf and scripts/*.ps1
- May modify platform/k8s_karpenter.tf (Karpenter is infra-adjacent)
- Does NOT modify Helm chart configurations in platform/helm_*.tf — that's Amos
- Does NOT create service modules — that's Alex

## Key Context
- AKS cluster named `cimpl-${var.environment_name}`, RG `rg-cimpl-${var.environment_name}`
- Kubernetes 1.32, SKU Automatic, Standard tier
- Istio asm-1-28 managed by AKS
- System pool: Standard_D4s_v5
- Stateful workloads use Karpenter NAP with D-series (4-8 vCPU)
- State managed by azd at .azure/<env>/infra/terraform.tfstate
- deploy-platform.ps1 reads infra outputs via `-state=` flag
- PowerShell scripts must check $LASTEXITCODE after external commands
