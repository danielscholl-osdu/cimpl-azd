---
status: superseded by [ADR-0016](0016-raw-manifests-for-keycloak.md)
date: 2026-02-25
deciders: platform team
---

# Bitnami Helm chart with official Keycloak image

## Context and Problem Statement

Keycloak is needed as the identity provider for OSDU services. There is no official first-party Keycloak Helm chart. The Bitnami Keycloak chart is the most mature option, but Bitnami deprecated their free container images in August 2025, moving them to a paid program. The archived images in `bitnamilegacy/` receive no security patches.

## Decision Drivers

- No official Keycloak Helm chart exists
- Bitnami free images are deprecated and unpatched since August 2025
- The official `quay.io/keycloak/keycloak` image is actively maintained
- Must be internal-only (no public exposure) for OSDU service authentication
- AKS Automatic deployment safeguards compliance

## Considered Options

- Bitnami chart with Bitnami image (deprecated, no security patches)
- Bitnami chart with official Keycloak image (quay.io)
- Codecentric chart with official image (community-maintained, less active)
- Keycloak Operator (full operator pattern, higher complexity)

## Decision Outcome

Chosen option: "Bitnami chart with official Keycloak image", because the Bitnami chart is the most mature Helm packaging for Keycloak and supports image overrides, while the official `quay.io/keycloak/keycloak` image ensures continued security patches without a paid Bitnami subscription.

**Compatibility adjustments required** when using the official image with the Bitnami chart:

- `args: [start, --import-realm]` — pass CLI args directly instead of `KEYCLOAK_EXTRA_ARGS` env var (Bitnami-specific)
- `runAsUser: 1000`, `runAsGroup: 0` — match the official image UID/GID (not Bitnami's 1001/1001)
- `readOnlyRootFilesystem: false` — official image requires writable `/opt/keycloak/data/`, `/opt/keycloak/conf/`, `/tmp`
- `KC_HEALTH_ENABLED: "true"` — native Keycloak env var for health endpoints on port 9000

**Access model**: Keycloak is internal-only with no HTTPRoute/Gateway exposure. OSDU services reach it via `keycloak.keycloak.svc.cluster.local:8080`. Admin console access requires `kubectl port-forward`.

### Consequences

- Good, because security patches come from the official Keycloak project (no Bitnami dependency)
- Good, because the Bitnami chart handles Helm lifecycle, probes, and Kubernetes resource generation
- Good, because realm import works via `--import-realm` CLI arg with volume-mounted JSON
- Bad, because Bitnami chart upgrades may introduce incompatibilities with the official image
- Bad, because `readOnlyRootFilesystem` cannot be enabled (upstream Keycloak limitation)
