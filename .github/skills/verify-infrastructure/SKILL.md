---
name: verify-infrastructure
description: "Use before claiming any infrastructure task is complete. Enforces evidence-based verification with actual commands and output inspection."
metadata:
  version: 1.0.0
  adapted-from: superpowers:verification-before-completion
---

# Verify Infrastructure

Evidence-based verification for infrastructure changes. Never claim completion without running verification commands and inspecting their output.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

"Terraform apply succeeded" does not mean the infrastructure works. "No errors" does not mean it's correct.

## When to Use This Skill

- Before claiming any deployment is complete
- Before marking a task as done
- Before creating a PR for infrastructure changes
- Before saying "it's working now"
- After any fix or change

## The Verification Gate

Before ANY completion claim, follow this process:

```
1. IDENTIFY  → What command(s) prove this claim?
2. RUN       → Execute the command(s) fresh, completely
3. READ      → Full output, check exit codes, count issues
4. VERIFY    → Does output actually confirm the claim?
5. ONLY THEN → Make the claim with evidence
```

## Quick Reference: Verification Commands

### Cluster Health

```bash
# Node status - all should be Ready
kubectl get nodes
# Expected: All nodes show STATUS=Ready

# Pod health - should return empty (no non-running pods)
kubectl get pods -A | grep -v Running | grep -v Completed
# Expected: Only header line, no failing pods

# Recent events - check for warnings
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### AKS Safeguards Compliance

```bash
# All constraints - check totalViolations column
kubectl get constraints -o wide
# Expected: All show 0 violations

# Specific constraint details
kubectl get k8sazurev1antiaffinityrules -o wide
kubectl get k8sazurev2containerenforceprob -o wide
kubectl get k8sazurev3containerlimits -o wide
```

### Component-Specific Verification

#### Elasticsearch
```bash
# Cluster status
kubectl get elasticsearch -n elastic-search
# Expected: HEALTH=green, PHASE=Ready

# All pods running
kubectl get pods -n elastic-search
# Expected: All pods Running, READY x/x

# Cluster health API
kubectl exec -it elasticsearch-es-default-0 -n elastic-search -- \
  curl -s -k -u "elastic:$(kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d)" \
  https://localhost:9200/_cluster/health
# Expected: "status":"green"
```

#### Kibana
```bash
# Kibana status
kubectl get kibana -n elastic-search
# Expected: HEALTH=green

# Pod running
kubectl get pods -n elastic-search -l kibana.k8s.elastic.co/name=kibana
# Expected: Running, Ready
```

#### PostgreSQL
```bash
# Pod status
kubectl get pods -n postgresql
# Expected: Running, Ready

# Database ready
kubectl exec -it postgresql-0 -n postgresql -- pg_isready
# Expected: accepting connections

# Can connect
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -c "SELECT 1"
# Expected: Returns 1
```

#### MinIO
```bash
# Pod status
kubectl get pods -n minio
# Expected: Running, Ready

# Service accessible
kubectl get svc -n minio
```

#### cert-manager
```bash
# Pods running
kubectl get pods -n cert-manager
# Expected: All Running

# Certificates issued
kubectl get certificates -A
# Expected: READY=True for all

# ClusterIssuer ready
kubectl get clusterissuer
# Expected: READY=True
```

#### Istio Ingress
```bash
# External IP assigned
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external
# Expected: EXTERNAL-IP is not <pending>

# Gateway configured
kubectl get gateway -A
# Expected: Gateway exists

# HTTPRoutes configured
kubectl get httproute -A
```

### Terraform Verification

```bash
# Plan shows no unexpected changes
terraform plan
# Expected: "No changes" or only expected changes

# State matches reality
terraform refresh
terraform plan
# Expected: No drift detected

# Output values correct
terraform output
# Expected: Values match expectations
```

### CI Checks (Pre-PR)

```bash
# Terraform formatting
terraform fmt -check -recursive ./infra
terraform fmt -check -recursive ./platform
# Expected: Exit code 0

# PowerShell syntax
pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; $hasError = $false; foreach ($s in $scripts) { $errors = $null; $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$errors); if ($errors) { Write-Host "ERROR: $($s.Name)"; $hasError = $true } else { Write-Host "OK: $($s.Name)" } }; if ($hasError) { exit 1 }'
# Expected: All OK, exit code 0

# No secrets in code
rg -i "(password|secret|api.?key|token)\s*[:=]" --glob '!*.example' --glob '!.git/' .
# Expected: No matches or only documented demo values
```

## Verification Checklist by Task Type

### After Deploying New Component

- [ ] `kubectl get pods -n <namespace>` shows all Running
- [ ] `kubectl get constraints -o wide` shows 0 violations
- [ ] Component-specific health check passes
- [ ] Can access service (if applicable)
- [ ] Logs show no errors: `kubectl logs <pod> -n <namespace>`

### After Fixing a Bug

- [ ] Original error no longer occurs
- [ ] `kubectl get pods -A | grep -v Running` is empty
- [ ] Related components still work
- [ ] No new errors introduced

### After Terraform Changes

- [ ] `terraform plan` shows only expected changes
- [ ] `terraform apply` completes successfully
- [ ] Resources exist in Azure portal/CLI
- [ ] Kubernetes resources are created/updated

### Before Creating PR

- [ ] `terraform fmt -check -recursive` passes
- [ ] PowerShell syntax validation passes
- [ ] No secrets in code
- [ ] Documentation updated if needed
- [ ] All components healthy after changes

## Red Flags - Claims Without Evidence

Never say these without running verification:

| Claim | Required Evidence |
|-------|-------------------|
| "Deployment succeeded" | kubectl get pods shows all Running |
| "The fix worked" | Original error gone + no new errors |
| "Tests pass" | Actual test output with exit code 0 |
| "It's healthy" | Health check command output |
| "No issues" | Constraint check shows 0 violations |
| "Ready for PR" | All CI checks pass locally |

## Evidence Documentation

When claiming completion, include:

```markdown
## Verification Evidence

### Commands Run
```bash
kubectl get pods -A | grep -v Running
# Output: [paste actual output]

kubectl get constraints -o wide
# Output: [paste actual output]
```

### Results
- All pods running: YES
- Constraint violations: 0
- Component health: [status]

### Conclusion
[Specific claim with evidence reference]
```

## Common Verification Mistakes

| Mistake | Correct Approach |
|---------|------------------|
| Trusting "apply succeeded" | Run kubectl checks after apply |
| Checking once, claiming later | Re-run verification immediately before claiming |
| Partial checks | Run full verification suite |
| Ignoring warnings | Investigate all warnings |
| Assuming previous state | Always verify current state fresh |
