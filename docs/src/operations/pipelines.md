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

Developers work on `feature/*` branches and merge to `dev` via pull request. The **Squad Promote** workflow (manual trigger) handles promotion through preview and main, including tagging and release creation.

---

## Workflow Summary

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| [Squad CI](#squad-ci) | `squad-ci.yml` | PR/push to dev, preview, main | Terraform & PowerShell validation |
| [PR Checks](#pr-checks) | `pr-checks.yml` | PR to main | Format, syntax, secrets scan |
| [CodeQL](#codeql) | `codeql.yml` | PR/push to main, weekly schedule | Security analysis |
| [Squad Preview Validation](#squad-preview-validation) | `squad-preview.yml` | Push to preview | Validate preview branch readiness |
| [Squad Main Guard](#squad-main-guard) | `squad-main-guard.yml` | PR/push to main, preview, insider | Block forbidden files on protected branches |
| [Squad Promote](#squad-promote) | `squad-promote.yml` | Manual dispatch | Promote dev → preview → main with release |
| [Squad Release](#squad-release) | `squad-release.yml` | Manual dispatch | Manual release fallback |
| [Squad Insider Release](#squad-insider-release) | `squad-insider-release.yml` | Push to insider | Create insider pre-release |
| [Squad Docs](#squad-docs) | `squad-docs.yml` | PR (spell check), push to main (deploy) | Spell check + GitHub Pages deploy |
| [Squad Heartbeat](#squad-heartbeat) | `squad-heartbeat.yml` | Schedule (30 min), issues, PRs | Auto-triage and monitor squad work |
| [Squad Triage](#squad-triage) | `squad-triage.yml` | Issue labeled "squad" | Route issues to squad members |
| [Squad Issue Assign](#squad-issue-assign) | `squad-issue-assign.yml` | Issue labeled "squad:*" | Assign work to squad members |
| [Squad Label Enforce](#squad-label-enforce) | `squad-label-enforce.yml` | Issue labeled | Enforce mutually exclusive labels |
| [Sync Squad Labels](#sync-squad-labels) | `sync-squad-labels.yml` | team.md changes, manual | Sync GitHub labels from team roster |

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
                        │      ├── squad-ci (terraform fmt, PS syntax) │
                        │      │                                       │
                        │      ▼                                       │
                        │  Merge to dev                                │
                        └──────┬───────────────────────────────────────┘
                               │
                               ▼
                ┌──────────────────────────────┐
                │  Squad Promote (manual)       │
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

### Squad CI

**File:** `squad-ci.yml`
**Triggers:** Pull requests and pushes to `dev`, `preview`, `main`, `insider`

Runs on every PR and push to protected branches. This is the primary gate for code quality.

| Job | What it checks |
|-----|----------------|
| `terraform-format` | `terraform fmt -check` on `infra/` and `platform/` |
| `powershell-syntax` | PSParser tokenization of all `scripts/*.ps1` files |

### PR Checks

**File:** `pr-checks.yml`
**Triggers:** Pull requests to `main`

Additional checks that run only on PRs targeting main.

| Job | What it checks |
|-----|----------------|
| `terraform-format` | Same as Squad CI |
| `powershell-syntax` | Same as Squad CI |
| `secrets-scan` | Regex scan for API keys, tokens, connection strings, private keys |

The secrets scan uses ripgrep with patterns for common secret types and fails the build if unacknowledged secrets are detected.

### CodeQL

**File:** `codeql.yml`
**Triggers:** Push/PR to `main`, weekly schedule (Monday 06:00 UTC)

GitHub's code scanning for security vulnerabilities. Results are written to Security tab.

### Squad Preview Validation

**File:** `squad-preview.yml`
**Triggers:** Push to `preview`

Validates the preview branch after promotion. Checks formatting, PowerShell syntax, and verifies no forbidden files leaked through.

### Squad Main Guard

**File:** `squad-main-guard.yml`
**Triggers:** Pull requests and pushes to `main`, `preview`, `insider`

Blocks commits that contain files from internal team directories:

- `.ai-team/`, `.squad/` — team state files
- `.ai-team-templates/`, `.squad-templates/` — internal templates
- `team-docs/` — internal team documentation
- `docs/proposals/` — design proposals

File deletions are allowed (cleaning up is fine). The Squad Promote workflow handles stripping these paths during the dev → preview merge.

---

## Release Pipelines

### Squad Promote

**File:** `squad-promote.yml`
**Triggers:** Manual dispatch (`workflow_dispatch`)
**Inputs:** `dry_run` (true/false, default false)

This is the primary release mechanism. It runs two sequential jobs:

**Job 1 — dev-to-preview:**
1. Ensure `preview` branch exists (creates from main if missing)
2. Merge `dev` into `preview` with `--no-ff`
3. Strip forbidden paths (`.squad/`, `team-docs/`, etc.) from the merge
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

### Squad Release

**File:** `squad-release.yml`
**Triggers:** Manual dispatch (`workflow_dispatch`)
**Inputs:** `version` (required, format `vX.Y.Z`)

Manual fallback if the promote workflow's release step fails partway through. Operates directly on the `main` branch:

1. Validate version format and check tag doesn't already exist
2. Validate terraform formatting
3. Stamp CHANGELOG
4. Create annotated tag and GitHub Release

### Squad Insider Release

**File:** `squad-insider-release.yml`
**Triggers:** Push to `insider`

Creates pre-release tags for early testing. Tags follow the pattern `vX.Y.Z-insider.SHORT_SHA` based on the latest existing version tag. Creates a GitHub Release marked as pre-release with auto-generated notes.

---

## Issue Management Pipelines

These workflows automate the squad's issue triage and assignment process.

### Squad Heartbeat

**File:** `squad-heartbeat.yml`
**Triggers:** Every 30 minutes (cron), issue/PR events, manual dispatch

Periodic health check that monitors the issue board:
- Finds untriaged issues (labeled "squad" but no member assignment)
- Finds assigned but unstarted issues
- Finds issues missing triage verdict or release target
- Auto-triages using keyword-based routing
- Assigns `@copilot` coding agent to matching issues

### Squad Triage

**File:** `squad-triage.yml`
**Triggers:** Issue labeled with "squad"

Initial triage when an issue enters the squad pipeline:
- Reads team roster and routing rules from `.squad/team.md` and `.squad/routing.md`
- Evaluates issue fit for `@copilot` coding agent based on capability keywords
- Falls back to keyword-based domain routing (frontend, backend, testing, devops)
- Defaults to team lead if no routing match
- Applies `squad:{member}` label and `go:needs-research` verdict

### Squad Issue Assign

**File:** `squad-issue-assign.yml`
**Triggers:** Issue labeled with any `squad:*` label

Routes work after triage:
- Extracts member name from label
- Posts assignment acknowledgment comment
- Special handling for `squad:copilot` — assigns the copilot-swe-agent bot

### Squad Label Enforce

**File:** `squad-label-enforce.yml`
**Triggers:** Issue labeled

Enforces mutual exclusivity within label namespaces:

| Namespace | Labels | Rule |
|-----------|--------|------|
| `go:` | yes, no, needs-research | Only one allowed |
| `release:` | v0.4.0–v1.0.0, backlog | Only one allowed |
| `type:` | feature, bug, spike, docs, chore, epic | Only one allowed |
| `priority:` | p0, p1, p2 | Only one allowed |

Special behavior:
- `go:yes` without a release target auto-adds `release:backlog`
- `go:no` removes all `release:*` labels

### Sync Squad Labels

**File:** `sync-squad-labels.yml`
**Triggers:** Changes to `.squad/team.md`, manual dispatch

Syncs GitHub labels from the team roster file. Creates `squad:{member}` labels for each team member, along with static labels for go/release/type/priority namespaces.

---

## Squad Docs

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
gh workflow run "Squad Promote"

# Or do a dry run first
gh workflow run "Squad Promote" -f dry_run=true
```

### Create a manual release (fallback)

```bash
# Only use if Squad Promote failed partway through
gh workflow run "Squad Release" -f version=v0.2.0
```

### Create an insider pre-release

```bash
# Push to the insider branch
git push origin dev:insider
```

### Check workflow status

```bash
# List recent runs for a workflow
gh run list --workflow="Squad Promote" --limit 5

# View details of a specific run
gh run view <run-id>

# Watch a run in progress
gh run watch <run-id>
```
