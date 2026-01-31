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

### Issue 1: AKS Safeguards Race Condition on Fresh Deploy

**Problem**: On a fresh `azd up`, the post-provision script runs immediately after cluster creation, but AKS safeguards (Gatekeeper) policies haven't fully propagated. Helm deployments fail with violations like:
- Missing health probes
- Duplicate service selectors
- Missing resource limits

**Error Examples**:
```
Error: admission webhook "validation.gatekeeper.sh" denied the request
[azurepolicy-k8sazurev3containerrestricted-xxx] Container 'postgresql' must define readinessProbe and livenessProbe
```

**Root Cause Analysis**:
- Azure Policy add-on is enabled at cluster creation in `infra/aks.tf`
- Gatekeeper constraints are installed asynchronously after AKS provisioning
- The script sets safeguards to Warning mode but doesn't wait for Gatekeeper reconciliation
- Platform charts already include probes and resource limits - the error is timing, not config

**Implemented Fix: Two-Phase Deployment with Behavioral Gate**

The solution uses server-side dry-run to verify that namespace exclusions are actually working:

```
postprovision (orchestrator)
  │
  ├── Phase 1: ensure-safeguards.ps1 (GATE)
  │     ├── Configure safeguards to Warning mode with excluded namespaces
  │     ├── Wait for Gatekeeper controller ready
  │     ├── Create target namespaces (elastic-search, postgresql, minio, etc.)
  │     └── Dry-run non-compliant Deployment in each namespace
  │         └── If any dry-run FAILS → exit with actionable error
  │         └── If all dry-runs PASS → exclusions verified, proceed
  │
  └── Phase 2: deploy-platform.ps1 (only runs if Phase 1 succeeds)
        ├── Deploy platform Terraform
        └── Verify component health
```

**Why behavioral gate over constraint mode checking:**
- Constraint enforcement mode (`warn`/`deny`) doesn't reflect namespace exclusions
- Another policy assignment at subscription/management group level may enforce the same definitions
- Dry-run tests **actual admission behavior** - if it passes, the real deployment will work

**Key insight from Azure docs**: Policy assignments can take up to 20 minutes to sync into each cluster. The behavioral dry-run gate handles this by testing actual admission behavior rather than waiting for metadata to reconcile.

Key features:
1. **Behavioral verification**: Tests what matters (admission behavior) not metadata (constraint modes)
2. **Fail fast with diagnosis**: If exclusions aren't working, shows which namespaces failed
3. **Actionable errors**: Provides debug commands and possible causes
4. **Azure Policy detection**: Skips checks entirely if Azure Policy add-on not enabled
5. **Namespace wait**: Waits for gatekeeper-system namespace to appear (handles fresh clusters)
6. **Dual deployment check**: Tries both `gatekeeper-controller` and `gatekeeper-controller-manager`
7. **Bypass escape hatch**: `SKIP_SAFEGUARDS_WAIT=true` environment variable for debugging

**Manual retry** (if Phase 1 fails):
```bash
./scripts/ensure-safeguards.ps1  # Retry Phase 1
./scripts/deploy-platform.ps1    # Run Phase 2 after Phase 1 succeeds
```

**Future Enhancement**:
- Move safeguards config + wait into infra layer using `azapi_update_resource` + `time_sleep`
- This would make postprovision only handle platform deployment

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
