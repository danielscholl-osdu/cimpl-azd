# Skills Analysis for cimpl-azd

This document analyzes which skills from the superpowers plugin and SDLC toolkit would be valuable for the cimpl-azd project, along with recommendations for GitHub Copilot CLI compatible implementations.

---

## Table of Contents

1. [Current Setup](#current-setup)
2. [Skill Mapping Analysis](#skill-mapping-analysis)
3. [High-Value Conversions](#high-value-conversions)
4. [Project-Specific Skills to Create](#project-specific-skills-to-create)
5. [Implementation Recommendations](#implementation-recommendations)
6. [Proposed Directory Structure](#proposed-directory-structure)

---

## Current Setup

### Existing GitHub Copilot Configuration

```
.github/
├── copilot-instructions.md          # Main repository instructions
├── agents/
│   └── cimpl-azd.agent.md           # Repository-specific agent
├── instructions/
│   ├── infra.instructions.md        # applyTo: infra/**/*.tf
│   ├── platform.instructions.md     # applyTo: platform/**/*.tf
│   └── scripts.instructions.md      # applyTo: scripts/**/*.ps1
├── prompts/
│   └── plan-change.prompt.md        # Change planning prompt
└── skills/
    └── terraform/                   # Comprehensive Terraform skill
        ├── SKILL.md
        └── references/
```

### Project Characteristics

| Aspect | Details |
|--------|---------|
| **Type** | Infrastructure as Code |
| **Languages** | Terraform (HCL), PowerShell |
| **Platform** | Azure Kubernetes Service (AKS) Automatic |
| **Constraints** | AKS Safeguards (non-negotiable), Two-phase deployment |
| **CI/CD** | GitHub Actions (fmt, syntax, secrets scan) |

---

## Skill Mapping Analysis

### Superpowers Skills Assessment

| Skill | Relevance | Rationale | Priority |
|-------|-----------|-----------|----------|
| **systematic-debugging** | **HIGH** | Infrastructure issues need root cause analysis, not quick fixes | P1 |
| **verification-before-completion** | **HIGH** | IaC claims need explicit verification (kubectl, terraform plan) | P1 |
| **brainstorming** | **MEDIUM** | Useful before infrastructure changes, but simpler than app dev | P2 |
| **writing-plans** | **MEDIUM** | Already have plan-change.prompt.md; could enhance | P2 |
| **executing-plans** | **MEDIUM** | Batch execution for multi-step changes | P2 |
| **test-driven-development** | **LOW** | Less applicable to IaC (no traditional unit tests) | P3 |
| **requesting-code-review** | **MEDIUM** | Useful for PR preparation | P2 |
| **receiving-code-review** | **LOW** | Standard PR workflow | P3 |
| **using-git-worktrees** | **LOW** | Less relevant for IaC projects | P3 |
| **dispatching-parallel-agents** | **LOW** | IaC changes are typically sequential | P3 |
| **subagent-driven-development** | **LOW** | Overkill for IaC changes | P3 |

### SDLC Skills Assessment

| Skill | Relevance | Rationale | Priority |
|-------|-----------|-----------|----------|
| **sdlc:chore** | **HIGH** | Perfect for maintenance (upgrades, cleanup, refactoring) | P1 |
| **sdlc:bug** | **HIGH** | Infrastructure debugging workflow | P1 |
| **sdlc:feature** | **MEDIUM** | New infrastructure component planning | P2 |
| **sdlc:commit** | **MEDIUM** | Structured commits for IaC | P2 |
| **sdlc:pull_request** | **MEDIUM** | PR creation workflow | P2 |
| **sdlc:prime** | **MEDIUM** | Codebase familiarization | P2 |
| **sdlc:init** | **LOW** | Already have CLAUDE.md setup | P3 |
| **sdlc:tdd** | **LOW** | Not applicable to IaC | P3 |
| **sdlc:implement** | **LOW** | Too generic for IaC | P3 |
| **sdlc:test_plan** | **LOW** | No traditional test suite | P3 |

---

## High-Value Conversions

### 1. Systematic Debugging → `infrastructure-debugging`

**Why**: Infrastructure issues (deployment failures, policy violations, connectivity) need systematic root cause analysis. Quick fixes often mask deeper problems.

**Adaptation for IaC**:
- Phase 1: Gather evidence (terraform state, kubectl logs, Azure Activity Log)
- Phase 2: Check recent changes (git diff, terraform plan)
- Phase 3: Hypothesis testing (isolated changes)
- Phase 4: Verified fix with documentation

**GitHub Copilot Format**: `.github/skills/infrastructure-debugging/SKILL.md`

---

### 2. Verification Before Completion → `verify-infrastructure`

**Why**: IaC changes can appear successful but have hidden issues. "terraform apply succeeded" doesn't mean the infrastructure works.

**Verification Commands for cimpl-azd**:
```bash
# Cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Safeguards compliance
kubectl get constraints -o wide

# Component-specific checks
kubectl get elasticsearch -n elasticsearch
kubectl exec -it postgresql-0 -n postgresql -- pg_isready
```

**GitHub Copilot Format**: `.github/skills/verify-infrastructure/SKILL.md`

---

### 3. SDLC Chore → `maintenance-task`

**Why**: IaC maintenance (version bumps, provider updates, cleanup) needs structured approach to avoid breaking changes.

**Adaptation for IaC**:
- Check version constraints before upgrades
- Verify compatibility (Helm provider 2.x vs 3.x)
- Run terraform plan to preview changes
- Update documentation

**GitHub Copilot Format**: `.github/prompts/maintenance-task.prompt.md`

---

### 4. SDLC Bug → `infrastructure-issue`

**Why**: Infrastructure bugs (policy violations, deployment failures) need structured investigation.

**Adaptation for IaC**:
- Identify failing component
- Check safeguards constraints
- Review recent changes
- Document root cause

**GitHub Copilot Format**: `.github/prompts/infrastructure-issue.prompt.md`

---

### 5. Brainstorming → `design-component`

**Why**: New infrastructure components need design validation before implementation.

**Adaptation for IaC**:
- Safeguards compliance check
- Resource requirements
- Integration with existing components
- Rollback strategy

**GitHub Copilot Format**: `.github/prompts/design-component.prompt.md`

---

## Project-Specific Skills to Create

### 1. `aks-safeguards` Skill

**Purpose**: Validate workloads against AKS Automatic Deployment Safeguards

**Key Content**:
```markdown
## AKS Safeguards Compliance Checklist

ALL workloads MUST have:
- [ ] readinessProbe AND livenessProbe on all containers
- [ ] resource requests on all containers
- [ ] Specific image tags (no :latest)
- [ ] seccompProfile: RuntimeDefault in pod spec
- [ ] topologySpreadConstraints or podAntiAffinity (if replicas > 1)
- [ ] Pod Security Standards compliance (runAsNonRoot, etc.)
- [ ] Unique selector labels per service
```

**Trigger**: When creating/modifying Helm charts or Kubernetes manifests

---

### 2. `two-phase-deployment` Skill

**Purpose**: Explain the two-phase deployment pattern and why it's required

**Key Content**:
- Phase 1: ensure-safeguards.ps1 (Gatekeeper readiness gate)
- Phase 2: deploy-platform.ps1 (platform deployment)
- Why: Azure Policy eventual consistency
- Never modify without understanding implications

**Trigger**: When modifying deployment scripts or orchestration

---

### 3. `helm-compliance` Skill

**Purpose**: Ensure Helm releases are AKS Safeguards compliant

**Key Content**:
- Required values for probes
- Postrender patterns for probe injection
- seccomp profile configuration
- Anti-affinity patterns

**Trigger**: When adding/modifying Helm releases in platform/

---

### 4. `terraform-validate` Prompt

**Purpose**: Run standard Terraform validation workflow

**Content**:
```markdown
Run the following validation checks:

1. Format check:
   terraform fmt -check -recursive ./infra
   terraform fmt -check -recursive ./platform

2. Validate (only if providers available):
   cd infra && terraform validate
   cd platform && terraform validate

3. Report any issues found
```

---

### 5. `powershell-validate` Prompt

**Purpose**: Validate PowerShell scripts

**Content**:
```markdown
Validate all PowerShell scripts in scripts/:

pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; foreach ($s in $scripts) { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$null); Write-Host "✓ $($s.Name)" }'
```

---

## Implementation Recommendations

### Priority 1: Create These First

| Item | Type | Location |
|------|------|----------|
| `infrastructure-debugging` | skill | `.github/skills/infrastructure-debugging/SKILL.md` |
| `verify-infrastructure` | skill | `.github/skills/verify-infrastructure/SKILL.md` |
| `aks-safeguards` | skill | `.github/skills/aks-safeguards/SKILL.md` |
| `validate-terraform` | prompt | `.github/prompts/validate-terraform.prompt.md` |
| `validate-powershell` | prompt | `.github/prompts/validate-powershell.prompt.md` |

### Priority 2: Enhance Existing

| Item | Type | Action |
|------|------|--------|
| `plan-change.prompt.md` | prompt | Add verification steps and safeguards checklist |
| `copilot-instructions.md` | instructions | Add skill references |

### Priority 3: Add Later

| Item | Type | Location |
|------|------|----------|
| `design-component` | prompt | `.github/prompts/design-component.prompt.md` |
| `maintenance-task` | prompt | `.github/prompts/maintenance-task.prompt.md` |
| `infrastructure-issue` | prompt | `.github/prompts/infrastructure-issue.prompt.md` |
| `two-phase-deployment` | skill | `.github/skills/two-phase-deployment/SKILL.md` |
| `helm-compliance` | skill | `.github/skills/helm-compliance/SKILL.md` |

---

## Proposed Directory Structure

```
.github/
├── copilot-instructions.md              # [existing] Main instructions
├── agents/
│   └── cimpl-azd.agent.md               # [existing] Repository agent
├── instructions/
│   ├── infra.instructions.md            # [existing] Terraform infra guidance
│   ├── platform.instructions.md         # [existing] Terraform platform guidance
│   └── scripts.instructions.md          # [existing] PowerShell guidance
├── prompts/
│   ├── plan-change.prompt.md            # [existing] Change planning
│   ├── validate-terraform.prompt.md     # [NEW] Terraform validation
│   ├── validate-powershell.prompt.md    # [NEW] PowerShell validation
│   ├── design-component.prompt.md       # [NEW] Component design
│   ├── maintenance-task.prompt.md       # [NEW] Maintenance workflow
│   └── infrastructure-issue.prompt.md   # [NEW] Issue investigation
└── skills/
    ├── terraform/                       # [existing] Terraform skill
    │   ├── SKILL.md
    │   └── references/
    ├── infrastructure-debugging/        # [NEW] Systematic debugging for IaC
    │   └── SKILL.md
    ├── verify-infrastructure/           # [NEW] Verification workflow
    │   └── SKILL.md
    ├── aks-safeguards/                  # [NEW] AKS compliance
    │   └── SKILL.md
    ├── two-phase-deployment/            # [NEW] Deployment pattern
    │   └── SKILL.md
    └── helm-compliance/                 # [NEW] Helm compliance
        └── SKILL.md
```

---

## GitHub Copilot CLI Format Reference

### Skill Format (SKILL.md)
```yaml
---
name: skill-name
description: "Use when [triggering condition]. [Brief purpose]."
license: MIT  # optional
metadata:     # optional
  author: Your Name
  version: 1.0.0
---

# Skill Title

## When to Use This Skill

[Clear triggering conditions]

## Core Process

[Step-by-step workflow]

## Common Mistakes

[What to avoid]

## Quick Reference

[Tables, checklists, commands]
```

### Prompt Format (.prompt.md)
```yaml
---
agent: "agent"  # or specific agent name
description: "Brief description of what this prompt does."
---

[Prompt content with instructions]
```

### Instructions Format (.instructions.md)
```yaml
---
applyTo: "glob/pattern/**/*.ext"
---

# Context-Specific Guidance

[Rules that apply when editing matching files]
```

---

## Next Steps

1. **Review this analysis** and confirm priorities
2. **Start with P1 items** (infrastructure-debugging, verify-infrastructure, aks-safeguards)
3. **Test with actual workflows** to refine content
4. **Iterate based on usage** - skills should evolve with project needs

---

## Skills NOT Recommended for Conversion

These superpowers skills are not well-suited for this IaC project:

| Skill | Reason |
|-------|--------|
| `test-driven-development` | No traditional unit tests in IaC |
| `using-git-worktrees` | Single-branch IaC workflow is typical |
| `dispatching-parallel-agents` | IaC changes are sequential |
| `subagent-driven-development` | Overkill for infrastructure changes |
| `writing-skills` | Meta-skill, not project-specific |
| `using-superpowers` | Claude Code specific bootstrapping |

These SDLC skills overlap with existing setup or aren't applicable:

| Skill | Reason |
|-------|--------|
| `sdlc:init` | Already have comprehensive instructions |
| `sdlc:tdd` | Not applicable to IaC |
| `sdlc:implement` | Too generic; use project-specific prompts |
| `sdlc:test_plan` | No test suite to document |
