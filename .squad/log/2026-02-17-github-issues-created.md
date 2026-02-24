# Session: 2026-02-17 — GitHub Issues Created

**Requested by:** Daniel Scholl

## Summary

Holden created 28 GitHub issues (#78–#105) for the ROSA→AKS migration plan.

## Details

- **Issues Created:** #78–#105 (28 total)
- **Organization:** 6 phases (0.5–5)
  - Phase 0.5: Postrender framework (1 issue)
  - Phase 1: Missing infrastructure: Keycloak, RabbitMQ, Airflow, Common, Elastic Bootstrap (6 issues)
  - Phase 2: Foundation services: Partition, Entitlements (2 issues)
  - Phase 3: Core services: Legal, Schema, Storage, Search, Indexer, File (6 issues)
  - Phase 4: Extended services: Notification, Dataset, Register, Policy, Secret, Unit, Workflow (7 issues)
  - Phase 5: Domain services + bootstrap data: Wellbore, Wellbore Worker, CRS Conversion, CRS Catalog, EDS-DMS, Bootstrap Data (6 issues)

- **Master Tracking Issue:** #105

- **Labels Created:** 16 new labels
  - Phase labels: `phase:0`, `phase:1`, `phase:2`, `phase:3`, `phase:4`, `phase:5`
  - Layer labels: `layer:platform`, `layer:services`
  - Squad assignment: `squad:amos`, `squad:alex`, `squad:holden`
  - Additional: `migration`, `rosa-parity`

- **Squad Assignments:**
  - **Amos (Platform Dev):** 7 issues (Phase 0.5, Phase 1 infra)
  - **Alex (Services Dev):** 20 issues (Phase 2–5 OSDU services)
  - **Holden (Tracker):** Coordinating issues #105 (master), tracking dependencies

## Files Modified

- `.ai-team/decisions/inbox/holden-github-issues-created.md` → merged to decisions.md
