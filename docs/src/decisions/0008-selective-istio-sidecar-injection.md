---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# Selective Istio Sidecar Injection Due to AKS Constraints

## Context and Problem Statement

AKS Automatic blocks `NET_ADMIN` and `NET_RAW` capabilities, which are required by Istio's `istio-init` container to configure iptables rules for traffic interception. This means standard Istio sidecar injection fails for any namespace where it is enabled. We need a strategy for service mesh coverage that works within AKS Automatic's capability restrictions.

## Decision Drivers

- AKS Automatic blocks `NET_ADMIN`/`NET_RAW` capabilities (no exceptions possible)
- Istio `istio-init` container requires `NET_ADMIN` for iptables configuration
- Data namespaces (Elasticsearch, PostgreSQL) benefit from mTLS encryption
- RabbitMQ, ExternalDNS, and other workloads must function without mesh injection
- Istio ambient mode (ztunnel-based, no `istio-init` needed) is on the AKS roadmap

## Considered Options

- Selective sidecar injection (inject where it works, skip where it doesn't)
- No service mesh at all
- Linkerd (no NET_ADMIN requirement)
- Wait for Istio ambient mode before deploying mesh

## Decision Outcome

Chosen option: "Selective sidecar injection now, with ambient mode as future aspiration", because it provides mTLS where possible today while maintaining forward compatibility with ambient mode when AKS supports it.

### Implementation

All platform middleware and OSDU services share two namespaces (see ADR-0017):

- **`platform`** — Istio sidecar injection **disabled**. Contains Elasticsearch, PostgreSQL, Redis, RabbitMQ, MinIO, Keycloak, and Airflow. RabbitMQ and several operators require capabilities that conflict with Istio's `istio-init` container on AKS Automatic, so injection is off for the entire namespace. STRICT mTLS is enforced via `PeerAuthentication` resources for individual workloads where sidecar injection is not needed because they use application-layer TLS (ECK self-signed TLS for Elasticsearch) or network-level isolation.
- **`osdu`** — Istio sidecar injection **enabled** (`istio-injection: enabled`). OSDU services (Partition, Entitlements, and future services) run with Istio sidecars and STRICT mTLS via `PeerAuthentication`.

### Consequences

- Good, because OSDU service namespace has full STRICT mTLS via PeerAuthentication and sidecar injection
- Good, because Istio ingress gateway works without sidecar injection (uses Gateway API)
- Good, because forward-compatible — when ambient mode is available, the platform namespace can gain mesh coverage without workload changes
- Bad, because the `platform` namespace has no mesh-layer mTLS (relies on application-layer TLS where available)
- Bad, because namespace-level injection label (`istio-injection: enabled`) is coarse — all-or-nothing per namespace
