---
status: accepted
contact: Daniel Scholl
date: 2026-02-27
deciders: Daniel Scholl
---

# Reusable OSDU service module and SQL template extraction

## Context and Problem Statement

The platform layer deploys OSDU services as individual `helm_release` resources. Each resource repeats 14 identical `set` blocks (~90 lines) for common Helm values. With 2 services today and ~20 more on the roadmap, copy-pasting this boilerplate per service is error-prone and makes global changes (e.g. adding a new common value) require editing every file.

Separately, `k8s_cnpg_databases.tf` (504 lines) embeds 340 lines of SQL DDL as a heredoc-in-YAML-in-HCL. This makes the SQL hard to read, hard to diff against the ROSA reference, and impossible to lint with SQL tools.

## Decision Drivers

- 22 planned OSDU services would mean ~2,000 lines of duplicated Helm values
- SQL DDL is sourced from ROSA and needs periodic comparison; inline embedding defeats standard diff workflows
- Terraform `moved` blocks enable zero-downtime state migration without destroy/recreate
- Module calls retain per-service `depends_on`, `extra_set`, and `preconditions` — no loss of control

## Considered Options

- **Reusable module with explicit calls** — `modules/osdu-service/` encapsulates common values; each service gets a named module call in `osdu.tf`
- **`for_each` over a service map** — single module block iterating over a map of service configs
- **Keep copy-paste pattern** — continue duplicating helm_release resources per service

## Decision Outcome

Chosen option: "Reusable module with explicit calls", because it eliminates per-service boilerplate (~90 → ~20 lines) while preserving explicit dependency graphs and service-specific configuration. Unlike `for_each`, explicit calls allow per-service `depends_on` blocks, which are critical for OSDU's ordered startup (e.g. entitlements depends on partition).

SQL DDL is extracted into per-database `.sql.tftpl` template files under `software/stack/charts/postgresql/sql/`, assembled at plan time via `templatefile()` + `join()`. This makes each database's schema independently readable, diffable, and lintable.

### Changes

| Action | File(s) | Purpose |
|--------|---------|---------|
| Create | `software/stack/modules/osdu-service/{main,variables,outputs}.tf` | Reusable module with common Helm values |
| Create | `software/stack/osdu.tf` | Explicit module calls per OSDU service |
| Create | `software/stack/moved.tf` | State migration blocks for existing resources |
| Create | `software/stack/charts/postgresql/sql/*.sql.tftpl` | Per-database DDL templates |
| Create | `software/stack/charts/osdu-common/main.tf` | OSDU namespace, ConfigMap, secrets |

### Consequences

- Good, because adding a new OSDU service requires only ~20 lines in `osdu.tf` instead of a new 90-line file
- Good, because common Helm value changes are made once in the module, not N times
- Good, because SQL DDL files can be compared against ROSA reference with standard diff tools
- Good, because `moved` blocks ensure zero state churn during migration
- Neutral, because module indirection adds one level of abstraction to navigate
- Bad, because Terraform doesn't support dynamic `lifecycle` blocks, so preconditions use an `alltrue()` workaround
