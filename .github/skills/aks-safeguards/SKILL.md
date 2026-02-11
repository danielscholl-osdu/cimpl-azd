---
name: aks-safeguards
description: "Use when creating or modifying Kubernetes workloads, Helm charts, or any deployment to AKS Automatic clusters. Ensures compliance with non-negotiable AKS Deployment Safeguards."
metadata:
  version: 1.0.0
---

# AKS Safeguards Compliance

AKS Automatic clusters enforce Deployment Safeguards that **cannot be bypassed, relaxed, or excluded by namespace**. All workloads MUST be compliant.

## The Iron Law

```
AKS SAFEGUARDS ARE NON-NEGOTIABLE
Make workloads compliant. Do not attempt to bypass.
```

## When to Use This Skill

- Creating new Helm releases in platform/
- Modifying existing Kubernetes deployments
- Adding new containers or pods
- Troubleshooting admission webhook rejections
- Reviewing pull requests that touch Kubernetes resources

## Quick Reference: Compliance Checklist

Every container/pod MUST have:

| Requirement | Status |
|-------------|--------|
| `readinessProbe` | Required on ALL containers |
| `livenessProbe` | Required on ALL containers |
| `resources.requests` | Required on ALL containers |
| Specific image tag | NO `:latest` allowed |
| `seccompProfile: RuntimeDefault` | Required in pod spec |
| Anti-affinity (if replicas > 1) | `topologySpreadConstraints` or `podAntiAffinity` |
| Pod Security Standards | `runAsNonRoot`, etc. |
| Unique service selectors | Each service needs unique labels |

## Detailed Requirements

### 1. Probes (readinessProbe + livenessProbe)

**ALL containers MUST have both probes.**

```yaml
containers:
  - name: my-container
    readinessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
```

**For containers without HTTP endpoints:**

```yaml
readinessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
livenessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  initialDelaySeconds: 15
  periodSeconds: 10
```

**TCP probe alternative:**

```yaml
readinessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 10
  periodSeconds: 5
```

### 2. Resource Requests

**ALL containers MUST specify resource requests.**

```yaml
containers:
  - name: my-container
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:           # Optional but recommended
        memory: "256Mi"
        cpu: "200m"
```

**Minimum viable requests:**

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "10m"
```

### 3. Image Tags

**NO `:latest` tags allowed. Use specific versions.**

```yaml
# WRONG
image: nginx:latest
image: myrepo/myimage

# CORRECT
image: nginx:1.25.3
image: myrepo/myimage:v1.2.3
image: myrepo/myimage@sha256:abc123...
```

### 4. Seccomp Profile

**Pod spec MUST include seccompProfile.**

```yaml
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: my-container
      # ...
```

### 5. Anti-Affinity (Replicas > 1)

**Deployments with multiple replicas MUST spread across nodes.**

**Option A: topologySpreadConstraints (preferred)**

```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: my-app
```

**Option B: podAntiAffinity**

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: my-app
            topologyKey: kubernetes.io/hostname
```

### 6. Pod Security Standards

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: my-container
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true  # If possible
        capabilities:
          drop:
            - ALL
```

## Helm Chart Compliance

### Setting Values in Terraform

```hcl
resource "helm_release" "my_app" {
  name       = "my-app"
  repository = "https://charts.example.com"
  chart      = "my-app"
  version    = "1.2.3"  # Always pin version
  namespace  = "my-namespace"

  # Probes
  set {
    name  = "readinessProbe.enabled"
    value = "true"
  }
  set {
    name  = "livenessProbe.enabled"
    value = "true"
  }

  # Resources
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  # Security context
  set {
    name  = "podSecurityContext.seccompProfile.type"
    value = "RuntimeDefault"
  }

  # Image tag (never latest)
  set {
    name  = "image.tag"
    value = "1.2.3"
  }
}
```

### Postrender for Probe Injection

When charts don't support probes natively, use Kustomize postrender:

```hcl
resource "helm_release" "my_app" {
  # ...

  postrender {
    binary_path = "${path.module}/postrender-my-app.sh"
  }
}
```

**postrender-my-app.sh:**

```bash
#!/bin/bash
set -euo pipefail
cat > /tmp/helm-input.yaml
kustomize build "${KUSTOMIZE_DIR:-./kustomize/my-app}" --load-restrictor=LoadRestrictionsNone
```

**kustomize/my-app/kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - /tmp/helm-input.yaml
patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/readinessProbe
        value:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
      - op: add
        path: /spec/template/spec/containers/0/livenessProbe
        value:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
```

## Checking Compliance

### Before Deployment

```bash
# Render Helm chart and check
helm template my-release my-chart -n my-namespace | \
  grep -E "(readinessProbe|livenessProbe|requests|seccompProfile|:latest)"
```

### After Deployment

```bash
# Check for violations
kubectl get constraints -o wide

# Specific constraint types
kubectl get k8sazurev2containerenforceprob -o wide
kubectl describe k8sazurev2containerenforceprob

# Find violating pods
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].readinessProbe == null) | .metadata.name'
```

## Common Compliance Issues

### Issue: Chart doesn't support probes

**Solution:** Use postrender with Kustomize patches (see above)

### Issue: Init containers need probes

**Note:** Init containers are exempt from probe requirements. Only regular containers need probes.

### Issue: Sidecar injection adds non-compliant containers

**Solution:** Configure sidecar injector to add probes, or use mesh-native health checks.

### Issue: Operator-managed resources

**Solution:** Configure the operator (CRD) to generate compliant resources. Example for ECK:

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
spec:
  nodeSets:
    - podTemplate:
        spec:
          securityContext:
            seccompProfile:
              type: RuntimeDefault
```

## What DOESN'T Work

These approaches will NOT bypass safeguards:

| Approach | Result |
|----------|--------|
| `az aks safeguards update --level Warn` | Rejected on AKS Automatic |
| `az aks safeguards update --excluded-ns` | Rejected on AKS Automatic |
| Namespace annotations | No effect |
| Policy exemptions | Cannot exempt AKS Automatic policies |
| Gatekeeper constraint modifications | Managed by Azure, reverts |

## Constraint Reference

| Constraint Type | What It Checks |
|-----------------|----------------|
| `k8sazurev2containerenforceprob` | Probes on containers |
| `k8sazurev3containerlimits` | Resource requests |
| `k8sazurev1antiaffinityrules` | Anti-affinity for HA |
| `k8sazurev1blockdefaulttags` | No :latest tags |
| `k8sazurev1containernoprivilege` | No privileged containers |
| `k8sazurev1disallowedcapabilities` | Capability restrictions |

## Integration with Terraform Workflow

When adding a new Helm release:

1. **Check chart documentation** for probe/security options
2. **Set all required values** in the helm_release resource
3. **Run terraform plan** and review rendered manifests
4. **If chart lacks options**, create postrender with Kustomize
5. **Deploy and verify**: `kubectl get constraints -o wide`
6. **Document any special handling** in the .tf file comments
