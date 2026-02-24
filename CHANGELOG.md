# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-02-24

### Added

- **ADR Framework**: 10 Architecture Decision Records documenting all major design choices ([ADR-0001](docs/src/decisions/0001-use-aks-automatic-as-deployment-target.md) through [ADR-0010](docs/src/decisions/0010-unique-service-selector-label-pattern.md))
- **CONTRIBUTING.md**: Contributing guide with branching model, quality gates, and conventions
- **AGENTS.md**: Rewritten with Critical Rules (ALWAYS/NEVER), Core Patterns, and Quality Gates
- **RabbitMQ raw manifests**: Replaced Bitnami Helm chart with raw K8s manifests using official `rabbitmq:4.1.0-management-alpine` image (Bitnami images removed from DockerHub Aug 2025)
- **Elasticsearch TLS**: Enabled ECK self-signed TLS for Elasticsearch HTTP transport (required by bootstrap chart HTTPS URLs)
- **Elastic bootstrap secrets**: ServiceAccount, credential secrets, and init container for bootstrap job
- **Karpenter stateful NodePool**: Dynamic VM SKU selection for stateful workloads, eliminating `OverconstrainedZonalAllocationRequest` failures
- **CNPG multi-database support**: Additional databases (Keycloak, Airflow) via idempotent Job
- **Two-phase deployment gate**: Behavioral dry-run gate for Azure Policy convergence on fresh clusters
- **CI workflows**: Terraform format check, PowerShell syntax validation, secrets scan

### Fixed

- **Elastic bootstrap postrender**: Fixed kustomize target from `kind: Deployment` to `kind: Job` (patch was silently not applying)
- **ECK secret race condition**: Added `time_sleep` resource between Elasticsearch CR creation and secret read
- **Architecture docs**: Updated stale sections (RabbitMQ, ES TLS, Istio mTLS, safeguards mode)

### Changed

- **Squad workflows**: Replaced Node.js scaffolding with Terraform/PowerShell validation in all CI, preview, promote, and release workflows
- **Versioning**: Git tag-based semver (no `package.json`)
- **CLAUDE.md**: Consolidated into AGENTS.md and docs/ (removed)
