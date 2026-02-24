# Amos — History

## Learnings
- 2026-02-24: Added AKS elastic-bootstrap Helm release with postrendered Job patches (probes/resources/TTL) and secret-sourced Elasticsearch credentials to initialize OSDU index templates, ILM policies, and aliases.
- 2026-02-24: Added Bitnami RabbitMQ Helm release with pinned image, managed-csi-premium Retain storage, Karpenter stateful scheduling, and STRICT Istio mTLS in the rabbitmq namespace.
