---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
---

# ECK Self-Signed TLS for Elasticsearch

## Context and Problem Statement

Elasticsearch was initially deployed with ECK's self-signed TLS disabled (`selfSignedCertificate.disabled: true`) to simplify internal connectivity, relying on Istio mTLS for encryption. However, the CIMPL elastic-bootstrap chart (which creates index templates, ILM policies, and aliases) hardcodes `https://` URLs for the Elasticsearch endpoint. Patching the bootstrap chart to support HTTP would diverge from the ROSA reference architecture and create a maintenance burden. We need to decide on the TLS strategy for Elasticsearch HTTP transport.

## Decision Drivers

- Elastic bootstrap chart hardcodes `https://` protocol for ES connections
- ROSA reference architecture uses ECK self-signed TLS (consistency goal)
- ECK manages certificate lifecycle automatically (rotation, renewal)
- Internal clients must trust the ECK CA or skip TLS verification

## Considered Options

- Enable ECK self-signed TLS (default ECK behavior)
- Patch the bootstrap chart to support HTTP
- Build a custom bootstrap image with configurable protocol

## Decision Outcome

Chosen option: "Enable ECK self-signed TLS", because it matches the ROSA reference architecture, ECK manages certificates automatically, and the bootstrap chart works without modification.

### Consequences

- Good, because elastic-bootstrap chart works without modification (`https://` URLs resolve correctly)
- Good, because consistent with ROSA reference architecture
- Good, because ECK manages certificate lifecycle automatically (no manual cert rotation)
- Good, because defense-in-depth — TLS encryption at application layer in addition to Istio mTLS at mesh layer
- Bad, because internal clients must either trust the ECK CA certificate or use `--insecure` / skip TLS verification
- Bad, because Kibana's HTTP endpoint remains unencrypted (`selfSignedCertificate.disabled: true` on Kibana) to work with Istio ingress routing — asymmetric TLS configuration between ES and Kibana
