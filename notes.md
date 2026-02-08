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
| MinIO | Working | Official MinIO chart |
| cert-manager | Working | Let's Encrypt integration |
| Istio Gateway | Working | External IP assigned |

---

## Recent Changes

The following improvements were completed in the latest sprint:

- **kubectl pre-provision check** (PR #35): kubectl is now validated during pre-provision with minimum version 1.28.0
- **Gateway API CRDs Terraform-managed** (PR for Issue #2): CRDs are now managed via `kubectl_manifest` with `for_each` instead of `local-exec` scripts, pinned at `platform/crds/gateway-api-v1.2.1.yaml`
- **Istio STRICT mTLS for Elasticsearch** (PR #34): PeerAuthentication enforces STRICT mTLS in the `elastic-search` namespace
- **Credentials externalized** (PR #36): PostgreSQL and MinIO credentials are now configurable via Terraform variables (`TF_VAR_postgresql_password`, `TF_VAR_minio_root_user`, `TF_VAR_minio_root_password`)
- **`ignore_changes = all` removed** (PR #37): Lifecycle blocks removed from all four Helm releases (elastic, postgresql, minio, cert_manager), enabling proper Terraform drift detection

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
| `k8sazurev1uniqueserviceselecto` | Each service must have unique selector labels |
| Pod Security Standards | Baseline PSS enforced (runAsNonRoot, etc.) |

**Resolution Strategy**: Make all workloads compliant instead of trying to bypass safeguards.

**Required Chart Updates**:
1. **Probes**: Add readinessProbe and livenessProbe to all containers
2. **Resources**: Add resource requests to all containers
3. **Image tags**: Use specific version tags, not `:latest`
4. **Security context**: Add `seccompProfile: RuntimeDefault` to pod spec
5. **Anti-affinity**: Add topologySpreadConstraints or podAntiAffinity when replicas > 1
6. **Pod Security**: Ensure runAsNonRoot where possible
7. **Service Selectors**: Use `commonLabels` with `app.kubernetes.io/component` to ensure unique service selectors

**Safeguards Script Update**:
The `ensure-safeguards.ps1` script should be updated to:
- Skip attempts to configure exclusions (won't work on Automatic)
- Wait for Gatekeeper to be ready
- Optionally dry-run actual platform manifests to verify compliance

**cert-manager cainjector Probe Solution**:
The cert-manager Helm chart (v1.17.0 - v1.19.2) does not expose probe configuration for the cainjector component. To comply with AKS Automatic safeguards:
- Solution: Use Helm postrender with kustomize to inject tcpSocket probes
- Implementation: `platform/postrender-cert-manager.sh` applies patches from `platform/kustomize/cert-manager/`
- Probes use port 9402 (metrics endpoint) via tcpSocket since cainjector lacks an HTTP healthz endpoint
- This approach avoids modifying the upstream chart or switching to raw manifests

**References**:
- [MS Answer confirming limitation](https://learn.microsoft.com/en-us/answers/questions/5694725/aks-automatic-gatekeeper-safeguards-block-sonobuoy)
- [Deployment Safeguards docs](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)
- [cert-manager issue #5626](https://github.com/cert-manager/cert-manager/issues/5626)

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
- Pin image tag to match data version (currently done)
- Document upgrade procedures requiring data migration

---

### Issue 5: Helm Provider Version Compatibility (RESOLVED)

**Problem**: Helm provider 3.x introduced breaking changes (`set {}` blocks → `set = [...]` list syntax, `postrender {}` → `postrender = {}`).

**Resolution**:
- Migrated to Helm provider `~> 3.1` and Kubernetes provider `~> 3.0`
- Converted all `set {}` blocks to `set = [...]` list-of-objects syntax
- Converted all `postrender {}` blocks to `postrender = {}` object assignment
- Kept deprecated `kubernetes_namespace`/`kubernetes_secret` resource names (v1 rename deferred to provider v4)

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

### Issue 7: Service Selector Violations - MinIO, PostgreSQL, Elasticsearch (RESOLVED)

**Problem**: Multiple services with the same selector violate AKS Automatic's `K8sAzureV1UniqueServiceSelector` policy. This affects:
- MinIO: Both `minio` and `minio-console` services had the same pod selector
- PostgreSQL: Both `postgresql` and `postgresql-hl` (headless) services had the same selector
- Elasticsearch: Both `elasticsearch-es-http` and `elasticsearch-es-transport` services had the same selector

**Error Messages**:
```
admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8sazurev1uniqueserviceselecto-...] same selector as service <minio-console> in namespace <minio>
admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8sazurev1uniqueserviceselecto-...] same selector as service <postgresql> in namespace <postgresql>
admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8sazurev1uniqueserviceselecto-...] same selector as service <elasticsearch-es-transport> in namespace <elastic-search>
```

**Resolution**:

**MinIO**: Added `commonLabels` in Helm values (`platform/helm_minio.tf`):
- Added `app.kubernetes.io/component: minio-server` via `commonLabels`
- This makes the main `minio` service selector unique from `minio-console`

**PostgreSQL**: Used Helm postrender with kustomize patches (`platform/postrender-postgresql.sh`):
- Added `postgresql.service/variant: primary` label to StatefulSet pods via `platform/kustomize/postgresql/statefulset-label.yaml`
- Added same label to regular service selector via `platform/kustomize/postgresql/service-selector.yaml`
- Headless service (`postgresql-hl`) keeps default selector

**Elasticsearch**: Configured ECK's native service selector overrides in `platform/helm_elastic.tf`:
- Added `elasticsearch.service/http: "true"` and `elasticsearch.service/transport: "true"` labels to ES pods via `nodeSets[].podTemplate.metadata.labels`
- Configured `spec.http.service.spec.selector` to require `elasticsearch.service/http: "true"`
- Configured `spec.transport.service.spec.selector` to require `elasticsearch.service/transport: "true"`
- Internal-HTTP and Default (StatefulSet headless) services use default selectors (automatically unique)
- All services still route to the same pods, but selectors are now unique
- **Note**: When adding new nodeSets, each must include both labels for service connectivity

This approach uses ECK's documented service customization capabilities rather than external kustomize patches.

**Verification** (run after ECK upgrades): `kubectl get svc -n elastic-search -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.selector}{"\n"}{end}'`

**References**:
- [Kubernetes Common Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [ECK HTTP Service Settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-http-settings-tls-sans.html)
- Related to issues #8, #11, and #29

---

## Improvement Backlog

### Priority 1 - Reliability
- [ ] Add retry logic with exponential backoff for Helm deployments
- [ ] Add RBAC role assignment to infra layer
- [x] Add safeguards wait/verification before platform deployment (two-phase behavioral gate)
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
- [x] Externalize PostgreSQL password to Terraform variable (PR #36)
- [x] Externalize MinIO credentials to Terraform variables (PR #36)
- [ ] Externalize credentials to Azure Key Vault for production
- [ ] Add network policies for namespace isolation
- [x] Configure pod-to-pod mTLS (Istio STRICT mTLS for Elasticsearch, PR #34)

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
AZURE_LOCATION=eastus2                    # Default region
TF_VAR_postgresql_password=<password>     # PostgreSQL admin password (auto-generated if not set)
TF_VAR_minio_root_user=<username>         # MinIO root user (default: minioadmin)
TF_VAR_minio_root_password=<password>     # MinIO root password (auto-generated if not set)
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

# Reconfigure safeguards manually (space-separated namespaces)
az aks safeguards update -g <rg> -n <cluster> --level Warn --excluded-ns elastic-system elastic-search cert-manager aks-istio-ingress postgresql minio
```
