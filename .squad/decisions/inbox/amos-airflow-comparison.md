# Airflow Deployment Comparison (Issue #81)

## ROSA reference (CIMPL chart)
- Terraform module: `reference-rosa/terraform/master-chart/infra/airflow-helm`.
- Chart source: OCI `community.opengroup.org:5555/.../airflow-helm-chart/cimpl-helm`, version `0.0.7-latest`.
- The module only defines the Helm release and accepts values via `airflow_values`; the values file is not in the repo, so workload configuration (probes/resources/affinity) isn’t visible.
- This path is ROSA-specific and does not align with AKS Automatic safeguards or Helm provider v3 patterns used here.

## osdu-developer reference
- Uses Flux HelmRelease with the community Airflow chart (`https://airflow-helm.github.io/charts`, chart `airflow`).
- Pins image `apache/airflow:2.10.1-python3.12`, disables internal PostgreSQL/Redis, and configures external DB/Redis.
- Uses KubernetesExecutor (no Celery workers) and relies on Key Vault secrets for fernet/webserver keys.
- Adds separate charts for DAG packaging, storage volumes, and Azure App Configuration config maps.

## AKS platform patterns (this repo)
- Helm releases are pinned and configured directly in Terraform with explicit resources, probes, security context, seccomp, and stateful node affinity.
- Istio mTLS is enforced per namespace via PeerAuthentication.
- Redis and CNPG PostgreSQL are already deployed; CNPG bootstrap creates the `airflow` database/user.

## Decision
- Use the **official Apache Airflow chart** (apache-airflow/airflow via `https://airflow.apache.org`) to meet the acceptance criteria and align with upstream support.
- Configure external Redis (`redis-master.redis.svc.cluster.local:6379`) and external PostgreSQL (`postgresql-rw.postgresql.svc.cluster.local:5432`, database `airflow`); disable internal subcharts.
- Generate fernet + webserver secret keys in Terraform, schedule on the stateful pool with tolerations/affinity, and enforce AKS safeguards via explicit probes/resources/security context.
