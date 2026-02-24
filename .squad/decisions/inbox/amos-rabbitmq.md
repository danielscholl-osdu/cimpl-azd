---
date: 2026-02-24
by: Amos
title: RabbitMQ storage class and image pinning
---

## Context
RabbitMQ requires premium persistent storage with a Retain policy and AKS safeguards require pinned image tags. The default managed-csi-premium storage class uses a Delete reclaim policy.

## Decision
Manage a `managed-csi-premium` StorageClass manifest with `reclaimPolicy: Retain` for RabbitMQ PVCs and pin the Bitnami RabbitMQ image to a specific version tag.

## Consequences
RabbitMQ PVCs persist after release deletion and require manual cleanup when decommissioning. Image pinning avoids AKS policy violations from latest tags and keeps deployments reproducible.
