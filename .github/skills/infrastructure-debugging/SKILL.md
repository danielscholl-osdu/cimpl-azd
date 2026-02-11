---
name: infrastructure-debugging
description: "Use when investigating deployment failures, policy violations, connectivity issues, or any unexpected infrastructure behavior. Enforces systematic root cause analysis before attempting fixes."
metadata:
  version: 1.0.0
---

# Infrastructure Debugging

Systematic root cause investigation for infrastructure issues. Adapted from superpowers systematic-debugging for Infrastructure as Code workflows.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Quick fixes in infrastructure mask deeper problems and create technical debt. A "working" deployment that you don't understand will break again.

## When to Use This Skill

- Deployment failures (terraform apply, helm install, azd up)
- Policy violations (AKS Safeguards, Azure Policy, Gatekeeper)
- Resource creation errors
- Connectivity issues between components
- Unexpected behavior after changes
- "It was working yesterday" situations

## Quick Reference

| Phase | Action | Output |
|-------|--------|--------|
| 1. Gather Evidence | Collect logs, state, errors | Evidence document |
| 2. Recent Changes | Check git history, terraform state | Change list |
| 3. Hypothesis | Form single testable theory | Clear hypothesis |
| 4. Verify Fix | Test minimal change, document | Verified solution |

## The Four-Phase Process

### Phase 1: Gather Evidence

**STOP. Do not attempt any fix yet.**

Collect information systematically:

```bash
# Terraform state and errors
terraform state list
terraform state show <resource>
terraform plan 2>&1 | tee plan-output.txt

# Kubernetes cluster state
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl describe pod <failing-pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous

# AKS Safeguards / Gatekeeper
kubectl get constraints -o wide
kubectl get k8sazurev1antiaffinityrules -o wide
kubectl get k8sazurev2containerenforceprob -o wide

# Azure Activity Log (recent failures)
az monitor activity-log list --resource-group <rg> --status Failed --max-events 10
```

**Document what you find before proceeding.**

### Phase 2: Check Recent Changes

Infrastructure issues often correlate with recent changes:

```bash
# Git history
git log --oneline -10
git diff HEAD~3 -- infra/ platform/ scripts/

# Terraform state changes
terraform state pull > current-state.json
# Compare with known good state if available

# Helm release history
helm history <release> -n <namespace>
```

**Questions to answer:**
- What changed since it last worked?
- Who made the change and why?
- Was there a provider/chart version update?

### Phase 3: Form and Test Hypothesis

**Form ONE clear hypothesis:**

> "The deployment fails because [specific cause] which results in [observed symptom]"

**Test minimally:**
- Change ONE variable at a time
- Use `terraform plan` before `apply`
- Test in isolation when possible

**If 3+ hypotheses fail:** Stop. Question your assumptions. The problem is likely architectural, not a simple fix.

### Phase 4: Implement and Verify Fix

Once root cause is confirmed:

1. **Document the root cause** in notes.md or as PR comment
2. **Implement minimal fix** addressing the root cause
3. **Verify the fix works:**
   ```bash
   # Full deployment verification
   terraform plan  # Should show expected changes only
   terraform apply
   kubectl get pods -A | grep -v Running  # Should be empty
   ```
4. **Verify no regressions** - run full validation suite

## Common Infrastructure Issues

### AKS Safeguards Violations

**Symptoms:**
- Pods stuck in Pending
- Admission webhook errors
- Constraint violations in `kubectl get constraints`

**Investigation:**
```bash
# Find which constraints are violated
kubectl get constraints -o wide | grep -v "0 *$"

# Get violation details
kubectl describe k8sazurev2containerenforceprob
```

**Root causes:**
- Missing probes (readinessProbe, livenessProbe)
- Missing resource requests
- Using :latest image tag
- Missing seccompProfile
- Missing anti-affinity (replicas > 1)

### Terraform State Issues

**Symptoms:**
- "Resource already exists" errors
- Orphaned resources
- State/reality mismatch

**Investigation:**
```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show <resource>

# Refresh state from reality
terraform refresh
```

**Common causes:**
- Manual changes outside Terraform
- Failed apply left partial state
- Import missing for existing resources

### Helm Release Failures

**Symptoms:**
- Helm release stuck in pending-install
- Values not applied correctly
- Chart version conflicts

**Investigation:**
```bash
# Release status
helm status <release> -n <namespace>

# Release history
helm history <release> -n <namespace>

# Get rendered manifests
helm get manifest <release> -n <namespace>

# Get applied values
helm get values <release> -n <namespace>
```

### Two-Phase Deployment Failures

**Symptoms:**
- Platform deployment fails on fresh cluster
- "Gatekeeper not ready" errors
- Timeout in ensure-safeguards.ps1

**Investigation:**
```bash
# Check Gatekeeper status
kubectl get pods -n gatekeeper-system

# Check constraint status
kubectl get constraints -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.totalViolations}{"\n"}{end}'
```

**Root cause:** Azure Policy eventual consistency - constraints not fully reconciled yet.

## Red Flags - Stop and Reconsider

If you find yourself thinking:

| Thought | Reality |
|---------|---------|
| "Let me just try this quick fix" | You don't understand the problem yet |
| "I'll add a retry/sleep to work around it" | You're masking the real issue |
| "It works locally, must be Azure's fault" | Check your assumptions |
| "Let me try multiple changes at once" | You won't know what fixed it |
| "This is the 4th thing I've tried" | Step back, question architecture |

## Evidence Documentation Template

When investigating, document:

```markdown
## Issue: [Brief description]

### Symptoms
- What error message?
- What command failed?
- When did it start?

### Evidence Gathered
- Terraform plan output: [summary]
- kubectl describe: [key findings]
- Recent changes: [git commits]

### Hypothesis
[Single clear statement]

### Test Results
- Test 1: [result]
- Test 2: [result]

### Root Cause
[Confirmed cause]

### Fix Applied
[What was changed and why]

### Verification
[Commands run and their output]
```

## Integration with Project Workflow

After fixing an infrastructure issue:

1. **Update notes.md** if it's a known issue pattern
2. **Update docs/architecture.md** if it reveals architectural insight
3. **Consider adding to CI checks** if it could be caught earlier
4. **Update copilot-instructions.md** if agents should know about it
