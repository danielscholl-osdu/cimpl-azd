# Alex — History

## Current State (v0.2.0, 2026-02-27)

**Deployed services (Phase 2 complete):**
- Partition — `software/stack/osdu.tf`, kustomize at `software/stack/kustomize/services/partition/`
- Entitlements — `software/stack/osdu.tf`, kustomize at `software/stack/kustomize/services/entitlements/`

**Deployment pattern established (PR #144).** Each service needs:
1. Module block in `software/stack/osdu.tf` (~20 lines)
2. Feature flag in `software/stack/variables.tf` (default: true)
3. Kustomize overlay at `software/stack/kustomize/services/<service>/`
4. Secrets in `software/stack/charts/osdu-common/main.tf` (coordinate with Amos)
5. SQL DDL in `software/stack/charts/postgresql/sql/` (most already exist)

**Remaining work:**
- Phase 3 (#145): Legal, Schema, Storage, Search, Indexer, File — 6 services
- Phase 4 (#146): Notification, Dataset, Register, Policy, Secret, Unit, Workflow — 7 services
- Phase 5 (#147): Wellbore, Wellbore Worker, CRS Conversion, CRS Catalog, EDS-DMS, Bootstrap Data — 6 services

**SQL DDL already exists for:** legal, schema, storage, file, dataset, register, workflow, well_delivery, reservoir, seismic

## Key Learnings (current)

### Service module pattern
- Don't override chart images — CIMPL charts have correct defaults with pinned tags
- Probes on port 8081 (`/health/liveness`, `/health/readiness`) — Spring Boot actuator management port
- Kustomize probes MUST target `type=core` Deployments only (not bootstrap)
- Helm timeout 900s for slow Java startup + liveness `initialDelaySeconds: 250`
- Bootstrap pods call service API to seed data after service is healthy
- Entitlements uses shared Redis via `extra_set` (`data.redisEntHost`)
- Each service has `preconditions` for dependency validation

### Keycloak integration
- Datafier secret: `OPENID_PROVIDER_CLIENT_ID`, `OPENID_PROVIDER_CLIENT_SECRET`, `OPENID_PROVIDER_URL`
- Service account email `datafier@service.local` required in JWT for entitlements auth
- Keycloak at `keycloak.platform.svc.cluster.local:8080`

### PostgreSQL integration
- Per-service databases with per-service schemas (e.g., `partition` schema in `partition` DB)
- JDBC URL needs `?currentSchema=<schema>` AND database needs `ALTER DATABASE SET search_path`
- CNPG endpoint: `postgresql-rw.platform.svc.cluster.local`

## Learnings

- Phase 5 services are added in `software/stack/osdu.tf` using the osdu-service module pattern with explicit `preconditions` and `depends_on` wiring.
- Per-service AKS safeguards overlays live at `software/stack/kustomize/services/<service>/` and copy the Partition probes/resources/seccomp pattern.
- Wellbore uses the `wellbore-postgres-secret` created in `software/stack/charts/osdu-common/main.tf` with the `well_delivery` database.
- New service feature flags belong in `software/stack/variables.tf` and default to `true` (opt-out model).

## ARCHIVED: OCI Registry Investigation (2025-07-18)

All OSDU service Helm charts pull from `oci://community.opengroup.org:5555/osdu/platform/...`. Chart version `0.0.7-latest` for most services. `helm registry login` required.

### Pinned Image Tags for Special Services
| Service | Image Name | Tag |
|---------|-----------|-----|
| Entitlements | `cimpl-entitlements-v2-release` | `da367b9f` |
| Workflow | `cimpl-workflow-release` | `f91c585a` |
| Wellbore | `cimpl-wellbore-release` | `f05e5a98` |
| Wellbore Worker | `cimpl-wellbore-worker-release` | `f7f46dc6` |
| EDS-DMS | `cimpl-eds-dms-release` | `f3df61a9` |

### Service Investigation Notes (preserved)
- All 24 CIMPL service modules have ZERO probes/resources/seccomp in Terraform — postrender required
- `rosa = true` flag in every service → set to `false` for AKS
- Every service has `bootstrap_sa` service account reference
- OETP server excluded from migration (disabled in ROSA)
- Policy service has unique OPA init container
- Wellbore unique — no `set_sensitive` for subscriberPrivateKeyId, has `wdms_workers.enabled`
