# Squad — cimpl-azd

## Project Context

| Field | Value |
|-------|-------|
| **User** | Daniel Scholl |
| **Project** | OSDU platform conversion from ROSA (Red Hat OpenShift) to AKS Automatic |
| **Stack** | Terraform (HCL), PowerShell, Helm, AKS Automatic, Istio, Gateway API |
| **Description** | Two-layer architecture: infra (AKS cluster) + software stack (middleware + OSDU services). Two namespaces: `platform` (middleware) + `osdu` (services). Converting reference-rosa/ to azd-native deployment on AKS Automatic with strict deployment safeguards. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Holden | Lead | .squad/agents/holden/charter.md | ✅ Active |
| Amos | Platform Dev | .squad/agents/amos/charter.md | ✅ Active |
| Alex | Services Dev | .squad/agents/alex/charter.md | ✅ Active |
| Drummer | Tester | .squad/agents/drummer/charter.md | ✅ Active |
| Naomi | Infra Dev | .squad/agents/naomi/charter.md | 🔒 Retired |
| Scribe | Session Logger | .squad/agents/scribe/charter.md | 📋 Silent |
| Ralph | Work Monitor | — | 🔄 Monitor |

## Issue Source

| Field | Value |
|-------|-------|
| **Repository** | danielscholl-osdu/cimpl-azd |
| **Connected** | 2026-02-17 |
| **Filters** | squad label |
| **Tracking Issue** | #105 |
