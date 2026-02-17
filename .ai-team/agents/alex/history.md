# Alex — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl (daniel.scholl@microsoft.com)
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
