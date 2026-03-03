# Service Catalog

This page answers three questions: what gets deployed by default, how each service is packaged, and what depends on what.

cimpl-azd deploys OSDU platform services organized according to the [OSDU platform taxonomy](https://community.opengroup.org/osdu/platform). All services use the reusable `modules/osdu-service` Terraform wrapper and CIMPL Helm charts from the OCI registry.

## Service Summary

| Category | Count | Services | Default State |
|----------|-------|----------|---------------|
| **Core** | 13 | Partition, Entitlements, Legal, Schema, Storage, Search, Indexer, File, Notification, Dataset, Register, Policy, Secret | Enabled |
| **Reference** | 3 | CRS Conversion, CRS Catalog, Unit | Disabled |
| **Domain** | 3 | Wellbore, Wellbore Worker, EDS-DMS | Disabled |
| **Orchestration** | 1 | Workflow | Disabled |

Core services (13) are enabled by default; they form the minimum viable OSDU platform. Reference, domain, and orchestration services are opt-in via [feature flags](../getting-started/feature-flags.md).

## Service Reference

| Service | Category | Enabled | Namespace | Primary Dependency | Feature Flag |
|---------|----------|---------|-----------|-------------------|--------------|
| Partition | Core | Yes | `osdu` | PostgreSQL, Keycloak | `enable_partition` |
| Entitlements | Core | Yes | `osdu` | Partition | `enable_entitlements` |
| Legal | Core | Yes | `osdu` | Entitlements | `enable_legal` |
| Schema | Core | Yes | `osdu` | Entitlements | `enable_schema` |
| Storage | Core | Yes | `osdu` | Legal | `enable_storage` |
| Search | Core | Yes | `osdu` | Entitlements | `enable_search` |
| Indexer | Core | Yes | `osdu` | Entitlements | `enable_indexer` |
| File | Core | Yes | `osdu` | Storage | `enable_file` |
| Notification | Core | Yes | `osdu` | Entitlements | `enable_notification` |
| Dataset | Core | Yes | `osdu` | Storage | `enable_dataset` |
| Register | Core | Yes | `osdu` | Storage | `enable_register` |
| Policy | Core | Yes | `osdu` | Entitlements | `enable_policy` |
| Secret | Core | Yes | `osdu` | Entitlements | `enable_secret` |
| Workflow | Orchestration | No | `osdu` | Entitlements, Airflow | `enable_workflow` |
| CRS Conversion | Reference | No | `osdu` | Entitlements | `enable_crs_conversion` |
| CRS Catalog | Reference | No | `osdu` | Entitlements | `enable_crs_catalog` |
| Unit | Reference | No | `osdu` | Entitlements | `enable_unit` |
| Wellbore | Domain | No | `osdu` | Storage | `enable_wellbore` |
| Wellbore Worker | Domain | No | `osdu` | Wellbore | `enable_wellbore_worker` |
| EDS-DMS | Domain | No | `osdu` | Storage | `enable_eds_dms` |

## Deployment Pattern

Each OSDU service Helm chart includes:

1. **Core Deployment** (`type=core`): the main Java service on port 8080 with health probes on management port 8081
2. **Bootstrap Deployment** (`type=bootstrap`): seeds initial data by calling the service API after startup

Kustomize postrender patches add AKS-compliant probes, resource limits, seccomp profiles, and security context hardening. See [Software Patterns](../design/software.md) for details.

## Version Management

All services default to chart version `0.0.7-latest` (controlled by `osdu_chart_version`). Per-service overrides are available via the `osdu_service_versions` map variable.

**When to use each:**

- **Global version (`osdu_chart_version`)**: use when upgrading all services together. This is the default path and keeps all services on the same chart version.
- **Per-service overrides (`osdu_service_versions`)**: use when a single service needs a different chart version, e.g., testing a pre-release chart or pinning a service that has a known regression in the latest version.

!!! warning "Mixed version risk"
    Running services on different chart versions increases operational complexity. Bootstrap containers and service APIs may have cross-version compatibility issues. Prefer upgrading all services together unless you have a specific reason to diverge.

## Dependency Graph

Services form a dependency chain. Disabling an upstream service prevents dependent services from deploying:

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

**Dependency types:**

- **Auth dependency** (→ Entitlements): the service calls Entitlements for authorization checks. All services except Partition depend on Entitlements.
- **Database dependency** (→ PostgreSQL): the service has its own database in the shared PostgreSQL cluster. Every OSDU service has a database dependency.
- **Data dependency** (→ Storage/Legal): the service reads or writes through the Storage or Legal APIs.

## Detailed Service Pages

- **[Core Services](core.md)**: The 13 services that form the minimum OSDU platform
- **[Reference & Domain Services](reference.md)**: Optional services for specialized OSDU capabilities
