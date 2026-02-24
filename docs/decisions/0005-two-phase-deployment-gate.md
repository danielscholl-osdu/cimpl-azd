---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Two-Phase Deployment Gate for Azure Policy Convergence

## Context and Problem Statement

Fresh AKS clusters have an eventual consistency window where Azure Policy assignments have not yet propagated to the in-cluster Gatekeeper constraints. Deploying platform workloads during this window causes intermittent failures — pods are rejected by Gatekeeper policies that haven't received their namespace exclusions or policy exemptions yet. This is especially critical for CNPG operator Jobs (initdb, join) which cannot have health probes and rely on an Azure Policy Exemption that takes up to 20 minutes to propagate.

## Decision Drivers

- Fresh cluster deployments must be reliable without manual intervention
- Azure Policy sync can take up to 20 minutes per Microsoft documentation
- CNPG probe exemption must propagate before PostgreSQL cluster creation
- Must integrate with `azd up` orchestration (pre-provision → provision → post-provision)
- Must fail fast if policies will never converge (not wait indefinitely)

## Considered Options

- Behavioral gate via server-side dry-run
- Fixed sleep timer (e.g., `sleep 1200`)
- Retry-on-failure with backoff
- Disable safeguards during initial deployment

## Decision Outcome

Chosen option: "Behavioral gate via server-side dry-run", because it tests actual Gatekeeper admission behavior rather than relying on timing assumptions, providing a reliable and deterministic signal that policies have converged.

### Consequences

- Good, because tests real admission behavior — a dry-run Job without probes succeeds only when the exemption has propagated
- Good, because deterministic — no timing assumptions, works regardless of Azure Policy sync speed
- Good, because fails fast on non-policy errors (RBAC, network) with clear error messages
- Good, because integrates cleanly with azd hooks (`scripts/ensure-safeguards.ps1` as Phase 1, `scripts/deploy-platform.ps1` as Phase 2)
- Bad, because adds up to 20 minutes to fresh cluster deployments (waiting for policy propagation)
- Bad, because requires PowerShell scripting complexity (polling loop with error classification)
