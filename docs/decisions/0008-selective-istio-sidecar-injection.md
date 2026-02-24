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

### Consequences

- Good, because Elasticsearch and PostgreSQL namespaces have STRICT mTLS via PeerAuthentication
- Good, because Istio ingress gateway works without sidecar injection (uses Gateway API)
- Good, because forward-compatible — when ambient mode is available, namespaces can migrate without workload changes
- Bad, because RabbitMQ namespace has no mesh coverage (no mTLS, no traffic policies)
- Bad, because inconsistent security posture — some namespaces encrypted at mesh layer, others not
- Bad, because namespace-level injection label (`istio-injection: enabled`) is coarse — all-or-nothing per namespace
