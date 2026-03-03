---
status: accepted
contact: Daniel Scholl
date: 2026-03-02
deciders: Daniel Scholl
---

# Stack file layout reorganization

## Context and Problem Statement

The `software/stack/` Terraform root module grew from a handful of middleware components to 9 middleware modules and 20 OSDU service modules. Several files became overloaded: `main.tf` (257 lines mixing locals, platform resources, and 9 module calls), `osdu.tf` (538 lines with 20 service modules), `variables.tf` (392 lines, 40 variables), and `modules/osdu-common/main.tf` (679 lines with 36 Kubernetes resources). Additionally, the `charts/` directory name was misleading, as only 4 of 9 modules actually used `helm_release`.

## Decision Drivers

- Files exceeding 400 lines are hard to navigate and review
- `charts/` name implies Helm charts, but 5 of 9 modules use raw manifests or CRDs
- OSDU services were in a flat list with no alignment to the OSDU platform's own service taxonomy
- `moved.tf` (209 lines of state migration blocks) was no longer needed after all environments were deleted
- New contributors need a clear mental model of where to find and add things

## Considered Options

- **Thematic file split with OSDU taxonomy alignment**: rename `charts/` to `modules/`, split large files by concern, group OSDU services per the official OSDU platform taxonomy
- **Keep current layout**: add comments and a README to explain the existing structure
- **Module-per-service**: create a separate `.tf` file per OSDU service (20+ files)

## Decision Outcome

Chosen option: "Thematic file split with OSDU taxonomy alignment", because it reduces cognitive load without over-fragmenting the codebase. Terraform keys state on resource/module block names, not filenames, so pure file reorganization has zero state impact.

### File splits

| Before | After |
|--------|-------|
| `main.tf` (257 lines) | `locals.tf`, `platform.tf`, `middleware.tf`, `osdu-common.tf` |
| `osdu.tf` (538 lines) | `osdu-services-core.tf`, `osdu-services-reference.tf`, `osdu-services-domain.tf` |
| `variables.tf` (392 lines) | `variables-flags.tf`, `variables-infra.tf`, `variables-credentials.tf`, `variables-osdu.tf` |
| `charts/` (misleading name) | `modules/` (unified with existing `osdu-service/`) |
| `modules/osdu-common/main.tf` (679 lines) | `namespace.tf`, `secrets-postgresql.tf`, `secrets-middleware.tf`, `secrets-identity.tf`, `services.tf` |
| `moved.tf` (209 lines) | Deleted (no environments with old state addresses) |

### OSDU service grouping

Services are grouped per the [OSDU platform taxonomy](https://community.opengroup.org/osdu/platform):

- **Core** (`osdu-services-core.tf`): partition, entitlements, legal, schema, storage, search, indexer, file, notification, dataset, register, policy, secret, workflow
- **Reference systems** (`osdu-services-reference.tf`): crs-conversion, crs-catalog, unit
- **Domain + external data** (`osdu-services-domain.tf`): wellbore, wellbore-worker, eds-dms

### Consequences

- Good, because no root `.tf` file exceeds 400 lines (largest is `osdu-services-core.tf` at 391)
- Good, because `modules/` accurately describes a directory containing Terraform modules of varying types
- Good, because OSDU service grouping matches the official taxonomy, making it intuitive for OSDU developers
- Good, because `variables-credentials.tf` isolates all `sensitive = true` variables, making security review easier
- Good, because zero Terraform state changes, verified by `terraform plan`
- Neutral, because more files to navigate (17 root `.tf` files vs 7 before), mitigated by a `README.md` navigation table
- Bad, because any documentation or tooling referencing old paths (`charts/`, `main.tf`, `osdu.tf`, `variables.tf`) must be updated
