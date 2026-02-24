---
date: 2026-02-24
by: Amos
title: Elastic Bootstrap Helm release with postrender safeguards
---

## Context
AKS Automatic safeguards require probes, resource requests, and seccomp settings, but the CIMPL elastic-bootstrap chart cannot be modified directly. The bootstrap Job must also source Elasticsearch credentials from the existing `elasticsearch-es-elastic-user` secret.

## Decision
Deploy elastic-bootstrap as a Helm release from the CIMPL OCI registry and apply a kustomize postrender patch to inject probes, resource requests/limits, TTL cleanup, and secret-backed environment variables.

## Consequences
Elastic bootstrap runs after the Elasticsearch cluster is ready, remains safeguards compliant without chart forks, and can be safely re-run because the Job is cleaned up via TTL and re-created on Helm upgrades.
