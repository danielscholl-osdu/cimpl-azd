# Architecture Decisions

## Generic Kustomize Postrender Framework (2026-02-24)

**By:** Amos  
**Title:** Generic kustomize postrender framework for AKS safeguards  

### Context
AKS Automatic safeguards require probes, resources, seccomp, and topology spread across all OSDU services. Existing postrender scripts were service-specific.

### Decision
Adopt shared kustomize components (seccomp, security-context, topology-spread) and a single postrenderer script at `platform/kustomize/postrender.sh` that selects per-service overlays via `SERVICE_NAME`. Service overlays live under `platform/kustomize/services`, starting with a partition template for probes/resources.

### Consequences
New services can reuse shared components and only define service-specific probes/resources. Terraform runs should set `SERVICE_NAME` to the Helm release name when invoking the postrenderer.

