---
name: "aks-safeguards-compliance"
description: "AKS Automatic deployment safeguards compliance patterns"
domain: "kubernetes-deployment"
confidence: "high"
source: "earned"
---

## Context
AKS Automatic clusters enforce deployment safeguards with NO option to relax or exclude namespaces. All workloads MUST comply. This is by design per Microsoft.

## Patterns

### Required for ALL containers
- readinessProbe and livenessProbe on every container
- Resource requests (and limits) on every container
- No `:latest` image tags — pin to specific versions
- seccompProfile: RuntimeDefault in pod security context
- Deployments with replicas > 1 need topologySpreadConstraints or podAntiAffinity

### Postrender/Kustomize approach
- Use kustomize postrender to inject missing probes, resources, seccomp into upstream charts
- Postrender script: `software/stack/kustomize/postrender.sh` (receives `SERVICE_NAME` env var)
- Shared kustomize components: `software/stack/kustomize/components/` (generic patches for all services)
- Per-service overlays: `software/stack/kustomize/services/<service>/` (service-specific customizations)
- OSDU services: probes on port 8081 targeting `type=core` Deployments only (not bootstrap)

### NET_ADMIN/NET_RAW blocked
- Istio sidecar injection istio-init containers need NET_ADMIN — blocked on AKS Automatic
- Use AKS-managed Istio (asm-1-28) instead of self-managed
- Workloads needing Istio mesh: label namespace with istio.io/rev: asm-1-28
- `osdu` namespace has Istio enabled; `platform` namespace does not (ADR-0008)

### Unique service selectors
- Each Service must have a unique label selector (K8sAzureV3UniqueServiceSelector)
- Postrender can inject additional pod labels to make selectors unique

### Ad-hoc pods (curl, debug)
Running ad-hoc pods (e.g., curl for health checks) requires full safeguards compliance:
- seccompProfile: RuntimeDefault
- Resource requests and limits
- runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities
- Pinned image tag (e.g., `curlimages/curl:8.12.1`)
- Tolerations for the target nodepool

## Anti-Patterns
- Trying to bypass safeguards with `az aks safeguards update` — always rejected
- Using `:latest` tags on Bitnami or upstream charts without pinning
- Deploying self-managed Istio — NET_ADMIN blocks it
- Assuming safeguards can be namespace-excluded — they cannot
- Using `kubectl run` without overrides — will be rejected by Gatekeeper
