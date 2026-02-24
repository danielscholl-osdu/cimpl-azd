---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# UniqueServiceSelector Compliance via Label Differentiation

## Context and Problem Statement

AKS Automatic enforces the `K8sAzureV1UniqueServiceSelector` Gatekeeper policy, which rejects Services whose label selectors are a subset of another Service's selectors in the same namespace. This is common in Kubernetes — headless Services for StatefulSet peer discovery and ClusterIP Services for client access often share the same `app` label selector. Components affected include Elasticsearch (4 services created by ECK), RabbitMQ (headless + client), and MinIO.

## Decision Drivers

- `K8sAzureV1UniqueServiceSelector` policy cannot be disabled on AKS Automatic
- ECK creates 4 services automatically: `*-es-http`, `*-es-transport`, `*-es-internal-http`, `*-es-default`
- RabbitMQ needs both headless (StatefulSet peer discovery) and ClusterIP (client access) services
- Solution must not break service discovery or pod scheduling
- Pattern must be applicable across all affected components

## Considered Options

- Add differentiating labels to pod templates and service selectors
- Merge services into a single multi-port service
- Request Azure Policy exemption for the constraint

## Decision Outcome

Chosen option: "Add differentiating labels to pod templates and service selectors", because it satisfies the UniqueServiceSelector policy without exemptions, is composable across all components, and uses native Kubernetes label semantics.

### Consequences

- Good, because no policy exemption needed — works within AKS Automatic's constraints
- Good, because composable — same pattern applies to ES, RabbitMQ, MinIO, and future components
- Good, because uses standard Kubernetes label selection — no custom admission webhooks or mutations
- Bad, because each component needs component-specific labels (e.g., `elasticsearch.service/http`, `rabbitmq.service/variant`) that must be kept in sync between pod templates and service selectors
- Bad, because ECK's service selector override syntax is non-obvious (`spec.http.service.spec.selector`) and must be documented for future maintainers
- Bad, because adding a new Elasticsearch nodeSet without the differentiating labels will silently break service routing

**Implementation by component:**
- **Elasticsearch**: ECK service selector overrides — `elasticsearch.service/http: "true"` and `elasticsearch.service/transport: "true"` labels on pods, referenced in `spec.http.service.spec.selector` and `spec.transport.service.spec.selector`
- **RabbitMQ**: `rabbitmq.service/variant: client` label on pods, used only in the ClusterIP service selector (headless service uses base `app.kubernetes.io/name` selector with `clusterIP: None`)
- **MinIO**: Handled via Helm postrender patches where needed
