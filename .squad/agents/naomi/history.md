# Naomi — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl
- infra/ layer: AKS Automatic cluster (K8s 1.32, Istio asm-1-28, Standard_D4s_v5 system pool)
- Karpenter NAP for stateful workloads (D-series 4-8 vCPU)
- ExternalDNS with UAMI + federated credentials
- State at .azure/<env>/infra/terraform.tfstate (azd-managed)
- deploy-platform.ps1 reads infra outputs via -state= flag

## Team Updates

📌 **2026-02-17:** ROSA parity gap analysis complete (Holden) — 4 missing infra components identified (Common, Keycloak, RabbitMQ, Airflow); all ~22 OSDU services missing. Key decisions: AKS-managed Istio confirmed (self-managed blocked by NET_ADMIN/NET_RAW), CloudNativePG is an upgrade (services must use postgresql-rw endpoint), service namespace strategy needs Daniel's input.

📌 **2026-02-17:** User directives clarified (Daniel Scholl) — Keycloak must be deployed as infra component (Entra ID cannot replace); RabbitMQ deployment required; Airflow should share existing Redis; Elasticsearch already running (check Elastic Bootstrap status).

## Learnings
- infra/main.tfvars.json must map DNS_ZONE_* variables for azd to pass DNS zone values to infra Terraform.
- scripts/pre-provision.ps1 sets both TF_VAR_dns_zone_* and DNS_ZONE_* env vars for ExternalDNS configuration.
