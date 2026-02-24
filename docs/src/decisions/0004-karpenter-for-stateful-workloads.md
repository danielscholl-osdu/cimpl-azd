---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Karpenter NodePools for Stateful Workload Scheduling

## Context and Problem Statement

Traditional VMSS-based AKS node pools pin a single VM SKU (e.g., `Standard_D4as_v5`) across all specified availability zones. When any zone lacks capacity for that exact SKU, `az aks create` fails with `OverconstrainedZonalAllocationRequest`. This is especially problematic for stateful workloads (Elasticsearch, PostgreSQL, RabbitMQ) that need premium storage-capable VMs and cross-zone spread.

## Decision Drivers

- Eliminate `OverconstrainedZonalAllocationRequest` failures on cluster creation and scaling
- Maintain cross-zone topology spread for HA stateful workloads
- Support premium storage (Premium_LRS) for Elasticsearch and PostgreSQL PVCs
- Keep the same workload targeting mechanism (`agentpool: stateful` label, `workload=stateful:NoSchedule` taint)

## Considered Options

- Karpenter/NAP with dynamic VM SKU selection
- Multiple VMSS node pools (one per zone)
- Single-zone deployment

## Decision Outcome

Chosen option: "Karpenter/NAP with dynamic VM SKU selection", because it dynamically selects from multiple D-series VM SKUs (4-8 vCPU, premium storage-capable) per zone, eliminating capacity failures while maintaining the same scheduling labels and taints.

### Consequences

- Good, because eliminates `OverconstrainedZonalAllocationRequest` — Karpenter selects any available D-series SKU per zone
- Good, because automatic scale-to-zero when no stateful pods are pending (cost savings)
- Good, because consolidation policy (`WhenEmpty`, 5 min) removes idle nodes automatically
- Good, because workloads use the same `agentpool: stateful` label and `workload=stateful:NoSchedule` toleration — no migration needed
- Bad, because Karpenter NodePool/AKSNodeClass CRDs are deployed in the platform layer, creating a dependency for all stateful workloads
- Bad, because VM SKU selection is less predictable — exact SKU varies by zone capacity at scheduling time
