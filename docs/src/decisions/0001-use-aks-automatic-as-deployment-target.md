---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
consulted: Azure AKS documentation, AKS Automatic GA release notes
informed: Platform consumers, application developers
---

# Use AKS Automatic as Deployment Target

## Context and Problem Statement

The CIMPL platform needs a Kubernetes runtime on Azure that balances operational simplicity with enterprise security compliance. The platform hosts stateful services (Elasticsearch, PostgreSQL, RabbitMQ) alongside an Istio service mesh and must be deployable via `azd up` with minimal manual intervention. Choosing the wrong platform increases operational burden and delays delivery.

## Decision Drivers

- Minimize day-2 operational burden (patching, scaling, upgrades)
- Built-in security baseline without manual Gatekeeper policy authoring
- Managed Istio service mesh integration (no manual Istio installation)
- Cost optimization through automatic node provisioning (Karpenter/NAP)
- Single `azd up` deployment experience

## Considered Options

- AKS Automatic
- Standard AKS with manual Gatekeeper policies
- Azure Container Apps
- Red Hat OpenShift on Azure (ROSA-style)

## Decision Outcome

Chosen option: "AKS Automatic", because it provides the best balance of operational simplicity, built-in security, and managed Istio — all critical for a small team deploying a complex platform stack.

### Consequences

- Good, because auto-scaling, auto-upgrade, and auto-repair reduce operational toil
- Good, because Deployment Safeguards enforce security baseline (probes, resource limits, seccomp profiles) without manual policy authoring
- Good, because managed Istio (`asm-1-28`) provides service mesh without installation or lifecycle management
- Good, because Karpenter-based Node Auto-Provisioning (NAP) dynamically selects VM SKUs per zone, eliminating `OverconstrainedZonalAllocationRequest` failures
- Bad, because strict Deployment Safeguards require workarounds for every Helm chart that doesn't expose probe/resource/seccomp configuration — this is the single largest source of platform complexity
- Bad, because `NET_ADMIN` and `NET_RAW` capabilities are blocked, preventing Istio sidecar injection in some namespaces (e.g., RabbitMQ)
- Bad, because AKS Automatic overrides the system pool VM SKU (e.g., `Standard_D4s_v5` → `Standard_D4lds_v5`), causing Terraform drift if not matched
- Bad, because Azure Policy eventual consistency means fresh clusters need a deployment gate before platform workloads can be applied (see ADR-0005)

## Validation

- `kubectl get constrainttemplates` — verify Gatekeeper policies are active
- `az aks show --query "sku.name"` — confirm cluster is "Automatic"
- All pods running with `readinessProbe`, `livenessProbe`, resource `requests`/`limits`, and `seccompProfile: RuntimeDefault`

## Pros and Cons of the Options

### AKS Automatic

Fully managed Kubernetes with opinionated defaults, Deployment Safeguards, managed Istio, and Karpenter-based node provisioning.

- Good, because zero-touch node management (auto-scale, auto-upgrade, auto-repair)
- Good, because Deployment Safeguards enforce pod security baseline at admission
- Good, because managed Istio removes mesh lifecycle burden
- Good, because NAP (Karpenter) enables dynamic VM SKU selection per zone
- Neutral, because relatively new GA offering (less community documentation)
- Bad, because safeguards require postrender/kustomize workarounds for most Helm charts (see ADR-0002)
- Bad, because NET_ADMIN/NET_RAW blocked breaks Istio sidecar `istio-init` container (see ADR-0008)

### Standard AKS with Manual Gatekeeper

Traditional AKS with user-managed Gatekeeper policies and optional Istio add-on.

- Good, because full control over which policies are enforced
- Good, because can selectively exempt workloads without Azure Policy
- Bad, because requires authoring and maintaining Gatekeeper ConstraintTemplates
- Bad, because no automatic enforcement — policies can drift or be disabled
- Bad, because Istio add-on still available but node management is manual (VMSS pools)

### Azure Container Apps

Serverless container platform abstracting away Kubernetes.

- Good, because zero infrastructure management
- Good, because built-in Dapr integration
- Bad, because no support for StatefulSets (Elasticsearch, PostgreSQL, RabbitMQ)
- Bad, because no Istio service mesh or Gateway API
- Bad, because limited control over storage, networking, and scheduling

### Red Hat OpenShift on Azure (ARO)

Managed OpenShift with built-in security context constraints (SCCs).

- Good, because mature security model with SCCs
- Good, because built-in monitoring (Prometheus/Grafana)
- Neutral, because reference architecture exists (ROSA OSDU deployment)
- Bad, because significantly higher cost per cluster
- Bad, because heavier operational overhead (OpenShift-specific tooling)
- Bad, because not aligned with Azure-native tooling (`azd`, Azure RBAC)

## More Information

- [AKS Automatic documentation](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic)
- [Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)
- Related: [ADR-0002](0002-helm-postrender-kustomize-for-safeguards.md) (postrender pattern), [ADR-0005](0005-two-phase-deployment-gate.md) (deployment gate), [ADR-0008](0008-selective-istio-sidecar-injection.md) (Istio constraints)
