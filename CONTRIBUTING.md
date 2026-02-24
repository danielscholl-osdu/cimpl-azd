# Contributing Guide

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.x

---

## Branching Model

This repository uses a three-branch promotion model:

```
feature/* ──► dev ──► preview ──► main
              │         │          │
              │         │          └─ Release (tagged, production-ready)
              │         └─ Pre-release validation
              └─ Integration (daily work)
```

| Branch | Purpose | Merges from |
|--------|---------|-------------|
| `feature/*` | Individual changes | — |
| `dev` | Integration branch, daily work | Feature branches (via PR) |
| `preview` | Pre-release validation | `dev` (via squad-promote workflow) |
| `main` | Production releases | `preview` (via squad-promote workflow) |

### Workflow

1. Create a feature branch from `dev`
2. Make changes, run quality checks locally
3. Open a PR targeting `dev`
4. After review and CI pass, merge to `dev`
5. Promotion to `preview` and `main` happens via the `squad-promote` workflow (maintainers only)

### Branch rules

- **Never push directly to `main` or `preview`** — use the promotion workflow
- **Never commit** `.squad/`, `.ai-team/`, `team-docs/`, or `docs/proposals/` to `main` or `preview` — the main-guard workflow blocks these paths

---

## Making Changes

### 1. Create a feature branch

```bash
git checkout dev
git pull origin dev
git checkout -b feature/my-change
```

### 2. Run quality checks before committing

```bash
# Terraform formatting (required — CI enforced)
terraform fmt -recursive ./infra
terraform fmt -recursive ./platform

# PowerShell syntax (required — CI enforced)
pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; foreach ($s in $scripts) { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$null) }'
```

### 3. Commit with conventional format

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`

**Scopes:** `infra`, `platform`, `scripts`, `docs`

**Examples:**
```
feat(platform): add Redis cluster deployment
fix(scripts): handle RBAC propagation timeout in ensure-safeguards
chore(infra): bump AKS module version
docs: add ADR for storage class selection
```

### 4. Open a PR targeting `dev`

PRs trigger CI checks automatically. All checks must pass before merge.

---

## CI Checks

| Check | Workflow | Runs on |
|-------|----------|---------|
| Terraform format | `pr-checks.yml` | PRs to `main` |
| PowerShell syntax | `pr-checks.yml` | PRs to `main` |
| Secrets scan | `pr-checks.yml` | PRs to `main` |
| Protected branch guard | `squad-main-guard.yml` | PRs to `main`, `preview` |
| Squad CI | `squad-ci.yml` | PRs to `dev`, `preview`, `main` |

---

## AKS Automatic Safeguards Compliance

Every Kubernetes workload in this repo must comply with AKS Automatic Deployment Safeguards. This is the most common source of PR issues.

**Every container must have:**
- `readinessProbe` and `livenessProbe`
- Resource `requests` and `limits`
- `seccompProfile: RuntimeDefault`

**Every pod with replicas > 1 must have:**
- `topologySpreadConstraints` or `podAntiAffinity`

**Forbidden:**
- `:latest` image tags
- `NET_ADMIN` or `NET_RAW` capabilities
- Privileged containers

When adding a **new Helm chart**, use the postrender + kustomize pattern to inject missing fields. See [ADR-0002](docs/decisions/0002-helm-postrender-kustomize-for-safeguards.md) and the ECK operator example at `platform/kustomize/eck-operator-postrender.sh`.

---

## Terraform Conventions

### Infra layer (`infra/`)

- State managed by azd at `.azure/<env>/infra/terraform.tfstate`
- Provider versions pinned in `infra/versions.tf` — do not downgrade
- Sensitive outputs must use `sensitive = true`

### Platform layer (`platform/`)

- Local state at `platform/terraform.tfstate`
- All optional resources must use `count = var.enable_X ? 1 : 0` guards
- Helm `set` blocks: use `type = "string"` when the value is `"true"` or `"false"`
- Cross-layer values come from environment variables, not direct state references

---

## PowerShell Conventions

- All scripts set `$ErrorActionPreference = "Stop"` at the top
- Always check `$LASTEXITCODE` after external commands (`az`, `terraform`, `kubectl`, `helm`)
- Quote variable interpolation in arguments: `"-state=$var"` not `-state=$var`
- Use `2>$null` for stderr suppression only when intentional

---

## Architecture Decision Records

Create an ADR in [`docs/decisions/`](docs/decisions/) when:
- Adding new architectural patterns
- Choosing between design alternatives
- Making technology or library selections
- Changing core system behaviors

See [`docs/decisions/README.md`](docs/decisions/README.md) for templates and the full index.

---

## Project References

| Document | Purpose |
|----------|---------|
| [`AGENTS.md`](AGENTS.md) | Agent guardrails — critical rules and core patterns |
| [`docs/architecture.md`](docs/architecture.md) | Component details, deployment flow, security architecture |
| [`docs/decisions/`](docs/decisions/) | ADR index with rationale for all major design choices |
