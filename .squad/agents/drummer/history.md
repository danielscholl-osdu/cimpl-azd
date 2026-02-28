# Drummer — History

## Current State (v0.2.0, 2026-02-27)

**Validation targets:**
- `terraform fmt -check -recursive ./infra`
- `terraform fmt -check -recursive ./software/stack`
- PowerShell syntax validation for `scripts/*.ps1`
- Pod health in `platform` and `osdu` namespaces

**Deployed and validated:**
- Phase 1 middleware: ES green, PG running, Redis running, RabbitMQ running, MinIO running, Keycloak running
- Phase 2 services: Partition Running, Entitlements Running (both `type=core` + bootstrap complete)

**Next validation:** Phase 3 (#127) — Legal, Schema, Storage, Search, Indexer, File health checks

## Learnings

### AKS safeguards-compliant curl pod
For in-cluster health checks, must create a pod with full safeguards compliance:
- seccompProfile: RuntimeDefault
- Resource requests and limits
- Security context (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)
- Tolerations for platform nodepool
- Image: `curlimages/curl:8.12.1` (pinned tag, not :latest)

### Service health endpoints
- All OSDU Java services: port 8081 at `/health/liveness` and `/health/readiness`
- App port 8080 does NOT serve health endpoints
- K8s Service port is 80 (targetPort 8080) for app traffic
