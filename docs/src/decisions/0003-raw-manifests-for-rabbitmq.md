---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Raw Kubernetes Manifests for RabbitMQ

## Context and Problem Statement

The Bitnami RabbitMQ Helm chart (`bitnamicharts/rabbitmq`) became unusable because Bitnami removed free-tier images from DockerHub (paid subscription required since August 2025) and the chart templates are deeply coupled to `/opt/bitnami/` filesystem paths, making the official RabbitMQ image (`rabbitmq:*-management-alpine`) incompatible as a drop-in replacement. We need an alternative deployment approach for RabbitMQ on AKS.

## Decision Drivers

- Bitnami images no longer available without paid subscription
- Chart templates assume `/opt/bitnami/` paths (configuration, plugins, data directories)
- Official RabbitMQ image uses standard Linux paths (`/etc/rabbitmq/`, `/var/lib/rabbitmq/`)
- Must be fully AKS Automatic safeguards-compliant (probes, resources, seccomp, topology spread)
- No operator dependency for a messaging broker

## Considered Options

- Raw Kubernetes manifests with official RabbitMQ image
- RabbitMQ Cluster Operator (rabbitmq/cluster-operator)
- Paid Bitnami subscription

## Decision Outcome

Chosen option: "Raw Kubernetes manifests with official RabbitMQ image", because it provides full control over the deployment, uses the official upstream image with no licensing concerns, and avoids introducing an operator for a single StatefulSet.

### Consequences

- Good, because official `rabbitmq:4.1.0-management-alpine` image — no licensing issues, direct upstream support
- Good, because full control over every field — AKS safeguards compliance is straightforward
- Good, because no operator dependency — one less component to maintain and monitor
- Good, because DNS-based peer discovery (`cluster_formation.peer_discovery_backend = dns`) is simple and reliable
- Bad, because more YAML to maintain compared to a Helm chart (StatefulSet, Services, ConfigMap, StorageClass, Secret)
- Bad, because upgrades require manual image tag changes (no `helm upgrade`)
- Bad, because sets precedent that may lead to more raw manifests as other Bitnami charts hit the same issue

**Key implementation details:**
- `enableServiceLinks: false` — prevents Kubernetes-injected `RABBITMQ_*` env vars from colliding with RabbitMQ's own environment variables
- `RABBITMQ_USE_LONGNAME` (singular, not plural) — required for DNS-based clustering with FQDNs
- Erlang cookie written via init script (`echo "$RABBITMQ_ERLANG_COOKIE" > .erlang.cookie && chmod 600`) because the official image's entrypoint expects file-based cookie
- Two services with differentiated selectors (`rabbitmq.service/variant: client` label) for UniqueServiceSelector compliance (see ADR-0010)
