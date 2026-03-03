# Software Patterns

This page documents the Terraform architecture, deployment patterns, and configuration model used across the cimpl-azd software stack.

## Terraform Module Architecture

### Three-Layer State

The deployment uses three separate Terraform states (see [ADR-0006](../decisions/0006-two-layer-terraform-state.md)):

| State | Directory | Contents |
|-------|-----------|----------|
| Layer 1 | `infra/` | AKS cluster, resource group, RBAC, policy exemptions |
| Layer 2 | `software/foundation/` | Cluster-wide singletons: cert-manager, ECK operator, CNPG operator, ExternalDNS, Gateway CRDs, StorageClasses |
| Layer 3 | `software/stack/` | Middleware instances + OSDU services |

Layer 3 combines middleware and OSDU services in a single state because they share the same deployment lifecycle. OSDU services have explicit `depends_on` relationships with middleware modules. The foundation layer was extracted to hold cluster-wide singletons that are independent of any individual stack.

### Reusable OSDU Service Module

Each OSDU service is deployed via the `modules/osdu-service/` wrapper module (see [ADR-0015](../decisions/0015-osdu-service-module-and-sql-extraction.md)). This standardizes:

- Helm release creation with OCI chart reference
- Kustomize postrender integration
- Timeout and retry configuration
- Chart version management

A typical service definition is ~20 lines in the calling `.tf` file:

```hcl
module "partition" {
  source = "./modules/osdu-service"
  count  = var.enable_partition ? 1 : 0

  name            = "partition"
  namespace       = local.osdu_namespace
  chart_version   = local.osdu_versions["partition"]
  kustomize_dir   = "${path.module}/kustomize/services/partition"
  # ... values and dependencies
}
```

### Module Organization

```
software/foundation/charts/     # Layer 2: cluster-wide singletons
├── cert-manager/     # cert-manager + ClusterIssuers
├── elastic/          # ECK operator
├── cnpg/             # CNPG operator
└── external-dns/     # ExternalDNS

software/stack/modules/         # Layer 3: stack-specific resources
├── elastic/          # Elasticsearch + Kibana CRs + bootstrap
├── redis/            # Bitnami Redis chart
├── rabbitmq/         # Raw K8s manifests (StatefulSet, Services, ConfigMap)
├── minio/            # MinIO Helm chart
├── keycloak/         # Raw K8s manifests (StatefulSet, realm import)
├── airflow/          # Apache Airflow official chart
├── gateway/          # Gateway API resources + TLS certificates
├── osdu-common/      # OSDU namespace, ConfigMaps, secrets, mTLS policy
└── osdu-service/     # Reusable wrapper for individual OSDU Helm releases
```

---

## Helm + Kustomize Postrender

All Helm charts are deployed with a Kustomize postrender to ensure AKS safeguards compliance (see [ADR-0002](../decisions/0002-helm-postrender-kustomize-for-safeguards.md)).

### How It Works

```
Helm template → Kustomize patches → kubectl apply
                     │
                     ├── Add health probes
                     ├── Set resource limits
                     ├── Add seccomp profiles
                     ├── Harden security context
                     └── Fix service selectors
```

### Postrender Directory Structure

```
software/stack/kustomize/
├── middleware/
│   ├── elastic/         # ECK operator patches
│   ├── airflow/         # Airflow chart patches
│   └── ...
└── services/
    ├── partition/       # Partition service patches
    ├── entitlements/    # Entitlements service patches
    └── ...
```

Each directory contains a `kustomization.yaml` with strategic merge patches targeting specific Deployments (by `type=core` label for OSDU services).

### OSDU Service Probes

OSDU Java services use Spring Boot actuator on management port 8081:

- Liveness: `/health/liveness` on port 8081
- Readiness: `/health/readiness` on port 8081
- `initialDelaySeconds: 150-250` (Java startup time)

!!! warning
    Probes must target `type=core` Deployments only. OSDU charts include both a main app (`type: core`) and a bootstrap container (`type: bootstrap`). Patching bootstrap containers with health probes will break them.

---

## Feature Flag System

All middleware and OSDU services are controlled by `enable_*` boolean variables (see [Feature Flags](../getting-started/feature-flags.md) for the complete reference).

### Design Principles

- **Opt-out model**: Everything defaults to enabled. Set `TF_VAR_enable_<component>=false` to disable.
- **Two-level control**: Group flags (`enable_osdu_core_services`, `enable_osdu_reference_services`, `enable_osdu_domain_services`) disable entire capability blocks. Individual flags (`enable_partition`, `enable_search`, etc.) provide fine-grained opt-out within a group. See [ADR-0019](../decisions/0019-group-feature-flags-with-cascading-locals.md).
- **Cascading locals**: `locals.tf` computes `local.deploy_*` for each service as `group_flag && individual_flag`. Resource files reference `local.deploy_*` instead of `var.enable_*` for OSDU services. Platform middleware flags remain direct variable references.
- **Dependency cascade**: Reference and domain groups require core. Disabling core automatically disables downstream groups.
- **Clean environment**: No need to set flags for the default deployment.

### Example

```bash
# Deploy platform middleware only — no OSDU services
azd env set TF_VAR_enable_osdu_core_services false

# Or disable specific middleware and let dependency chains propagate
azd env set TF_VAR_enable_elasticsearch false
# Search and Indexer won't deploy since they depend on Elasticsearch
```

---

## Dependency Chain Management

OSDU services form a dependency graph. Terraform's `depends_on` and conditional `count` guards enforce the correct deployment order:

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

Each service waits for its dependencies to be healthy before deploying. Bootstrap containers call upstream APIs to seed initial data (e.g., Partition bootstrap registers the `osdu` data partition with all middleware endpoints).

---

## CNPG Database Bootstrapping

PostgreSQL databases are bootstrapped using a CNPG `initdb` script that creates 14 separate databases (one per OSDU service), matching the ROSA topology (see [ADR-0014](../decisions/0014-rosa-alignment-and-deliberate-differences.md)):

| Category | Databases |
|----------|-----------|
| OSDU core | partition, entitlements, legal, schema, storage, file, dataset, register, workflow |
| OSDU domain | seismic, reservoir, well_delivery |
| Non-OSDU | keycloak, airflow |

Each database has a service-specific schema with the standard OSM table pattern: `(id text, pk bigint IDENTITY, data jsonb NOT NULL)` + GIN index.

A shared `osdu` user owns all OSDU databases, a simplification from ROSA's per-service user model.

---

## Chart Version Management

OSDU services use CIMPL Helm charts from the OCI registry with chart-default images (see [ADR-0013](../decisions/0013-chart-default-images-over-explicit-overrides.md)):

```hcl
# Default version for all services
variable "osdu_chart_version" {
  default = "0.0.7-latest"
}

# Per-service overrides
variable "osdu_service_versions" {
  type    = map(string)
  default = {}
}
```

!!! tip
    Don't override chart images. CIMPL Helm charts have correct default images with pinned tags. ROSA reference overrides use different tags that may not exist.

---

## Secrets and Configuration

OSDU services discover middleware via Kubernetes secrets created by the `osdu-common` module:

| Secret | Service | Key Fields |
|--------|---------|------------|
| `partition-postgres-secret` | Partition | `OSM_POSTGRES_URL`, `OSM_POSTGRES_USERNAME`, `OSM_POSTGRES_PASSWORD` |
| `entitlements-multi-tenant-postgres-secret` | Entitlements | `ENT_PG_URL_SYSTEM`, `ENT_PG_USER_SYSTEM`, `ENT_PG_PASS_SYSTEM` |
| `wellbore-postgres-secret` | Wellbore | `OSM_POSTGRES_URL`, `OSM_POSTGRES_USERNAME`, `OSM_POSTGRES_PASSWORD` |
| `datafier-secret` | Entitlements bootstrap | `OPENID_PROVIDER_CLIENT_ID`, `OPENID_PROVIDER_CLIENT_SECRET`, `OPENID_PROVIDER_URL` |
| `entitlements-redis-secret` | Entitlements | `REDIS_PASSWORD` |

Secret key names align with ROSA conventions (see [ADR-0014](../decisions/0014-rosa-alignment-and-deliberate-differences.md)).
