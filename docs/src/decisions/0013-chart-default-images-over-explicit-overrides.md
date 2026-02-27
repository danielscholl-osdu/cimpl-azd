---
status: accepted
contact: Daniel Scholl
date: 2026-02-27
deciders: Daniel Scholl
---

# Use CIMPL chart default images instead of explicit image overrides

## Context and Problem Statement

When deploying OSDU services via CIMPL Helm charts, should we explicitly override container image references in our Terraform Helm values, or rely on the chart's built-in defaults?

The ROSA reference implementation overrides images for every service. A code review flagged the absence of explicit image overrides as a "runtime drift risk," citing the `0.0.7-latest` chart version string as evidence of tag instability.

## Decision Drivers

- AKS Deployment Safeguards block `:latest` image tags via Gatekeeper policy
- CIMPL charts pin images to commit SHAs (e.g., `1397af8b`), not mutable tags
- Chart version (`0.0.7-latest`) is a Helm chart version, not a container image tag — these are distinct concepts
- ROSA image overrides reference tags from a different registry path that may not exist in the CIMPL OCI registry
- Overriding with wrong tags causes `ImagePullBackOff` failures that are harder to diagnose than using defaults

## Considered Options

- **Use chart default images** — let each chart version bundle its tested image references
- **Override images explicitly** — pin image repository and tag in Terraform Helm values (ROSA pattern)

## Decision Outcome

Chosen option: "Use chart default images", because the CIMPL Helm charts already embed pinned, tested image references with commit SHA tags. Overriding introduces a maintenance burden and a risk of tag mismatch with no corresponding benefit.

The `0.0.7-latest` string is the **chart** version (a Helm concept), not an image tag. The images inside the chart use immutable commit SHAs. AKS safeguards enforce the no-`:latest` policy at the container image level, which these charts already satisfy.

### Consequences

- Good, because chart upgrades automatically bring matched image versions without manual coordination
- Good, because it eliminates a class of deployment failures from stale or wrong image tag overrides
- Good, because it reduces Terraform Helm value surface area per service
- Bad, because chart version `0.0.7-latest` is a mutable reference — a chart republish could change defaults without our knowledge
- Mitigation: when chart stability is a concern, pin to an immutable chart digest or a non-`latest` chart version
