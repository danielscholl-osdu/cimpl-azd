# Amos — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl
- platform/ layer has: Elasticsearch (ECK), PostgreSQL (CNPG), MinIO, Redis, cert-manager, ExternalDNS, Istio Gateway
- Helm provider v3 syntax: set = [...], postrender = {}
- AKS safeguards: probes, resources, seccomp, no :latest, anti-affinity, unique service selectors
- Postrender kustomize used for cert-manager cainjector probes and MinIO service selector
- Stateful workloads on agentpool=stateful with taint workload=stateful:NoSchedule
- Reference ROSA infra components at reference-rosa/terraform/master-chart/infra/ (airflow, keycloak, rabbitmq still to port)

## Team Updates

📌 **2026-02-17:** ROSA parity gap analysis complete (Holden) — AKS-managed Istio is correct approach; CloudNativePG upgrade (3-instance HA, RW endpoint at postgresql-rw.postgresql.svc.cluster.local); service namespace strategy decision needed before Phase 2 platform deployment.

📌 **2026-02-17:** User directives clarified (Daniel Scholl) — Keycloak deployment required; RabbitMQ deployment required; Airflow can share existing Redis instead of deploying its own; Elasticsearch already running (investigate Elastic Bootstrap status).

## Learnings

### 2025-07-18: Common Chart Investigation (Q1)
- **Chart**: `common-infra-bootstrap` from OCI registry `community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/common-infra-bootstrap/cimpl-helm`
- **Version used on ROSA**: `0.0.7-4eccc54d`
- **Terraform module**: `reference-rosa/terraform/master-chart/infra/common-helm/main.tf` — deploys a single `helm_release` resource, passing `common_values` from an external `common-values.yaml` file (not committed to repo)
- **Dependencies**: Airflow, Keycloak, MinIO, and PostgreSQL all `depends_on` Common — it's a prerequisite for all stateful infra
- **Values file**: Referenced as `file("${path.module}/common-values.yaml")` in `reference-rosa/terraform/main.tf:80` but not committed to the repo — the chart contents cannot be inspected from the Terraform code alone
- **Assessment**: Based on naming convention ("common-infra-bootstrap"), dependency graph, and OSDU patterns, this is almost certainly a namespace/RBAC/ConfigMap bootstrap chart that creates the shared `osdu` namespace, RBAC roles, service accounts, ConfigMaps with cluster-wide settings (domain, project ID, subscriber key), and possibly network policies. On AKS, we achieve equivalent results differently: per-component namespaces via `kubernetes_namespace` resources, RBAC via Azure AD integration, and config via Terraform variables passed directly to Helm releases.

### 2025-07-18: Elastic Bootstrap Investigation (Q6)
- **Chart**: `elastic-bootstrap` from OCI registry `community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/elastic-bootstrap/cimpl-helm`
- **Version**: `0.0.7-latest`
- **Custom image**: `community.opengroup.org:5555/.../elastic-bootstrap/elastic-bootstrap:f72735fb` — this is a purpose-built container, not a stock Elasticsearch image
- **Terraform module**: `reference-rosa/terraform/master-chart/services/elastic-bootstrap-helm/main.tf` — deploys a single `helm_release`, passes image via `set` block (`elasticsearch.image`)
- **Dependency chain**: `depends_on = [ module.Elastic, null_resource.wait_for_istio ]` — runs AFTER Elasticsearch is deployed
- **Classification**: Lives under `services/` not `infra/`, enabled by `enable_elastic-bootstrap = true` in `reference-rosa/terraform/main.tf:69`
- **Assessment**: This is a post-deploy initialization job. The custom container image strongly suggests it creates index templates, ILM policies, index aliases, pipeline configurations, and/or security roles that OSDU services expect. It runs as a Helm release (not a one-shot Job), meaning it can be re-applied via `recreate_pods = true`. On AKS with ECK, we'd need to implement equivalent initialization — likely as a Kubernetes Job or a Terraform `kubectl_manifest` that creates index templates and ILM policies via the Elasticsearch API after the cluster is healthy.

📌 **2026-02-17:** Amos investigation findings merged into decisions registry — Common Chart clarified (no standalone module needed unless single osdu namespace adopted; lightweight k8s_common.tf as alternative); Elastic Bootstrap identified as Phase 2 dependency (need k8s_elastic_bootstrap.tf Job to configure ES index templates, ILM policies, aliases).

📌 **2026-02-17:** User directive for Bootstrap Data requirement merged — Bootstrap Data modules (commented-out in ROSA) must be implemented on AKS for parity.

📌 **2026-02-17:** GitHub issues logged and organized (#78–#105) for Phase 0.5–5 migration. Amos assigned 7 issues (Phase 0.5 postrender + Phase 1 infra: Keycloak, RabbitMQ, Airflow, Common, Elastic Bootstrap, safeguards compliance).

### 2026-03-05: Airflow deployment patterns (Issue #81)
- Airflow should use the official Apache Airflow Helm chart with external Redis (`redis-master.redis.svc.cluster.local`) and CNPG PostgreSQL (`postgresql-rw.postgresql.svc.cluster.local`, database `airflow`).
- Airflow namespace uses `istio-injection: enabled` with STRICT mTLS and stateful node affinity/tolerations for workers.
- Airflow secrets are generated in Terraform (fernet + webserver keys) and stored in an `airflow-secrets` secret for Helm values.
