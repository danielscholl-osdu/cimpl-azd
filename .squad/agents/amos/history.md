# Amos — History

## Current State (v0.2.0, 2026-02-27)

**All middleware deployed and healthy in `platform` namespace:**
- Elasticsearch 8.15.2 (3-node, ECK-managed, green)
- PostgreSQL 17 (3-instance CNPG HA, `postgresql-rw.platform.svc.cluster.local`)
- Redis (single instance, `redis-master.platform.svc.cluster.local`)
- RabbitMQ 4.1.0 (3-node, raw manifests — ADR-0003)
- MinIO (single instance, `minio.platform.svc.cluster.local`)
- Keycloak 26.5.4 (raw manifests — ADR-0016, `keycloak.platform.svc.cluster.local:8080`)
- Airflow 3.x (official Apache chart, KubernetesExecutor, shares Redis — default disabled)
- cert-manager 1.16.2
- Gateway API + TLS

**OSDU common resources deployed (`osdu` namespace):**
- Namespace with Istio STRICT mTLS
- Partition and Entitlements secrets (postgres, redis, datafier)
- Shared ConfigMaps

**Key architecture changes since initial work:**
- Keycloak: switched from Bitnami Helm chart to raw manifests (ADR-0016). Official image at `/opt/keycloak/`, UID 1000, `KC_*` env vars. Realm import includes `datafier` client + service account with email.
- Namespaces: consolidated from per-component to `platform` + `osdu` (ADR-0017)
- NodePool: renamed from `stateful` to `platform`
- All paths moved from `platform/` to `software/stack/charts/`

## Remaining Work
- Add conditional secrets to `software/stack/charts/osdu-common/main.tf` as Alex onboards new services
- SQL DDL templates in `software/stack/charts/postgresql/sql/` — most already exist

## ARCHIVED Learnings (pre-refactor, paths are stale)

### 2026-03-12: Keycloak on AKS — **SUPERSEDED by ADR-0016**
_Original Bitnami approach abandoned. Now uses raw manifests. See ADR-0016 for current implementation._

### 2025-07-18: Common Chart Investigation
- ROSA `common-infra-bootstrap` is a namespace/config bootstrap. On AKS, equivalent is `software/stack/charts/osdu-common/main.tf`.

### 2025-07-18: Elastic Bootstrap Investigation
- Post-deploy initialization job configuring ES index templates, ILM policies, aliases. Implemented at `software/stack/charts/elastic/` as part of the ECK stack.

### 2026-03-05: Airflow deployment patterns
- Official Apache Airflow Helm chart with external Redis and CNPG PostgreSQL. KubernetesExecutor. Implemented at `software/stack/charts/airflow/main.tf`.
