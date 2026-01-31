# cimpl-azd Development Notes

This document tracks known issues, workarounds, and areas requiring improvement.

## Current State

**Status**: Platform layer deployment succeeds on existing clusters but has issues on fresh deployments due to AKS safeguards timing.

| Component | Status | Notes |
|-----------|--------|-------|
| AKS Automatic | Working | K8s 1.32, Istio asm-1-28 |
| Elasticsearch | Working | 3 nodes, dedicated node pool |
| Kibana | Working | 1 node, external access via Istio |
| PostgreSQL | Working | Bitnami chart with ECR images |
| MinIO | Working | Bitnami chart |
| cert-manager | Working | Let's Encrypt integration |
| Istio Gateway | Working | External IP assigned |

---

## Known Issues

### Issue 1: AKS Automatic Deployment Safeguards (CRITICAL)

**Problem**: AKS Automatic clusters have Deployment Safeguards **always enforced** with no option to relax or add namespace exclusions. This is by design - Microsoft explicitly states that the only supported path is to make workloads compliant.

**Key Limitation**:
```
ERROR: The request is not allowed because cimpl-dev is an automatic cluster.
```

**What Doesn't Work on AKS Automatic**:
- `az aks safeguards update --level Warn` - Rejected
- `az aks safeguards update --excluded-ns` - Rejected
- `az aks update --safeguards-level Warning` - Silently ignored
- Any attempt to relax or exclude namespaces from safeguards

**Policies That Are Enforced** (cannot be disabled):
| Policy | Requirement |
|--------|-------------|
| `k8sazurev1antiaffinityrules` | Deployments with replicas > 1 must have podAntiAffinity or topologySpreadConstraints |
| `k8sazurev2containerenforceprob` | All containers must have readinessProbe and livenessProbe |
| `k8sazurev1containerrequests` | All containers must have resource requests |
| `k8sazurev2containernolatestima` | No `:latest` image tags |
| `k8sazurev3allowedseccomp` | Must set seccompProfile (RuntimeDefault or Localhost) |
| Pod Security Standards | Baseline PSS enforced (runAsNonRoot, etc.) |

**Resolution Strategy**: Make all workloads compliant instead of trying to bypass safeguards.

**Required Chart Updates**:
1. **Probes**: Add readinessProbe and livenessProbe to all containers
2. **Resources**: Add resource requests to all containers
3. **Image tags**: Use specific version tags, not `:latest`
4. **Security context**: Add `seccompProfile: RuntimeDefault` to pod spec
5. **Anti-affinity**: Add topologySpreadConstraints or podAntiAffinity when replicas > 1
6. **Pod Security**: Ensure runAsNonRoot where possible

**Safeguards Script Update**:
The `ensure-safeguards.ps1` script should be updated to:
- Skip attempts to configure exclusions (won't work on Automatic)
- Wait for Gatekeeper to be ready
- Optionally dry-run actual platform manifests to verify compliance

**References**:
- [MS Answer confirming limitation](https://learn.microsoft.com/en-us/answers/questions/5694725/aks-automatic-gatekeeper-safeguards-block-sonobuoy)
- [Deployment Safeguards docs](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)

#### ECK Operator Probe Support (RESOLVED)

**Problem**: The ECK operator Helm chart (v2.16.0 - v3.2.0) does not expose probe configuration for the manager container, causing deployment failures on AKS Automatic clusters with Deployment Safeguards enforced.

**Error**:
```
Container <manager> in your Pod <elastic-operator-pod> has no <livenessProbe>
Container <manager> in your Pod <elastic-operator-pod> has no <readinessProbe>
```

**Solution**: Implemented Helm postrenderer with kustomize to inject tcpSocket probes on webhook port (9443).

**Implementation**:
- Created kustomize overlay at `platform/kustomize/eck-operator/` with Strategic Merge Patch
- Created postrenderer script at `platform/kustomize/eck-operator-postrender.sh`
- Updated `platform/helm_elastic.tf` to use postrenderer for elastic_operator deployment
- Probes are injected during Helm install without modifying the upstream chart

**Files**:
- `platform/kustomize/eck-operator/kustomization.yaml` - Kustomize configuration
- `platform/kustomize/eck-operator/statefulset-probes.yaml` - Probe patch for StatefulSet
- `platform/kustomize/eck-operator-postrender.sh` - Helm postrenderer script

---

### Issue 2: RBAC Permission Delay on Fresh Deploy

**Problem**: After cluster creation with Azure RBAC, the deploying user may not have immediate admin permissions, causing kubectl commands to fail.

**Error**:
```
Error: namespaces is forbidden: User "xxx" cannot create resource "namespaces"
```

**Current Workaround**:
- Manually grant "Azure Kubernetes Service RBAC Cluster Admin" role to user
- Wait ~5 minutes for RBAC propagation

**Proposed Fix**:
1. Add role assignment to infra terraform layer
2. Add RBAC verification step in pre/post-provision scripts

---

### Issue 3: Bitnami Chart Image Verification

**Problem**: Bitnami Helm charts require verified images. Using non-standard registries (like AWS ECR) triggers image verification failures.

**Error**:
```
Error: validation against image verification failed
```

**Current Workaround**:
- Set `global.security.allowInsecureImages: true` in chart values

**Proposed Fix**:
- Document this requirement in chart configurations
- Consider using verified images when available

---

### Issue 4: PostgreSQL Data Version Compatibility

**Problem**: PostgreSQL data files are version-specific. Upgrading chart versions may result in data incompatibility.

**Error**:
```
FATAL: database files are incompatible with server
```

**Current Workaround**:
- Pin image tag to match existing data version (currently PostgreSQL 18)

**Proposed Fix**:
- Use `lifecycle { ignore_changes = all }` to prevent accidental upgrades
- Document upgrade procedures requiring data migration

---

### Issue 5: Helm Provider Version Compatibility

**Problem**: Helm provider 3.x introduced breaking changes (e.g., `set` block syntax changes to `set_value`).

**Current Workaround**:
- Pin Helm provider to `~> 2.17.0` in versions.tf

**Proposed Fix**:
- Documented in versions.tf
- Will need migration plan for Helm provider 3.x

---

### Issue 6: Terraform State Management Across Layers

**Problem**: Two separate terraform states (infra + platform) can drift. Platform layer depends on infra outputs that may change.

**Current Workaround**:
- Pass cluster name and resource group explicitly via environment variables
- Post-provision script reads from terraform outputs if env vars missing

**Proposed Fix**:
1. Consider terraform workspaces or single state
2. Use terraform_remote_state data source to link layers
3. Document state management strategy

---

## Improvement Backlog

### Priority 1 - Reliability
- [ ] Add retry logic with exponential backoff for Helm deployments
- [ ] Add RBAC role assignment to infra layer
- [ ] Add safeguards wait/verification before platform deployment
- [ ] Implement health check gates between layers

### Priority 2 - User Experience
- [ ] Add `azd down` cleanup verification
- [ ] Add progress indicators for long-running operations
- [ ] Improve error messages with actionable guidance
- [ ] Add dry-run/plan mode for validation

### Priority 3 - Operations
- [ ] Add monitoring/alerting configuration
- [ ] Document backup/restore procedures
- [ ] Add log aggregation configuration
- [ ] Implement GitOps workflow option

### Priority 4 - Security
- [ ] Externalize PostgreSQL password to Key Vault
- [ ] Externalize MinIO credentials to Key Vault
- [ ] Add network policies for namespace isolation
- [ ] Configure pod-to-pod mTLS

---

## Testing Checklist

### Fresh Deploy (`azd up` from scratch)
- [ ] Resource group created with Contact tag
- [ ] AKS cluster healthy with all node pools
- [ ] Safeguards configured in Warning mode
- [ ] cert-manager operational
- [ ] Elasticsearch green health
- [ ] Kibana accessible
- [ ] PostgreSQL running
- [ ] MinIO running
- [ ] Istio ingress with external IP

### Destroy/Recreate Cycle
- [ ] `azd down --force --purge` completes
- [ ] No orphaned resources
- [ ] `azd up` succeeds without manual intervention
- [ ] All data persisted correctly (if using retained volumes)

---

## Environment Variables Reference

Required in `.azure/<env>/.env`:
```
AZURE_CONTACT_EMAIL=your-email@example.com
TF_VAR_acme_email=your-email@example.com
TF_VAR_kibana_hostname=kibana.yourdomain.com
```

Optional:
```
AZURE_LOCATION=eastus2  # Default region
```

---

## Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check safeguards
kubectl get constraints -o wide

# Check Elasticsearch
kubectl get elasticsearch -n elastic-search
kubectl get pods -n elastic-search

# Check PostgreSQL
kubectl get pods -n postgresql
kubectl exec -it postgresql-0 -n postgresql -- pg_isready

# Check MinIO
kubectl get pods -n minio

# Get Elasticsearch password
kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d

# Reconfigure safeguards manually
az aks update -g <rg> -n <cluster> --safeguards-level Warning --safeguards-excluded-ns "elastic-system,elastic-search,cert-manager,aks-istio-ingress,postgresql,minio"
```
