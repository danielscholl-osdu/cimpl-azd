---
name: "helm-v3-terraform"
description: "Helm provider v3 syntax patterns for Terraform"
domain: "terraform-helm"
confidence: "high"
source: "earned"
---

## Context
The platform layer uses Helm provider ~> 3.1 and Kubernetes provider ~> 3.0. These have breaking syntax changes from v2.

## Patterns

### set blocks — list-of-objects format
```hcl
set = [
  { name = "replicaCount", value = "3" },
  { name = "image.tag", value = "1.2.3" },
]
```
NOT nested `set {}` blocks.

### postrender — object assignment
```hcl
postrender = {
  binary_path = "${path.module}/kustomize/kustomize.sh"
}
```
NOT a `postrender {}` block.

### Boolean values as Kubernetes labels
When setting K8s labels/annotations to "true" via Helm set, add `type = "string"`:
```hcl
{ name = "podLabels.azure\\.workload\\.identity/use", value = "true", type = "string" }
```
Without `type = "string"`, Helm interprets "true" as boolean, which is invalid for K8s labels.

### Boolean chart values
Do NOT use `type = "string"` for boolean Helm chart values — only for labels/annotations:
```hcl
{ name = "installCRDs", value = "true" }  # No type needed
```

## Anti-Patterns
- Using nested `set {}` blocks (Helm provider v2 syntax)
- Using `postrender {}` as a block instead of object assignment
- Adding `type = "string"` to every boolean value (only needed for K8s labels/annotations)
