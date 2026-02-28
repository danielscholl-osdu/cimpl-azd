---
status: accepted
contact: Daniel Scholl
date: 2026-02-27
deciders: Daniel Scholl
supersedes: ADR-0012
---

# Raw Kubernetes manifests for Keycloak

## Context and Problem Statement

ADR-0012 chose the Bitnami Keycloak Helm chart with the official `quay.io/keycloak/keycloak` image. In practice, the Bitnami chart proved to be a poor fit: Bitnami templates hardcode paths under `/opt/bitnami/`, set `runAsUser: 1001` (Bitnami convention), and use Bitnami-specific environment variables (`KEYCLOAK_EXTRA_ARGS`, `KEYCLOAK_DATABASE_*`) that have no effect on the official Keycloak image. Making the Bitnami chart work with the official image required overriding nearly every template value, negating the chart's value as a pre-built package.

This mirrors the same problem encountered with RabbitMQ (ADR-0003): Bitnami deprecated their free images, and Bitnami chart templates are structurally incompatible with official upstream images.

## Decision Drivers

- Bitnami chart templates assume Bitnami image conventions (`/opt/bitnami/`, UID 1001, Bitnami env vars)
- The official Keycloak image uses different paths (`/opt/keycloak/`), UID 1000/GID 0, and native `KC_*` env vars
- Overriding the Bitnami chart to work with the official image requires customizing nearly every field, defeating the purpose of a Helm chart
- AKS Automatic Deployment Safeguards require seccomp profiles, probes, and resource requests on every container — easier to enforce with full manifest control
- Keycloak is a single StatefulSet + 2 Services + 1 ConfigMap — low complexity, manageable without a chart

## Considered Options

- **Bitnami chart with official image** (ADR-0012 approach, superseded) — too many overrides needed
- **Raw Kubernetes manifests** — StatefulSet, Services, ConfigMap, Secrets managed directly in Terraform
- **Keycloak Operator** — full operator pattern, higher complexity than needed for single instance

## Decision Outcome

Chosen option: "Raw Kubernetes manifests", because Keycloak's deployment footprint is small enough (one StatefulSet, two Services, one ConfigMap for realm import) that a Helm chart adds more complexity than it removes. This follows the same pattern as RabbitMQ (ADR-0003).

**Implementation**: All Keycloak resources are defined in `software/stack/charts/keycloak/main.tf` using Terraform `kubectl_manifest` (StatefulSet, Services) and `kubernetes_config_map` / `kubernetes_secret` resources.

**Key configuration**:

- Image: `quay.io/keycloak/keycloak:26.5.4` (pinned tag)
- `args: [start, --import-realm]` — native Keycloak CLI args
- `runAsUser: 1000`, `runAsGroup: 0` — official image UID/GID
- `readOnlyRootFilesystem: false` — official image requires writable `/opt/keycloak/data/`
- Health endpoints on management port 9000 (`KC_HTTP_MANAGEMENT_PORT`)
- PostgreSQL backend (`KC_DB=postgres`, JDBC URL to CNPG cluster)
- OSDU realm auto-imported via ConfigMap mounted at `/opt/keycloak/data/import`
- `datafier` client with service account (`email: datafier@service.local`) pre-configured in realm JSON
- Namespace: `platform` (shared with other middleware, see ADR-0017)

**Access model**: Internal-only, no HTTPRoute/Gateway exposure. OSDU services reach Keycloak via `keycloak.platform.svc.cluster.local:8080`. Admin console access requires `kubectl port-forward`.

### Consequences

- Good, because full control over every field — AKS safeguards compliance is straightforward
- Good, because no Bitnami dependency — neither chart nor images
- Good, because realm import with `datafier` client and service account email is declared in Terraform (reproducible)
- Good, because upgrades are a single image tag change with clear diff
- Bad, because more YAML to maintain compared to a working Helm chart (but less than fighting a broken one)
- Bad, because no Helm lifecycle management (rollback, history)
