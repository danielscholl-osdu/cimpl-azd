# Amos — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl (daniel.scholl@microsoft.com)
- platform/ layer has: Elasticsearch (ECK), PostgreSQL (CNPG), MinIO, Redis, cert-manager, ExternalDNS, Istio Gateway
- Helm provider v3 syntax: set = [...], postrender = {}
- AKS safeguards: probes, resources, seccomp, no :latest, anti-affinity, unique service selectors
- Postrender kustomize used for cert-manager cainjector probes and MinIO service selector
- Stateful workloads on agentpool=stateful with taint workload=stateful:NoSchedule
- Reference ROSA infra components at reference-rosa/terraform/master-chart/infra/ (airflow, keycloak, rabbitmq still to port)

## Team Updates

📌 **2026-02-17:** ROSA parity gap analysis complete (Holden) — AKS-managed Istio is correct approach; CloudNativePG upgrade (3-instance HA, RW endpoint at postgresql-rw.postgresql.svc.cluster.local); service namespace strategy decision needed before Phase 2 platform deployment.

## Learnings
