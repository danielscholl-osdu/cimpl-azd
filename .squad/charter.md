# cimpl-azd — OSDU on AKS Automatic

> Deliver a production-ready OSDU data platform on Azure Kubernetes Service Automatic, converted from the ROSA reference implementation.

## Mission

Port the full OSDU platform stack from Red Hat OpenShift (ROSA) to AKS Automatic using Azure Developer CLI (azd) for deployment orchestration. The result is a repeatable, multi-user deployment that passes AKS Automatic deployment safeguards and runs all ~20 OSDU microservices.

## Architecture

Three-layer Terraform model:

| Layer | Directory | Owner | Purpose |
|-------|-----------|-------|---------|
| 1. Cluster Infrastructure | `infra/` | Naomi | AKS cluster, RBAC, networking, Istio |
| 2. Platform Components | `platform/` | Amos | Stateful middleware: ES, PG, Redis, RabbitMQ, MinIO, Keycloak, Airflow |
| 3. OSDU Services | `services/` | Alex | ~20 OSDU microservices via Helm |

## Constraints

- AKS Automatic enforces deployment safeguards (probes, resources, seccomp, no `:latest`, anti-affinity)
- NET_ADMIN/NET_RAW capabilities blocked (affects Istio sidecar injection)
- Two separate Terraform states (infra/ managed by azd, platform/ local)
- All OSDU service charts require postrender/kustomize patches for safeguards compliance

## Success Criteria

- All ROSA reference services deployed and healthy on AKS Automatic
- `azd up` provisions a complete environment end-to-end
- Multi-user support via azd environment naming
- Documentation published via GitHub Pages
