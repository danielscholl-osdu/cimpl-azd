---
status: accepted
contact: Daniel Scholl
date: 2026-02-27
deciders: Daniel Scholl
---

# ROSA alignment with deliberate AKS differences

## Context and Problem Statement

CIMPL was originally deployed on Red Hat OpenShift (ROSA). Our AKS port must decide which ROSA patterns to replicate exactly and where to diverge intentionally. Without a documented alignment strategy, reviewers cannot distinguish "not yet ported" from "deliberately different."

During live ROSA cluster investigation, we catalogued the exact Kubernetes secret key names, JDBC URL formats, database topology, and infrastructure patterns used in production. This ADR records which patterns we align with and which we change, with rationale for each difference.

## Decision Drivers

- CIMPL Helm charts expect specific environment variable names injected via `envFrom` secrets
- Diverging from ROSA secret key names risks silent misconfiguration (app starts but fails at runtime)
- Some ROSA patterns (per-service Redis, per-service DB users) add complexity without benefit in a single-tenant AKS deployment
- AKS Automatic imposes different constraints than OpenShift (no NET_ADMIN, Deployment Safeguards, NAP)

## Decision Outcome

Align with ROSA conventions wherever chart compatibility is at stake (secret keys, database names, DDL). Diverge deliberately where AKS constraints or operational simplicity justify a different approach.

### Aligned with ROSA

| Area | Detail |
|------|--------|
| Secret key naming | `OSM_POSTGRES_URL`, `OSM_POSTGRES_USERNAME`, `OSM_POSTGRES_PASSWORD`, `PARTITION_POSTGRES_DB_NAME` for partition; `ENT_PG_*` + `SPRING_DATASOURCE_*` for entitlements |
| Database-level search_path | `ALTER DATABASE <db> SET search_path` instead of `?currentSchema=` in JDBC URLs |
| Separate databases | 14 databases (one per service), matching ROSA's `cimpl-postgres-infra-bootstrap` |
| DDL | Table definitions match ROSA bootstrap image (OSM pattern: `id text, pk bigint IDENTITY, data jsonb`) |
| Chart default images | Use chart-embedded pinned images, not explicit overrides (ADR-0013) |
| Helm chart source | OCI registry charts at their published versions |

### Deliberate differences from ROSA

| Difference | ROSA | AKS (Ours) | Rationale |
|------------|------|------------|-----------|
| Database users | Per-service users (e.g., `partition_user`) | Shared `osdu` user | Single-tenant simplification; CNPG manages HA and connection pooling. Per-service users add credential management complexity without security benefit in a single-cluster model. |
| Redis topology | Per-service Redis sidecars | Shared Redis cluster (`redis-master.redis.svc.cluster.local`) | Reduces resource overhead from ~10 Redis instances to 1 managed cluster. Can revisit if service isolation is needed. |
| PostgreSQL HA | Single managed instance | CloudNativePG (3-node HA) | AKS has no built-in managed PostgreSQL inside the cluster. CNPG provides HA with automated failover and backup. |
| Platform | OpenShift (ROSA) on AWS | AKS Automatic + managed Istio on Azure | Different cloud provider. AKS Automatic handles node provisioning via NAP/Karpenter. |
| Bootstrap pattern | Deployment (runs indefinitely) | Job (run-once with backoffLimit) | Jobs are idempotent and release resources after completion. ROSA uses Deployments for restart-on-failure, but our Jobs achieve the same via backoffLimit. |
| Schema naming | `entitlements_osdu_1` (multi-tenant convention) | `entitlements` (service name) | Single-tenant simplification. The schema name is stored in partition properties, so the app resolves it dynamically regardless of the actual name. |
| Security enforcement | OpenShift Security Context Constraints | AKS Deployment Safeguards (Gatekeeper) | Platform-specific enforcement. Postrender/kustomize patches handle compliance (ADR-0002). |

### Consequences

- Good, because aligned secret keys ensure CIMPL charts work without value overrides for environment variables
- Good, because deliberate differences are documented, preventing future "why is this different?" questions
- Good, because the shared-user and shared-Redis simplifications reduce operational overhead for single-tenant deployments
- Neutral, because future multi-tenant requirements may need per-service users and Redis instances
- Bad, because any ROSA chart update that adds new secret key expectations requires investigation
- Mitigation: compare ROSA secrets on each chart version bump as part of the upgrade checklist
