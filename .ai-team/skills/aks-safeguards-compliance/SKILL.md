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
- Pattern: platform/kustomize/{component}/ directories with kustomization.yaml + patch files
- Helm postrender binary: platform/kustomize/kustomize.sh (wraps kustomize build)
- Each component gets its own kustomize directory for targeted patches

### NET_ADMIN/NET_RAW blocked
- Istio sidecar injection istio-init containers need NET_ADMIN — blocked on AKS Automatic
- Use AKS-managed Istio (asm-1-28) instead of self-managed
- Workloads needing Istio mesh: label namespace with istio.io/rev: asm-1-28
- Workloads NOT needing mesh (ExternalDNS, cert-manager): do NOT label namespace

### Unique service selectors
- Each Service must have a unique label selector (K8sAzureV3UniqueServiceSelector)
- Postrender can inject additional pod labels to make selectors unique

## Anti-Patterns
- Trying to bypass safeguards with `az aks safeguards update` — always rejected
- Using `:latest` tags on Bitnami or upstream charts without pinning
- Deploying self-managed Istio — NET_ADMIN blocks it
- Assuming safeguards can be namespace-excluded — they cannot
