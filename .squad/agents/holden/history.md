# Holden — History

## Current State (v0.2.0, 2026-02-27)

**Architecture settled.** Two-layer model with consolidated namespaces:
- `infra/` — AKS cluster (stable, Naomi's scope absorbed)
- `software/stack/` — All middleware + OSDU services in one Terraform state
- `platform` namespace — All middleware (ES, PG, Redis, RabbitMQ, MinIO, Keycloak, Airflow)
- `osdu` namespace — All OSDU services (Partition, Entitlements deployed; ~18 remaining)

**Key ADRs:** 0015 (reusable osdu-service module), 0016 (raw manifests for Keycloak), 0017 (consolidated namespaces)

**Backlog:** Epic #105, Phase 3 #145, Phase 4 #146, Phase 5 #147, Validation #127. Old per-service issues (#86–#104) closed.

## ARCHIVED: Core Analysis Summary (2025-07-18 to 2026-02-17)

Completed comprehensive ROSA-to-AKS parity analysis covering 8 infra components and ~22 OSDU services.

**ROSA Reference Stack:** 8 infra components (Istio, Common, Airflow, ES, Keycloak, MinIO, PG, RabbitMQ) + ~22 services in single `osdu` namespace via CIMPL registry.

**AKS Differences:** Managed Istio (NET_ADMIN blocked), ECK for Elasticsearch, CloudNativePG 3-instance HA, two consolidated namespaces (`platform` + `osdu`).

**Decisions Recorded:** Istio approach, ECK strategy, CNPG upgrade, namespace strategy → ADR-0017.

## Learnings

📌 **2026-02-27:** Absorbed Naomi's infra scope — infra layer is stable. Holden now reviews both infra and stack changes.

📌 **2026-02-27:** Phase 2 complete (Partition + Entitlements, PR #144, release v0.2.0). Deployment pattern validated. Each service is ~20 lines in osdu.tf using reusable module.

📌 **2026-02-27:** Backlog consolidated from 23 open issues to 5. Batched by phase for mechanical service deployment.

📌 **2026-02-17:** Created 28 GitHub issues (#78–#105) for ROSA→AKS migration. Subsequently reorganized into batched issues (#145, #146, #147) after pattern was established.
