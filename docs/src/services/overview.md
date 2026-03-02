# Service Catalog

cimpl-azd deploys OSDU platform services organized according to the [OSDU platform taxonomy](https://community.opengroup.org/osdu/platform). All services use the reusable `modules/osdu-service` Terraform wrapper and CIMPL Helm charts from the OCI registry.

## Service Summary

| Category | Count | Services | Default State |
|----------|-------|----------|---------------|
| **Core** | 13 | Partition, Entitlements, Legal, Schema, Storage, Search, Indexer, File, Notification, Dataset, Register, Policy, Secret | Enabled |
| **Reference** | 3 | CRS Conversion, CRS Catalog, Unit | Disabled |
| **Domain** | 3 | Wellbore, Wellbore Worker, EDS-DMS | Disabled |
| **Orchestration** | 1 | Workflow | Disabled |

Core services (13) are enabled by default — they form the minimum viable OSDU platform. Reference, domain, and orchestration services are opt-in via [feature flags](../getting-started/feature-flags.md).

## Deployment Pattern

Each OSDU service Helm chart includes:

1. **Core Deployment** (`type=core`) — the main Java service on port 8080 with health probes on management port 8081
2. **Bootstrap Deployment** (`type=bootstrap`) — seeds initial data by calling the service API after startup

Kustomize postrender patches add AKS-compliant probes, resource limits, seccomp profiles, and security context hardening. See [Software Patterns](../design/software.md) for details.

## Version Management

All services default to chart version `0.0.7-latest` (controlled by `osdu_chart_version`). Per-service overrides are available via the `osdu_service_versions` map variable.

## Dependency Graph

Services form a dependency chain — disabling an upstream service prevents dependent services from deploying:

```
PostgreSQL ──► Partition ──► Entitlements ──► Legal ──► Storage
                   │              │                        │
                   │              ├──► Schema               ├──► File
                   │              ├──► Search               ├──► Dataset
                   │              ├──► Indexer              └──► Register
                   │              ├──► Notification
                   │              └──► Policy, Secret
                   │
Keycloak ─────────┘
```

## Detailed Service Pages

- **[Core Services](core.md)** — The 13 services that form the minimum OSDU platform
- **[Reference & Domain Services](reference.md)** — Optional services for specialized OSDU capabilities
