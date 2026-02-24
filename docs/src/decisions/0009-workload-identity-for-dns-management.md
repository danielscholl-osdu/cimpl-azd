---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Workload Identity for Cross-Subscription DNS Management

## Context and Problem Statement

ExternalDNS needs to create and manage DNS records in an Azure DNS zone that may reside in a different subscription than the AKS cluster. The identity mechanism must work reliably on AKS Automatic (which uses multiple managed identities) and support cross-subscription resource access without storing static credentials in the cluster.

## Decision Drivers

- DNS zone may be in a different subscription than the AKS cluster
- AKS Automatic assigns multiple managed identities — IMDS-based identity is ambiguous
- No static credentials (service principal secrets) should be stored in Kubernetes
- Must integrate with ExternalDNS's Azure provider configuration
- Federated credentials provide a zero-secret authentication path

## Considered Options

- Workload Identity with federated credentials
- IMDS-based managed identity (`useManagedIdentityExtension`)
- Static service principal credentials in Kubernetes Secret

## Decision Outcome

Chosen option: "Workload Identity with federated credentials", because it provides secure, cross-subscription DNS management without stored secrets, and works reliably on AKS Automatic where IMDS-based identity fails due to multiple managed identities.

### Consequences

- Good, because zero stored secrets — federated credential exchange happens at token request time
- Good, because cross-subscription capable — the managed identity can be granted DNS Zone Contributor on any subscription
- Good, because explicit identity binding — ServiceAccount annotation specifies exactly which client ID to use
- Good, because AKS Automatic compatible — does not rely on IMDS, which is ambiguous with multiple identities
- Bad, because requires infrastructure setup outside the platform layer (managed identity, federated credential, role assignment)
- Bad, because requires `type = "string"` on the Helm `set` for `azure.workload.identity/use: "true"` pod label to prevent Helm from interpreting it as a boolean
