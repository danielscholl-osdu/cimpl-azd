# Team Roster

> OSDU platform conversion from ROSA to AKS Automatic

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. Does not generate domain artifacts. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Holden | Lead | `.squad/agents/holden/charter.md` | ✅ Active |
| Amos | Platform Dev | `.squad/agents/amos/charter.md` | ✅ Active |
| Alex | Services Dev | `.squad/agents/alex/charter.md` | ✅ Active |
| Drummer | Tester | `.squad/agents/drummer/charter.md` | ✅ Active |
| Scribe | Session Logger | `.squad/agents/scribe/charter.md` | 📋 Silent |
| Ralph | Work Monitor | — | 🔄 Monitor |

## Coding Agent

<!-- copilot-auto-assign: false -->

| Name | Role | Charter | Status |
|------|------|---------|--------|
| @copilot | Coding Agent | — | 🤖 Coding Agent |

### Capabilities

**Good fit — auto-route when enabled:**
- Mechanical OSDU service ports following the established `osdu.tf` + `modules/osdu-service` pattern
- Terraform fmt fixes and linting cleanup
- Documentation updates and README fixes
- Dependency version bumps
- Creating kustomize overlays for new services (copy from partition/entitlements template)

**Needs review — route to @copilot but flag for squad member PR review:**
- New OSDU service modules in `software/stack/osdu.tf`
- Kustomize overlay additions at `software/stack/kustomize/services/<service>/`
- Conditional secrets in `software/stack/charts/osdu-common/main.tf`

**Not suitable — route to squad member instead:**
- Architecture decisions (namespace strategy, module design)
- Shared postrender framework changes
- Cross-layer integration (infra outputs → stack inputs)
- Safeguards compliance for new component types
- Debugging AKS Automatic constraint violations

## Project Context

- **Owner:** Daniel Scholl
- **Stack:** Terraform (HCL), PowerShell, Helm, AKS Automatic, Istio, Gateway API
- **Description:** Two-layer azd deployment converting OSDU from ROSA to AKS Automatic
- **Created:** 2026-02-17
