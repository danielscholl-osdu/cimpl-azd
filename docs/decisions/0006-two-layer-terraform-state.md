---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Two-Layer Terraform State for Cluster and Platform

## Context and Problem Statement

The CIMPL deployment includes both Azure infrastructure (AKS cluster, resource group, RBAC) and Kubernetes platform workloads (Helm releases, CRDs, namespaces). These have fundamentally different change frequencies and blast radii — a Helm chart upgrade should not risk the AKS cluster, and a cluster-level change should not trigger re-evaluation of every Kubernetes resource. We need a state management strategy that isolates these concerns.

## Decision Drivers

- Cluster infrastructure changes are infrequent and high-risk
- Platform workload changes are frequent and lower-risk
- `azd up` must orchestrate both layers in the correct order
- Cross-layer values (cluster name, OIDC issuer URL, resource group) must flow from infra to platform
- Blast radius of a `terraform destroy` must be containable per layer

## Considered Options

- Two separate Terraform states (infra/ and platform/)
- Single monolithic Terraform state
- Terraform workspaces

## Decision Outcome

Chosen option: "Two separate Terraform states", because it provides independent lifecycles, reduces blast radius, and aligns with the natural boundary between Azure infrastructure and Kubernetes workloads.

### Consequences

- Good, because `terraform apply` in platform/ cannot accidentally modify or destroy the AKS cluster
- Good, because platform changes are fast — Terraform only evaluates Helm releases and K8s resources, not Azure ARM resources
- Good, because each layer can be independently planned, applied, and destroyed
- Good, because aligns with azd hooks: infra/ managed by `azd provision`, platform/ managed by `scripts/deploy-platform.ps1`
- Bad, because cross-layer values must be explicitly passed via environment variables or `terraform output` commands in scripts
- Bad, because two `terraform.tfstate` files to manage (infra state at `.azure/<env>/infra/terraform.tfstate`, platform state at `platform/terraform.tfstate`)
- Bad, because debugging requires understanding which layer owns each resource
