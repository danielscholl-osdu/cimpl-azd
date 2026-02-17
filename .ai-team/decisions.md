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
