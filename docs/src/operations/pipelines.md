# CI/CD Pipelines

This document describes every GitHub Actions workflow in this repository, how they connect, and the end-to-end release flow.

---

## Branch Promotion Model

```
feature/* ──PR──► dev ──promote──► preview ──promote──► main
                   │                  │                   │
                   │                  │                   ├─ Tagged release (vX.Y.Z)
                   │                  │                   └─ GitHub Release created
                   │                  └─ Pre-release validation
                   └─ Integration (daily work)

insider ─push──► Insider pre-release (vX.Y.Z-insider.SHA)
```

Developers work on `feature/*` branches and merge to `dev` via pull request. The **Promote** workflow (manual trigger) handles promotion through preview and main, including tagging and release creation.

---

## Workflow Summary

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| [CI](#ci) | `squad-ci.yml` | PR/push to dev, preview, main | Terraform & PowerShell validation |
| [PR Checks](#pr-checks) | `pr-checks.yml` | PR to main | Format, syntax, secrets scan |
| [CodeQL](#codeql) | `codeql.yml` | PR/push to main, weekly schedule | Security analysis |
| [Preview Validation](#preview-validation) | `squad-preview.yml` | Push to preview | Validate preview branch readiness |
| [Main Guard](#main-guard) | `squad-main-guard.yml` | PR/push to main, preview, insider | Block forbidden files on protected branches |
| [Promote](#promote) | `squad-promote.yml` | Manual dispatch | Promote dev → preview → main with release |
| [Release](#release) | `squad-release.yml` | Manual dispatch | Manual release fallback |
| [Insider Release](#insider-release) | `squad-insider-release.yml` | Push to insider | Create insider pre-release |
| [Docs](#docs-pipeline) | `squad-docs.yml` | PR (spell check), push to main (deploy) | Spell check + GitHub Pages deploy |

---

## Pipeline Flow Diagram

```
                        ┌─────────────────────────────────────────────┐
                        │          Developer Workflow                  │
                        │                                              │
                        │  feature/* branch                            │
                        │      │                                       │
                        │      ▼                                       │
                        │  Open PR → dev                               │
                        │      │                                       │
                        │      ├── CI (terraform fmt, PS syntax)       │
                        │      │                                       │
                        │      ▼                                       │
                        │  Merge to dev                                │
                        └──────┬───────────────────────────────────────┘
                               │
                               ▼
                ┌──────────────────────────────┐
                │  Promote (manual)             │
                │                               │
                │  Job 1: dev → preview          │
                │    • merge dev into preview    │
                │    • strip forbidden files     │
                │         │                      │
                │         ▼                      │
                │  Job 2: preview → main         │
                │    • determine next version    │
                │    • validate CHANGELOG        │
                │    • validate terraform fmt    │
                │    • merge preview into main   │
                │    • stamp CHANGELOG           │
                │    • create git tag            │
                │    • create GitHub Release     │
                └──────────────────────────────┘
                               │
                               ▼
                      Tagged release (vX.Y.Z)
                      GitHub Release published
```

---

## Validation Pipelines

### CI

**File:** `squad-ci.yml`
**Triggers:** Pull requests and pushes to `dev`, `preview`, `main`, `insider`

Runs on every PR and push to protected branches. This is the primary gate for code quality.

| Job | What it checks |
|-----|----------------|
| `terraform-format` | `terraform fmt -check` on `infra/` and `software/` |
| `powershell-syntax` | PSParser tokenization of all `scripts/*.ps1` files |

### PR Checks

**File:** `pr-checks.yml`
**Triggers:** Pull requests to `main`

Additional checks that run only on PRs targeting main.

| Job | What it checks |
|-----|----------------|
| `terraform-format` | Same as CI |
| `powershell-syntax` | Same as CI |
| `secrets-scan` | Regex scan for API keys, tokens, connection strings, private keys |

The secrets scan uses ripgrep with patterns for common secret types and fails the build if unacknowledged secrets are detected.

### CodeQL

**File:** `codeql.yml`
**Triggers:** Push/PR to `main`, weekly schedule (Monday 06:00 UTC)

GitHub's code scanning for security vulnerabilities. Results are written to Security tab.

### Preview Validation

**File:** `squad-preview.yml`
**Triggers:** Push to `preview`

Validates the preview branch after promotion. Checks formatting, PowerShell syntax, and verifies no forbidden files leaked through.

### Main Guard

**File:** `squad-main-guard.yml`
**Triggers:** Pull requests and pushes to `main`, `preview`, `insider`

Blocks commits that contain files from internal team directories:

- `.ai-team/` — AI agent state files
- `.ai-team-templates/` — internal templates
- `team-docs/` — internal team documentation
- `docs/proposals/` — design proposals

File deletions are allowed (cleaning up is fine). The Promote workflow handles stripping these paths during the dev → preview merge.

---

## Release Pipelines

### Promote

**File:** `squad-promote.yml`
**Triggers:** Manual dispatch (`workflow_dispatch`)
**Inputs:** `dry_run` (true/false, default false)

This is the primary release mechanism. It runs two sequential jobs:

**Job 1 — dev-to-preview:**
1. Ensure `preview` branch exists (creates from main if missing)
2. Merge `dev` into `preview` with `--no-ff`
3. Strip forbidden paths from the merge
4. Push preview

**Job 2 — preview-to-main (release):**
1. **Version calculation** — reads latest git tag (or defaults to `v0.0.0`), scans commit messages:
   - `feat` commits → bump minor version
   - `BREAKING CHANGE` or `!:` commits → bump major version
   - Otherwise → bump patch version
2. **Validation** — checks CHANGELOG has `[Unreleased]` or matching version section, no forbidden files, terraform format
3. **Merge** — merge preview into main with `--no-ff`
4. **CHANGELOG stamp** — replace `[Unreleased]` header with version and date, re-add empty `[Unreleased]` section
5. **Tag and release** — create annotated git tag, push tag, create GitHub Release with changelog notes

Use `dry_run: true` to preview what would happen without making changes.

### Release

**File:** `squad-release.yml`
**Triggers:** Manual dispatch (`workflow_dispatch`)
**Inputs:** `version` (required, format `vX.Y.Z`)

Manual fallback if the promote workflow's release step fails partway through. Operates directly on the `main` branch:

1. Validate version format and check tag doesn't already exist
2. Validate terraform formatting
3. Stamp CHANGELOG
4. Create annotated tag and GitHub Release

### Insider Release

**File:** `squad-insider-release.yml`
**Triggers:** Push to `insider`

Creates pre-release tags for early testing. Tags follow the pattern `vX.Y.Z-insider.SHORT_SHA` based on the latest existing version tag. Creates a GitHub Release marked as pre-release with auto-generated notes.

---

## Docs Pipeline

**File:** `squad-docs.yml`
**Triggers:** PRs (spell check on `*.md` changes), push to `main` (deploy), manual dispatch from `main`

Runs two jobs:

| Job | What it does |
|-----|--------------|
| `spell-check` | Runs `crate-ci/typos` against all Markdown files using `.github/_typos.toml` |
| `deploy` | Builds docs with Zensical + Material for MkDocs and deploys to GitHub Pages (main branch only) |

---

## How To

### Run a release

```bash
# Trigger the promote workflow (promotes dev → preview → main, tags, and releases)
gh workflow run "squad-promote.yml"

# Or do a dry run first
gh workflow run "squad-promote.yml" -f dry_run=true
```

### Create a manual release (fallback)

```bash
# Only use if promote failed partway through
gh workflow run "squad-release.yml" -f version=v0.2.0
```

### Create an insider pre-release

```bash
# Push to the insider branch
git push origin dev:insider
```

### Check workflow status

```bash
# List recent runs for a workflow
gh run list --workflow="squad-promote.yml" --limit 5

# View details of a specific run
gh run view <run-id>

# Watch a run in progress
gh run watch <run-id>
```
