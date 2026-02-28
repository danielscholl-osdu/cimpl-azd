---
status: accepted
contact: Daniel Scholl
date: 2026-02-27
deciders: Daniel Scholl
---

# Consolidated namespace architecture

## Context and Problem Statement

Kubernetes best practices often suggest one namespace per component for blast-radius isolation. However, the CIMPL deployment targets AKS Automatic, where Deployment Safeguards apply namespace-level policies and every namespace exclusion (for Gatekeeper) must be individually configured. Additionally, the platform must support multiple independent "stacks" on the same cluster (e.g., blue/green deployments for testing), where each stack needs its own set of middleware and services.

The original architecture used separate namespaces per component (`elasticsearch`, `postgresql`, `redis`, `rabbitmq`, `airflow`, `keycloak`). This created:

- 6+ namespace exclusions to manage for Gatekeeper policies
- Cross-namespace service discovery with full FQDNs everywhere
- No clean mechanism for multi-stack isolation (each stack would need 6+ uniquely named namespaces)

## Decision Drivers

- Multi-stack support: a `stack_id` suffix must cleanly produce isolated sets of resources
- AKS Deployment Safeguards: fewer namespaces = fewer exclusion configurations
- Istio sidecar injection is namespace-scoped (all-or-nothing)
- OSDU services need Istio mTLS; middleware generally does not (see ADR-0008)
- Terraform module organization: each module deploys into a namespace passed as a variable

## Considered Options

- **Per-component namespaces** — `elasticsearch`, `postgresql`, `redis`, `rabbitmq`, `airflow`, `keycloak`, `osdu`
- **Two consolidated namespaces** — `platform` (all middleware) + `osdu` (all OSDU services)
- **Single namespace** — everything in one namespace

## Decision Outcome

Chosen option: "Two consolidated namespaces", because the `platform` / `osdu` split aligns with the Istio injection boundary (OSDU services need sidecars, middleware does not) and provides clean multi-stack isolation via suffix (`platform-blue`, `osdu-blue`).

### Namespace layout

| Namespace | Contents | Istio Injection | Stack suffix example |
|-----------|----------|-----------------|---------------------|
| `platform` | Elasticsearch, PostgreSQL, Redis, RabbitMQ, MinIO, Keycloak, Airflow, cert-manager, Karpenter NodePool | Disabled | `platform-blue` |
| `osdu` | OSDU common resources (ConfigMap, secrets), Partition, Entitlements, and all future OSDU services | Enabled (STRICT mTLS) | `osdu-blue` |

### Service discovery

All cross-namespace references use fully-qualified service names computed from the namespace local:

```hcl
locals {
  platform_namespace = var.stack_id != "" ? "platform-${var.stack_id}" : "platform"
  osdu_namespace     = var.stack_id != "" ? "osdu-${var.stack_id}" : "osdu"
  postgresql_host    = "postgresql-rw.${local.platform_namespace}.svc.cluster.local"
  redis_host         = "redis-master.${local.platform_namespace}.svc.cluster.local"
  keycloak_host      = "keycloak.${local.platform_namespace}.svc.cluster.local"
}
```

### Node scheduling

All middleware and OSDU services share a single Karpenter `NodePool` named `platform`:

- **Toleration**: `workload=platform:NoSchedule`
- **NodeSelector**: `agentpool: platform`
- **VM SKUs**: D-series, 4-8 vCPU, premium storage capable

Lightweight workloads (MinIO, Airflow task pods) run on the auto-provisioned default pool with no tolerations.

### Consequences

- Good, because multi-stack isolation requires only 2 namespace suffixes, not 6+
- Good, because only 2 namespaces to configure for Gatekeeper exclusions
- Good, because Istio injection boundary matches the namespace boundary exactly
- Good, because OSDU services discover middleware via simple FQDN locals
- Neutral, because all middleware shares a failure domain — a bad deploy of one component can affect namespace-level resources (but Terraform guards this)
- Bad, because namespace-level RBAC is coarser (a user with access to `platform` can see all middleware secrets)
