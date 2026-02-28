# cimpl-azd — OSDU on AKS Automatic

> Deliver a production-ready OSDU data platform on Azure Kubernetes Service Automatic, converted from the ROSA reference implementation.

## Mission

Port the full OSDU platform stack from Red Hat OpenShift (ROSA) to AKS Automatic using Azure Developer CLI (azd) for deployment orchestration. The result is a repeatable, multi-user deployment that passes AKS Automatic deployment safeguards and runs all ~20 OSDU microservices.

## Architecture

Two-layer Terraform model with a single software stack:

| Layer | Directory | Purpose |
|-------|-----------|---------|
| 1. Cluster Infrastructure | `infra/` | AKS cluster, RBAC, networking, Istio |
| 2. Software Stack | `software/stack/` | Middleware (ES, PG, Redis, RabbitMQ, MinIO, Keycloak, Airflow) + OSDU services |

Two consolidated namespaces (ADR-0017):

| Namespace | Contents | Istio |
|-----------|----------|-------|
| `platform` | All middleware (Elasticsearch, PostgreSQL, Redis, RabbitMQ, MinIO, Keycloak, Airflow, cert-manager) | Disabled |
| `osdu` | All OSDU services (Partition, Entitlements, and future services) | Enabled (STRICT mTLS) |

## Current State (v0.2.0)

- **Phase 0.5** ✅ Postrender framework
- **Phase 1** ✅ All middleware deployed and healthy
- **Phase 2** ✅ Partition + Entitlements deployed
- **Phase 3** 🔄 Core services: Legal, Schema, Storage, Search, Indexer, File (#145)
- **Phase 4** ⬜ Extended services (#146)
- **Phase 5** ⬜ Domain services + Bootstrap Data (#147)

## Key Files

| File | Purpose |
|------|---------|
| `software/stack/main.tf` | Namespace locals, Karpenter, middleware module calls |
| `software/stack/osdu.tf` | OSDU service module calls (~20 lines per service) |
| `software/stack/variables.tf` | Feature flags (default: true), credentials, config |
| `software/stack/charts/` | Per-component Terraform modules (elastic, postgresql, keycloak, etc.) |
| `software/stack/modules/osdu-service/` | Reusable OSDU Helm wrapper with postrender |
| `software/stack/kustomize/` | Postrender patches per service for AKS safeguards |
| `software/stack/charts/osdu-common/` | OSDU namespace, shared secrets, ConfigMaps |

## Constraints

- AKS Automatic enforces deployment safeguards (probes, resources, seccomp, no `:latest`, anti-affinity)
- NET_ADMIN/NET_RAW capabilities blocked (affects Istio sidecar injection)
- Two separate Terraform states: `infra/` (azd-managed) and `software/stack/` (local via pre-deploy.ps1)
- All OSDU service charts require postrender/kustomize patches for safeguards compliance
- Feature flags use opt-out model (all default true; set `enable_<svc>=false` to disable)

## Success Criteria

- All ROSA reference services deployed and healthy on AKS Automatic
- `azd up` provisions a complete environment end-to-end
- Multi-user support via azd environment naming
- Documentation published via GitHub Pages
