---
status: accepted
contact: Daniel Scholl
date: 2026-03-03
deciders: Daniel Scholl
---

# Group feature flags with cascading locals

## Context and Problem Statement

The software stack has 34 individual `enable_*` feature flags across platform middleware and OSDU services. Users think in capability blocks ("give me platform only", "skip all domain services") but must toggle services one by one. Worse, OSDU services have hidden dependency chains: disabling core services should implicitly disable reference and domain services that depend on them, but a user unfamiliar with the OSDU topology would not know this.

## Decision Drivers

- Users want coarse-grained control: "deploy platform only" or "deploy core but not domain"
- Individual flags remain necessary for fine-grained opt-out of specific services
- Dependency chain between groups: reference and domain services require core
- Must not change the Terraform variable interface for existing users (additive only)
- Should be a pure organizational change with no state impact on existing deployments

## Considered Options

- **Group flags with cascading locals**: add 3 `enable_osdu_*_services` master switches; compute `local.deploy_*` per service as `group && individual`; resource files reference locals
- **Deployment tier enum**: a single `deployment_tier = "platform" | "core" | "reference" | "full"` variable that implicitly controls which services deploy
- **No change**: users continue setting individual flags per service

## Decision Outcome

Chosen option: "Group flags with cascading locals", because it provides two layers of control (coarse + fine) without breaking existing configurations and encodes the dependency cascade in one place.

### Implementation

Three group variables added to the corresponding flag files:

| Variable | File | Default | Effect |
|----------|------|---------|--------|
| `enable_osdu_core_services` | `variables-flags-osdu-core.tf` | `true` | Gates all 15 core services + common resources |
| `enable_osdu_reference_services` | `variables-flags-osdu-reference.tf` | `true` | Gates 3 reference services; cascades through core |
| `enable_osdu_domain_services` | `variables-flags-osdu-domain.tf` | `false` | Gates 3 domain services; cascades through core |

Cascade logic in `locals.tf`:

```hcl
_osdu_core      = var.enable_osdu_core_services
_osdu_reference = local._osdu_core && var.enable_osdu_reference_services
_osdu_domain    = local._osdu_core && var.enable_osdu_domain_services

deploy_partition = local._osdu_core && var.enable_partition
deploy_unit      = local._osdu_reference && var.enable_unit
deploy_wellbore  = local._osdu_domain && var.enable_wellbore
# ... etc for all 21 OSDU services
```

Resource files (`osdu-services-*.tf`, `osdu-common.tf`) reference `local.deploy_*` instead of `var.enable_*` for all OSDU flags. Platform middleware flags (`var.enable_elasticsearch`, `var.enable_postgresql`, etc.) remain direct variable references since they have no group dependency chain.

### Variable file reorganization

As part of this change, `variables-flags.tf` was split into category-aligned files matching the existing resource file naming:

| File | Category | Variables |
|------|----------|-----------|
| `variables-flags-platform.tf` | Platform namespace (infra + middleware) | 13 |
| `variables-flags-osdu-core.tf` | OSDU core services | 15 + 1 group |
| `variables-flags-osdu-reference.tf` | OSDU reference services | 3 + 1 group |
| `variables-flags-osdu-domain.tf` | OSDU domain services | 3 + 1 group |

### Consequences

- Good, because `enable_osdu_core_services=false` disables all OSDU services in one flag
- Good, because dependency cascade is automatic: disabling core implicitly disables reference and domain
- Good, because individual flags still work for fine-grained opt-out within a group
- Good, because existing deployments with no group flags set see zero behavior change (all default to `true`)
- Good, because variable files now mirror the resource file naming convention
- Neutral, because resource files now reference `local.deploy_*` instead of `var.enable_*`, adding one level of indirection
- Bad, because `terraform plan` output shows locals, not variables, making it slightly harder to trace which input flag caused a change
