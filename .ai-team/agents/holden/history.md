# Holden — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA (OpenShift) to AKS Automatic using azd + Terraform
- Three-layer architecture: infra (AKS), platform (middleware), services (OSDU apps)
- User: Daniel Scholl (daniel.scholl@microsoft.com)
- AKS Automatic has strict, non-negotiable deployment safeguards
- Reference ROSA codebase at reference-rosa/ has ~20 OSDU services + infra components
- Layers 1 and 2 are built; Layer 3 (OSDU services) is the next frontier

## Learnings

### ROSA Reference Architecture
- ROSA infra has 8 components: Istio (self-managed, ambient profile), Common (infra bootstrap), Airflow, Elasticsearch, Keycloak, MinIO, PostgreSQL, RabbitMQ
- All ROSA components use OCI charts from `community.opengroup.org:5555` (CIMPL registry)
- ROSA deploys everything into a single `osdu` namespace
- ROSA has ~22 services total (20 OSDU microservices + elastic-bootstrap + bootstrap-data)
- ROSA dependency chain: Istio → Common → {PostgreSQL, Elastic, MinIO} → {Keycloak, RabbitMQ, Airflow} → Services
- Services have a strict dependency order: Partition → Entitlements → (Legal, Schema, File, Policy, Secret, etc.)
- Airflow is upstream of: Partition, Search, Register, Dataset, Unit, CRS-Conversion, EDS-DMS, Workflow
- Keycloak JWKS endpoint readiness gate blocks all services that validate JWTs
- OETP Server is disabled in ROSA reference (`enable_oetp_server = false`)
- Bootstrap Data modules are commented out in ROSA reference

### AKS vs ROSA Architectural Differences
- Istio: AKS uses managed Istio (asm-1-28), ROSA uses self-managed v1.26.1 — different but AKS cannot use self-managed (NET_ADMIN blocked)
- Elasticsearch: AKS uses ECK Operator + CR, ROSA uses CIMPL Helm chart — AKS approach gives better safeguards control
- PostgreSQL: AKS uses CloudNativePG (3-instance HA), ROSA uses CIMPL Bitnami chart (single instance) — AKS is an upgrade; services must use `postgresql-rw.postgresql.svc.cluster.local`
- MinIO: AKS uses official chart from charts.min.io, ROSA uses CIMPL-wrapped Bitnami chart — functionally equivalent
- Redis: AKS deploys standalone Redis (Bitnami chart); ROSA embeds Redis in service charts (entitlements, notification)
- Namespaces: AKS uses per-component namespaces; ROSA uses single `osdu` namespace for everything

### Key File Paths
- ROSA master deployment: `reference-rosa/terraform/master-chart/main.tf` — all module calls and dependency chains
- ROSA variables: `reference-rosa/terraform/master-chart/variables.tf` — all chart versions, enable flags, image references
- ROSA infra modules: `reference-rosa/terraform/master-chart/infra/` — 8 subdirectories
- ROSA service modules: `reference-rosa/terraform/master-chart/services/` — 24 subdirectories
- AKS platform layer: `platform/*.tf` — current Layer 2 implementation
- Gap analysis: session workspace plan.md (not in repo)
- Decision inbox: `.ai-team/decisions/inbox/holden-rosa-parity-analysis.md`

### AKS Safeguards Impact on Services Layer
- Every OSDU service chart will need: probes, resource requests, seccomp, versioned image tags, unique service selectors
- CIMPL charts were built for OpenShift — likely need postrender/kustomize patches for AKS compliance
- Consider a generic postrender framework rather than per-service overlays
- Jobs (Airflow, bootstrap, elastic-bootstrap) are problematic — probes required but semantically incorrect for one-shot tasks
- Policy exemption pattern exists: `azurerm_resource_policy_exemption` in aks.tf for CNPG jobs
