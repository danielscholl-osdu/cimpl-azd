# Team Decisions

This file records architectural and process decisions made by the team.
Scribe merges inbox entries here and deduplicates.

### 2026-02-17: Team structure — three dev specializations
**By:** Squad (Coordinator)
**What:** Team split into Infra Dev (Naomi), Platform Dev (Amos), and Services Dev (Alex) matching the three-layer architecture
**Why:** The project has three distinct domains: AKS cluster infra, stateful middleware (Elasticsearch, PostgreSQL, etc.), and ~20 OSDU microservices. Each requires different expertise and the work is largely independent.

### 2025-07-18: ROSA-to-AKS Parity — Gap Analysis Complete
**By:** Holden
**What:** Completed full gap analysis comparing ROSA reference implementation (8 infra + ~22 services) against current AKS implementation. Identified 4 missing infra components (Common, Keycloak, RabbitMQ, Airflow), all ~22 OSDU services missing, and 10 open questions requiring user input before implementation can proceed.
**Why:** The user asked for a parity plan. Rather than assume answers to ambiguous architectural questions (e.g., can Entra ID replace Keycloak? What does the Common chart do?), I documented specific questions. The analysis reveals the current AKS implementation covers Layer 2 middleware well (Elasticsearch, PostgreSQL, MinIO, Redis, cert-manager) but the entire Layer 3 (OSDU services) is unbuilt. A phased 5-8 week migration plan was proposed.

### 2025-07-18: AKS-managed Istio is the correct approach (confirmed)
**By:** Holden
**What:** ROSA uses self-managed Istio (ambient profile, OpenShift) with 5 Helm releases. AKS uses AKS-managed Istio (asm-1-28). These are architecturally different but self-managed Istio CANNOT work on AKS Automatic due to NET_ADMIN/NET_RAW being blocked.
**Why:** This is a non-negotiable architectural constraint. Any service chart that assumes self-managed Istio behavior (istio-init containers, ambient mode) will need adaptation.

### 2025-07-18: CloudNativePG is an upgrade over ROSA PostgreSQL
**By:** Holden
**What:** ROSA uses a CIMPL-wrapped Bitnami chart (single instance). AKS uses CloudNativePG with 3-instance HA, sync replication, and separate WAL storage. Services must use `postgresql-rw.postgresql.svc.cluster.local` instead of simple `postgresql` hostname.
**Why:** This is a positive architectural change but services connecting to PostgreSQL will need endpoint configuration updates.

### 2025-07-18: Service namespace strategy needs decision
**By:** Holden
**What:** ROSA deploys all infra and services into a single `osdu` namespace. AKS currently uses per-component namespaces for infra. Recommendation is to use a single `osdu` namespace for all OSDU services to match ROSA's inter-service communication patterns.
**Why:** Namespace choice affects service DNS resolution, RBAC, network policies, and chart configuration. Must be decided before Phase 2.

### 2026-02-17: User directive — Keycloak required
**By:** Daniel Scholl (via Copilot)
**What:** Entra ID cannot replace Keycloak. Keycloak must be deployed as an infrastructure component.
**Why:** User request — captured for team memory

### 2026-02-17: User directive — RabbitMQ required by OSDU services
**By:** Daniel Scholl (via Copilot)
**What:** RabbitMQ is used by OSDU services directly, not just Airflow. Must be deployed.
**Why:** User request — captured for team memory

### 2026-02-17: User directive — Airflow can share existing Redis
**By:** Daniel Scholl (via Copilot)
**What:** Airflow should use the existing Redis deployment rather than deploying its own.
**Why:** User request — captured for team memory

### 2026-02-17: User directive — Elasticsearch already running
**By:** Daniel Scholl (via Copilot)
**What:** Elasticsearch is already deployed and running on AKS. Elastic Bootstrap status needs investigation.
**Why:** User request — captured for team memory

### 2026-02-17: User directive — OCI registry sourcing
**By:** Daniel Scholl (via Copilot)
**What:** OSDU service charts/images are pulled from OSDU community repositories. Each service has its own repository in GitLab (community.opengroup.org).
**Why:** User request — captured for team memory

### 2026-02-17: User directive — Bootstrap Data is required
**By:** Daniel Scholl (via Copilot)
**What:** Bootstrap Data is required for parity. The commented-out bootstrap-data modules in ROSA must be implemented on AKS.
**Why:** User request — captured for team memory

### 2025-07-18: Common Chart — No direct AKS equivalent needed
**By:** Amos
**What:** The ROSA `common-infra-bootstrap` chart is a namespace/config bootstrap that creates shared resources (namespace, RBAC, ConfigMaps) in the single `osdu` namespace. On AKS, we already handle this differently: per-component namespaces via `kubernetes_namespace` resources, Azure RBAC integration, and config passed directly through Terraform variables to each Helm release. No standalone "common" module is needed unless we adopt a single `osdu` namespace strategy, in which case we'd need a lightweight equivalent to create the namespace, shared ConfigMaps (domain, project ID), and any ServiceAccounts that multiple services share.
**Why:** Clarifies gap analysis Q1. The Common chart is not a blocker for Phase 2 platform work. If/when we move to a single `osdu` namespace (per Holden's recommendation), we should create a simple `platform/k8s_common.tf` with `kubernetes_namespace`, `kubernetes_config_map`, and `kubernetes_service_account` resources — no Helm chart needed.

### 2025-07-18: Elastic Bootstrap — AKS equivalent needed before OSDU services
**By:** Amos
**What:** The ROSA `elastic-bootstrap` is a post-deploy initialization job that configures Elasticsearch with index templates, ILM policies, and aliases that OSDU services expect to find. It uses a custom CIMPL container image and runs after Elasticsearch is healthy. On AKS with ECK, we have a working Elasticsearch cluster but no index bootstrapping. OSDU services (indexer, search, storage) will fail at runtime if expected index templates and ILM policies don't exist.
**Why:** Clarifies gap analysis Q6. This is a **Phase 2 dependency** — needed before any OSDU service that writes to or reads from Elasticsearch. Recommended AKS approach: create a `platform/k8s_elastic_bootstrap.tf` that deploys a Kubernetes Job (using the same CIMPL bootstrap image or a custom script) to configure index templates and ILM policies via the Elasticsearch REST API. The Job should: (1) wait for ES cluster health green/yellow, (2) apply index templates, (3) apply ILM policies, (4) create initial aliases. This can use `kubectl_manifest` with a Job spec, depending on `kubectl_manifest.elasticsearch`.

### 2025-07-18: OSDU Service Charts Require Postrender Patches for AKS Safeguards
**By:** Alex (Services Dev)
**What:** Investigation of all 24 CIMPL service Helm modules confirms zero probes, resource requests/limits, or seccomp settings exist in the Terraform-level configuration. All compliance must come from the OCI charts themselves (which we cannot inspect without pulling) or from postrender/kustomize patches. Given that we already needed kustomize patches for minio, eck-operator, and cert-manager, the working assumption should be that every OSDU service will also need patches.
**Why:** This determines our migration strategy. Rather than creating 20+ individual kustomize patch directories, we should consider a shared postrender approach — possibly a single kustomize overlay that targets all Deployments in the OSDU namespace with generic probe/resource/seccomp patches.

### 2025-07-18: All CIMPL Service Images Default to :latest — Must Override
**By:** Alex (Services Dev)
**What:** Every service module defaults its container image to `:latest` tags (e.g., `cimpl-partition-master:latest`). ROSA overrides these at the top-level variables.tf with pinned commit-hash tags (e.g., `core-plus-partition-release:67dedce7`). For AKS Automatic, we MUST use the pinned tags — `:latest` will be rejected by Gatekeeper (`K8sAzureV2ContainerNoLatestImage`).
**Why:** Image pinning is mandatory, not optional, on AKS Automatic. Our service Terraform modules must always specify pinned image tags.

### 2025-07-18: OETP Server — Exclude from Initial AKS Migration
**By:** Alex (Services Dev)
**What:** OETP server is disabled in ROSA (`enable_oetp_server = false`), is a specialized WebSocket streaming protocol, and both server and client modules exist but client is never wired up. Recommend excluding from Phase 1 AKS migration.
**Why:** Focus on core OSDU services first. OETP can be added later if needed.

### 2025-07-18: Subscriber Key is an Env Var, Not a Secret Mount
**By:** Alex (Services Dev)
**What:** `cimpl_subscriber_private_key_id` is injected into every service pod as a Helm `set_sensitive` value mapped to `data.subscriberPrivateKeyId`. This becomes a Kubernetes Secret mounted as an environment variable (via Helm's standard set_sensitive mechanism). The value is a plain string identifier ("Subscriber ID"), not a file-based key.
**Why:** For AKS, we need to decide how to source this value — options include azd env variable, Azure Key Vault reference, or Kubernetes Secret. The current ROSA approach (Terraform variable) works fine but the value should be marked `sensitive = true` in our Terraform outputs.

### 2026-02-17: GitHub issues created for ROSA→AKS migration
**By:** Holden
**What:** Created 28 issues (#78–#105) in danielscholl-osdu/cimpl-azd organized by 6 phases: Phase 0.5 (postrender framework), Phase 1 (missing infrastructure: Keycloak, RabbitMQ, Airflow, Common, Elastic Bootstrap), Phase 2 (foundation services: Partition, Entitlements), Phase 3 (core services: Legal, Schema, Storage, Search, Indexer, File), Phase 4 (extended services: Notification, Dataset, Register, Policy, Secret, Unit, Workflow), Phase 5 (domain services + bootstrap data: Wellbore, Wellbore Worker, CRS Conversion, CRS Catalog, EDS-DMS, Bootstrap Data). Master tracking issue is #105.
**Why:** Tracking the full migration from ROSA to AKS parity. Labels created for phase grouping (`phase:0`–`phase:5`), layer assignment (`layer:platform`, `layer:services`), and squad ownership (`squad:amos`, `squad:alex`, `squad:holden`). Each issue includes ROSA reference details (chart, version, image tag), AKS implementation targets, acceptance criteria, and dependency links.
