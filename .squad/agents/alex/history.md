# Alex — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl
- ~20 OSDU services to port from reference-rosa/terraform/master-chart/services/
- Services: partition, entitlements, legal, indexer, search, schema, storage, dataset, notification, file, register, policy, secret, unit, workflow, wellbore, wellbore-worker, CRS conversion, CRS catalog, OETP server, EDS-DMS
- ROSA uses OCI registry at community.opengroup.org:5555
- Service dependency chain: Common → PostgreSQL/Elastic → Keycloak → Services
- AKS safeguards: all containers need probes, resources, seccomp, pinned image tags
- Helm provider v3 syntax required

## Team Updates

📌 **2026-02-17:** ROSA parity gap analysis complete (Holden) — Gap analysis identified all ~22 OSDU services as missing from AKS. Key findings: 4 missing infra components (Common, Keycloak, RabbitMQ, Airflow); AKS-managed Istio vs ROSA self-managed requires service chart adaptation (no istio-init, no ambient mode); service namespace strategy and PostgreSQL RW endpoint updates needed.

📌 **2026-02-17:** User directives clarified (Daniel Scholl) — Keycloak required (cannot use Entra ID); RabbitMQ required by OSDU services directly; Airflow can share existing Redis; Elasticsearch already running (need to investigate Elastic Bootstrap status).

## Learnings

### 2025-07-18: Deep Investigation of CIMPL Service Charts (Q5/Q8/Q9/Q10)

**Q5 — OCI Registry Access:**
- All OSDU service Helm charts pull from OCI registry: `oci://community.opengroup.org:5555/osdu/platform/...`
- Each service module has its own repository path, e.g.:
  - partition: `oci://community.opengroup.org:5555/osdu/platform/system/partition/cimpl-helm`
  - entitlements: `oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/entitlements/cimpl-helm`
  - legal: `oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/cimpl-helm`
  - OETP server/client: `oci://community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/reservoir/open-etp-server/cimpl-helm`
- Chart versions: Almost all services use `0.0.7-latest` as the chart version. Only exception: entitlements uses `0.0.7-cimpl993f5ece` and OETP server uses `0.29.0-release`.
- Container images: **Every single service module defaults to `:latest` tags** (e.g., `cimpl-partition-master:latest`). However, the top-level `variables.tf` provides pinned commit-hash tags as overrides (e.g., `core-plus-partition-release:67dedce7`), meaning ROSA was ALSO meant to use pinned tags at deployment time, just not in module defaults.

**Q8 — Probes/Resources/Seccomp Compliance:**
- **ZERO** probes, resource requests/limits, or securityContext/seccomp settings found in any service Terraform module.
- Searched all 24 service directories for `readiness`, `liveness`, `seccomp`, `resources`, `securityContext` — zero hits (only .gitignore noise about "override resources locally").
- The Terraform modules only set `data.*` Helm values (image, domain, partition config, etc.) — nothing related to pod-level Kubernetes compliance.
- Whether probes/resources exist depends entirely on what's baked into the remote OCI Helm charts themselves. We cannot inspect the chart templates without pulling from the OCI registry.
- **Critical implication:** We will almost certainly need postrender/kustomize patches for every single OSDU service, following the same pattern used for minio/eck-operator/cert-manager in `platform/kustomize/`.

**Q9 — Domain/Subscriber Key Configuration:**
- `cimpl_subscriber_private_key_id` is passed to every service via `set_sensitive` as `data.subscriberPrivateKeyId`. It flows: root `var.cimpl_subscriber_id` → master-chart `var.cimpl_subscriber_private_key_id` → each service module's `set_sensitive` block.
- This means it becomes an environment variable in the pod (Helm chart converts `data.subscriberPrivateKeyId` → env var). It's NOT a file mount.
- Format: Appears to be a plain string ID (described as "Subscriber ID"), not a full key. The variable name says "private_key_id" but the description just says "Subscriber ID" — likely a CIMPL platform authentication token or identifier.
- `cimpl_domain` (= `var.domain`) is set as `global.domain` in every service — this is the API gateway domain for route configuration.
- `cimpl_project` (= `var.cimpl_project`) is optional (default null), set as `data.googleCloudProject` — legacy GCP naming, used for grouping/project context.
- Every service also gets: `global.onPremEnabled=true`, `global.dataPartitionId=osdu`, `data.serviceAccountName`, `data.bootstrapServiceAccountName`, `data.bucketPrefix=refi`, `data.groupId=group`, `data.bucketName=refi-opa-policies`, `rosa=true`.

**Q10 — OETP Server:**
- OETP server is **disabled in ROSA** (`enable_oetp_server = false`).
- OETP = Open ETP (Energistics Transfer Protocol) — a WebSocket-based real-time data streaming protocol for subsurface data.
- Server and client share the same OCI repository path (`reservoir/open-etp-server/cimpl-helm`) but are separate charts.
- The OETP server chart version is `0.29.0-release` (pinned differently from other services' `0.0.7-latest`).
- The OETP server module follows the exact same pattern as other services (same set values, same `set_sensitive` for subscriberPrivateKeyId).
- There's also an `oetp-client-helm` module but it has no enable flag in the ROSA variables — it's never referenced in `main.tf`.
- **Recommendation: Exclude from initial AKS migration.** ROSA has it disabled, it's a specialized streaming protocol not needed for core OSDU functionality.

**Key Pattern Findings:**
1. All service modules are structurally identical — same `set` block pattern with ~14 values.
2. `rosa = true` flag exists in every service — for AKS we'd set this to `false`.
3. Every service has a `bootstrap_sa` (bootstrap-sa) service account reference.
4. Service dependency chain in ROSA main.tf: Keycloak → partition → entitlements → (legal, indexer, schema, file, policy, secret, notification, wellbore, crs-catalog). Some services depend on Airflow instead.
5. The wellbore service is unique — it doesn't use `set_sensitive` for subscriberPrivateKeyId, and has a `wdms_workers.enabled` toggle.
6. Policy service has a unique OPA init container image (`opa.init.image`).

📌 **2026-02-17:** Alex investigation findings merged into decisions registry — OSDU Service Charts Require Postrender Patches (all 24 services have zero probes/resources/seccomp; shared postrender approach recommended); All CIMPL Service Images Default to :latest (must override with pinned tags on AKS Automatic); OETP Server recommended for exclusion from Phase 1; Subscriber Key sourcing options clarified (env var pattern, needs sensitive marking).

📌 **2026-02-17:** User directive for OCI registry sourcing merged — service charts/images pull from OSDU community repositories in GitLab (community.opengroup.org).

📌 **2026-02-17:** GitHub issues logged and organized (#78–#105) for Phase 0.5–5 migration. Alex assigned 20 issues (Phase 2–5 OSDU services: Partition, Entitlements, Legal, Schema, Storage, Search, Indexer, File, Notification, Dataset, Register, Policy, Secret, Unit, Workflow, Wellbore, Wellbore Worker, CRS Conversion, CRS Catalog, EDS-DMS, Bootstrap Data).

### 2026-02-25: #108 Resolved — All 5 Missing Image Tags Found

**Prerequisite:** `helm registry login community.opengroup.org:5555` required before pulling charts.

**Key finding:** These 5 services use `cimpl-*-release` image names (NOT `core-plus-*-release` like the other 15 services). Entitlements specifically uses `cimpl-entitlements-v2-release` (v2 variant).

**Pinned image tags (latest available):**

| Service | Image Name | Tag |
|---------|-----------|-----|
| Entitlements | `cimpl-entitlements-v2-release` | `da367b9f` |
| Workflow | `cimpl-workflow-release` | `f91c585a` |
| Wellbore | `cimpl-wellbore-release` | `f05e5a98` |
| Wellbore Worker | `cimpl-wellbore-worker-release` | `f7f46dc6` |
| EDS-DMS | `cimpl-eds-dms-release` | `f3df61a9` |

**Full registry paths (for Terraform modules):**
- Entitlements: `community.opengroup.org:5555/osdu/platform/security-and-compliance/entitlements/cimpl-entitlements-v2-release:da367b9f`
- Workflow: `community.opengroup.org:5555/osdu/platform/data-flow/ingestion/ingestion-workflow/cimpl-workflow-release:f91c585a`
- Wellbore: `community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/wellbore-domain-services/cimpl-wellbore-release:f05e5a98`
- Wellbore Worker: `community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/wellbore-domain-services-worker/cimpl-wellbore-worker-release:f7f46dc6`
- EDS-DMS: `community.opengroup.org:5555/osdu/platform/data-flow/ingestion/external-data-sources/eds-dms/cimpl-eds-dms-release:f3df61a9`

**Helm chart versions:**
- Entitlements: `0.0.7-cimpl993f5ece` (ROSA default)
- Workflow/Wellbore: `0.0.7-latest` (200+ cimpl versions available)
- Wellbore Worker: `0.0.7-latest` (also `0.29.0`, `0.29.1`, `0.29.2`)
- EDS-DMS: `0.0.7-latest` (also `0.29.0`)

This unblocks #85, #98, #99, #100, #103.

### 2026-02-25: OSDU service postrender framework wired for Partition

- Added `platform/helm_partition.tf` with Helm v3 postrender using `/usr/bin/env` to pass `SERVICE_NAME=partition` into `platform/kustomize/postrender.sh`.
- Shared kustomize components live under `platform/kustomize/components/`, with per-service overlays in `platform/kustomize/services/<service>/`.
- Partition bootstrap image is pinned to the same tag as the main service image (`67dedce7`) to avoid `:latest` on AKS Automatic.
