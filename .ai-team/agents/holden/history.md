# Holden — History

## ARCHIVED: Core Analysis Summary (2025-07-18 to 2026-02-17)

Completed comprehensive ROSA-to-AKS parity analysis covering 8 infra components and ~22 OSDU services. Key findings:

**ROSA Reference Stack:** 8 infra components (Istio self-managed, Common, Airflow, Elasticsearch, Keycloak, MinIO, PostgreSQL, RabbitMQ) + ~22 services all in single `osdu` namespace via CIMPL registry. Strict dependency chain: Istio → Common → {PostgreSQL, Elastic, MinIO} → {Keycloak, RabbitMQ, Airflow} → Services.

**AKS vs ROSA:** Managed Istio (NET_ADMIN blocked self-managed), ECK for Elasticsearch, CloudNativePG HA upgrade (postgresql-rw endpoint required), per-component namespaces (vs ROSA single namespace).

**Gap:** 4 missing infra components (Common, Keycloak, RabbitMQ, Airflow); all ~22 services missing. Every service needs AKS safeguards compliance (probes, resource requests, seccomp, versioned tags, unique selectors). CIMPL charts built for OpenShift — postrender/kustomize patches needed. Jobs problematic (probes semantically wrong but required).

**Key Paths:** ROSA masters at `reference-rosa/terraform/master-chart/{main.tf,variables.tf}`; infra modules at `infra/`; service modules at `services/`; AKS platform at `platform/*.tf`.

**Decisions Recorded:** 4 architectural decisions merged into `.ai-team/decisions.md` (Istio approach confirmed, ECK strategy, CNPG upgrade, namespace strategy needs decision).

## Team Updates

📌 **2026-02-17:** Gap analysis complete and decisions merged into team registry.

## Project Learnings (from import)
- Project converts OSDU platform from ROSA (OpenShift) to AKS Automatic using azd + Terraform
- Three-layer architecture: infra (AKS), platform (middleware), services (OSDU apps)
- User: Daniel Scholl (daniel.scholl@microsoft.com)
- AKS Automatic has strict, non-negotiable deployment safeguards
- Reference ROSA codebase at reference-rosa/ has ~20 OSDU services + infra components
- Layers 1 and 2 are built; Layer 3 (OSDU services) is the next frontier

## Learnings

📌 **2026-02-17:** Team investigation findings merged into decisions registry — All 3 agents contributed findings (Amos: Common/Elastic Bootstrap clarifications; Alex: service chart compliance patterns; Copilot: user directives on Keycloak, RabbitMQ, Airflow Redis-sharing, Bootstrap Data). New user directives confirm OCI registry sourcing and Bootstrap Data implementation required.

📌 **2026-02-17:** Created 28 GitHub issues (#78–#105) for ROSA→AKS migration, organized by phase:
- **Phase 0.5:** #78 (postrender framework) — critical path, assigned to Amos
- **Phase 1:** #79 (Keycloak), #80 (RabbitMQ), #81 (Airflow), #82 (Common), #83 (Elastic Bootstrap) — assigned to Amos
- **Phase 2:** #84 (Partition), #85 (Entitlements) — assigned to Alex
- **Phase 3:** #86 (Legal), #87 (Schema), #88 (Storage), #89 (Search), #90 (Indexer), #91 (File) — assigned to Alex
- **Phase 4:** #92 (Notification), #93 (Dataset), #94 (Register), #95 (Policy), #96 (Secret), #97 (Unit), #98 (Workflow) — assigned to Alex
- **Phase 5:** #99 (Wellbore), #100 (Wellbore Worker), #101 (CRS Conversion), #102 (CRS Catalog), #103 (EDS-DMS), #104 (Bootstrap Data) — assigned to Alex
- **Tracking:** #105 (master tracking issue) — assigned to Holden
- **Label scheme:** `phase:0`–`phase:5`, `layer:platform`/`layer:services`/`layer:infra`, `squad:amos`/`squad:alex`/`squad:holden`, `squad`, `enhancement`, `blocked`
