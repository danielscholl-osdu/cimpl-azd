# cimpl-azd Architecture

This document describes the architecture and design decisions for the CIMPL AKS deployment.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure Subscription                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Resource Group: rg-cimpl-<env>                     │  │
│  │                                                                       │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │  │
│  │  │                 AKS Automatic: cimpl-<env>                       │ │  │
│  │  │                                                                  │ │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐   │ │  │
│  │  │  │   System    │  │   Default   │  │   Platform (Karpenter)  │   │ │  │
│  │  │  │  Node Pool  │  │  Node Pool  │  │      Node Pool          │   │ │  │
│  │  │  │  (2 nodes)  │  │  (auto)     │  │      (auto)             │   │ │  │
│  │  │  │             │  │             │  │                         │   │ │  │
│  │  │  │ - Istio     │  │ - MinIO     │  │ - Elasticsearch (3)     │   │ │  │
│  │  │  │ - CoreDNS   │  │ - cert-mgr  │  │ - PostgreSQL HA (3)     │   │ │  │
│  │  │  │ - Gateway   │  │ - Airflow   │  │ - Redis                 │   │ │  │
│  │  │  │             │  │   task pods │  │ - RabbitMQ (3)          │   │ │  │
│  │  │  │             │  │             │  │ - Keycloak              │   │ │  │
│  │  │  │             │  │             │  │ - Kibana                │   │ │  │
│  │  │  │             │  │             │  │ - Airflow (control)     │   │ │  │
│  │  │  │             │  │             │  │ - OSDU services         │   │ │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘   │ │  │
│  │  │                                                                  │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────────┐│ │  │
│  │  │  │                    Istio Service Mesh                        ││ │  │
│  │  │  │                                                              ││ │  │
│  │  │  │   Internet ──► Ingress Gateway ──► HTTPRoute ──► Pods        ││ │  │
│  │  │  │              (External LB)        (Gateway API)              ││ │  │
│  │  │  └──────────────────────────────────────────────────────────────┘│ │  │
│  │  └──────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Two-Layer Deployment Model

The deployment is split into two layers, each with its own Terraform state (see [ADR-0006](../decisions/0006-two-layer-terraform-state.md)):

### Layer 1: Cluster Infrastructure (`infra/`)

**Purpose**: Provision the foundational AKS cluster and Azure resources.

**Components**:
- Azure Resource Group with tags
- AKS Automatic cluster
- System node pool (critical workloads)
- Istio service mesh (AKS-managed)
- Azure RBAC integration
- Workload Identity support
- Storage CSI drivers

**Terraform Resources**:
```
azurerm_resource_group.main
module.aks (Azure Verified Module)
azurerm_role_assignment.aks_cluster_admin
azurerm_resource_policy_exemption.cnpg_probe_exemption
```

**Key Configuration**:
```hcl
# AKS Automatic with Istio
sku = { name = "Automatic", tier = "Standard" }
service_mesh_profile = { mode = "Istio" }
```

### Layer 2: Software Stack (`software/stack/`)

**Purpose**: Deploy all platform middleware and OSDU services onto the cluster.

This layer combines middleware and OSDU services in a single Terraform state because they share the same deployment lifecycle and OSDU services have explicit `depends_on` relationships with middleware modules (e.g., Entitlements depends on Keycloak and Partition).

**Middleware Components** (all in `platform` namespace):
- cert-manager with Let's Encrypt ClusterIssuer
- ECK Operator + Elasticsearch + Kibana
- Elastic Bootstrap job (index templates, ILM policies, aliases)
- CloudNativePG (CNPG) Operator + 3-instance HA PostgreSQL cluster
- Redis (Bitnami chart, cache layer)
- RabbitMQ (raw manifests, clustered messaging)
- MinIO (standalone, S3-compatible object storage)
- Keycloak (raw manifests, identity provider)
- Apache Airflow (KubernetesExecutor, official chart)
- Gateway API configuration (Istio)
- Karpenter NodePool + AKSNodeClass for workloads (NAP)
- Custom StorageClasses for Elasticsearch and PostgreSQL

**OSDU Services** (all in `osdu` namespace):
- OSDU common resources (namespace, ConfigMap, secrets, mTLS)
- Partition service (data partition management)
- Entitlements service (access control)
- Additional OSDU services as they are ported

---

## Namespace Architecture

All resources are organized into two namespaces with optional stack-id suffix for multi-stack support (see [ADR-0017](../decisions/0017-consolidated-namespace-architecture.md)):

| Namespace | Contents | Istio Injection |
|-----------|----------|-----------------|
| `platform` | All middleware (ES, PG, Redis, RabbitMQ, MinIO, Keycloak, Airflow) | Disabled |
| `osdu` | OSDU common resources + all OSDU services | Enabled (STRICT mTLS) |

For named stacks (e.g., `STACK_NAME=blue`), namespaces become `platform-blue` and `osdu-blue`.

---

## AKS Automatic Configuration

### Why AKS Automatic?

AKS Automatic provides:
- **Simplified operations**: Auto-scaling, auto-upgrade, auto-repair
- **Built-in best practices**: Network policy, pod security, cost optimization
- **Integrated Istio**: Managed service mesh without manual installation
- **Deployment Safeguards**: Gatekeeper policies for compliance

### Node Pools

| Pool | Purpose | VM Size | Count | Taints | Managed By |
|------|---------|---------|-------|--------|------------|
| system | Critical system components | `var.system_pool_vm_size` (default: Standard_D4lds_v5) | 2 | CriticalAddonsOnly | AKS (VMSS) |
| default | General workloads (MinIO, Airflow task pods) | Auto-provisioned | Auto | None | NAP (Karpenter) |
| platform | Middleware + OSDU services | D-series (4-8 vCPU) | Auto | workload=platform:NoSchedule | NAP (Karpenter) |

**System Pool Variables**:
- `system_pool_vm_size` — VM SKU for system nodes (default: `Standard_D4lds_v5`)
- `system_pool_availability_zones` — Zones for system nodes (default: `["1", "2", "3"]`)

### Why Karpenter (NAP) for Platform Workloads?

The platform node pool uses AKS Node Auto-Provisioning (NAP), powered by Karpenter, instead of a traditional VMSS-based agent pool (see [ADR-0004](../decisions/0004-karpenter-nodepools-for-stateful-scheduling.md)):

1. **Eliminates `OverconstrainedZonalAllocationRequest` failures**: Karpenter selects from multiple D-series VM SKUs per zone.
2. **Dynamic SKU selection**: 4-8 vCPU VMs with premium storage support, best available option per zone.
3. **Automatic scaling**: Nodes provisioned on-demand and consolidated when empty.

The Karpenter `NodePool` and `AKSNodeClass` CRDs are deployed in `software/stack/main.tf`. Workloads target these nodes via `agentpool: platform` nodeSelector and `workload=platform:NoSchedule` toleration.

### Network Configuration

```
Network Plugin:      Azure CNI Overlay
Network Dataplane:   Cilium
Outbound Type:       Managed NAT Gateway
Service CIDR:        10.0.0.0/16
DNS Service IP:      10.0.0.10
```

### Istio Service Mesh (asm-1-28)

AKS-managed Istio provides:
- Automatic sidecar injection (via namespace label on `osdu` namespace)
- Traffic management via Gateway API
- External ingress gateway
- mTLS between OSDU services

```yaml
# Istio injection enabled on OSDU namespace
metadata:
  labels:
    istio-injection: enabled
```

See [ADR-0008](../decisions/0008-selective-istio-sidecar-injection.md) for the selective injection strategy.

---

## Platform Component Details

### Elasticsearch Cluster

**Architecture**: 3-node cluster with combined master/data/ingest roles

```
┌─────────────────────────────────────────────────────────────────┐
│                    Elasticsearch Cluster                        │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  ES Node 1   │  │  ES Node 2   │  │  ES Node 3   │           │
│  │  (master+    │  │  (master+    │  │  (master+    │           │
│  │   data+      │  │   data+      │  │   data+      │           │
│  │   ingest)    │  │   ingest)    │  │   ingest)    │           │
│  │              │  │              │  │              │           │
│  │  128Gi SSD   │  │  128Gi SSD   │  │  128Gi SSD   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│              ┌─────────────┴─────────────┐                      │
│              │    Elasticsearch Service   │                     │
│              │    (ClusterIP:9200)        │                     │
│              └───────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

**Storage**: Custom StorageClass with Premium LRS and Retain policy
```yaml
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  kind: Managed
  cachingMode: ReadOnly
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### Kibana

Single-replica deployment with external access via Gateway API.

**Traffic Flow**:
```
Internet ──► External IP ──► Istio Gateway ──► HTTPRoute ──► Kibana Service ──► Pod
                                                     │
                                           cert-manager TLS
```

### ECK Operator

Elastic Cloud on Kubernetes (ECK) operator manages the Elasticsearch and Kibana deployments.

**Version**: 2.16.0

**Probe Injection Workaround**:
The ECK operator Helm chart does not expose probe configuration. We use a Helm postrenderer with kustomize to inject tcpSocket probes on the webhook port (9443) during deployment (see [ADR-0002](../decisions/0002-helm-postrender-kustomize-for-safeguards.md)).

**Unique Service Selector Workaround**:
ECK creates multiple services that can have overlapping selectors, violating AKS Automatic's `K8sAzureV1UniqueServiceSelector` policy. We use ECK's native service selector overrides to differentiate them (see [ADR-0010](../decisions/0010-unique-service-selector-compliance.md)).

### Elastic Bootstrap

Post-deploy Job that configures index templates, ILM policies, and aliases required by OSDU services. It runs after Elasticsearch is healthy, uses the CIMPL elastic-bootstrap chart/image, and pulls credentials from the `elasticsearch-es-elastic-user` secret.

### PostgreSQL (CloudNativePG)

3-instance HA PostgreSQL cluster managed by the CloudNativePG (CNPG) operator with synchronous replication.

**Architecture**: 1 primary (read-write) + 2 sync replicas (read-only), spread across 3 availability zones.

```
┌─────────────────────────────────────────────────────────────────┐
│                    PostgreSQL Cluster (CNPG)                    │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Instance 1  │  │  Instance 2  │  │  Instance 3  │           │
│  │  PRIMARY     │──►  REPLICA     │  │  REPLICA     │           │
│  │  (read-write)│  │  (read-only) │  │  (read-only) │           │
│  │              │ ───────────────►│  │              │           │
│  │  8Gi + 4Gi   │  │  8Gi + 4Gi   │  │  8Gi + 4Gi   │           │
│  │  (data+WAL)  │  │  (data+WAL)  │  │  (data+WAL)  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│       Zone 1             Zone 2             Zone 3              │
│                                                                 │
│  ┌────────────────────┐  ┌────────────────────────┐             │
│  │ postgresql-rw :5432│  │ postgresql-ro :5432    │             │
│  │ (primary service)  │  │ (read-only replicas)   │             │
│  └────────────────────┘  └────────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

**Configuration**:
- Operator: CNPG chart `cloudnative-pg` v0.27.1
- Instances: 3 (synchronous quorum replication: `minSyncReplicas: 1, maxSyncReplicas: 1`)
- Databases: 14 separate databases (one per OSDU service), matching ROSA topology (see [ADR-0014](../decisions/0014-rosa-alignment-and-deliberate-differences.md))
- Storage: 8Gi data + 4Gi WAL per instance on `pg-storageclass` (Premium_LRS, Retain)
- Read-write: `postgresql-rw.platform.svc.cluster.local:5432`
- Read-only: `postgresql-ro.platform.svc.cluster.local:5432`
- Node affinity: `agentpool=platform` with `workload=platform:NoSchedule` toleration

**CNPG Probe Exemption**: CNPG creates short-lived initdb/join Jobs that cannot have health probes. An Azure Policy Exemption is configured in `infra/aks.tf` to waive the probe requirement (see [ADR-0005](../decisions/0005-two-phase-deployment-gate.md)).

### RabbitMQ

RabbitMQ cluster for async messaging (OSDU service broker).

**Configuration**:
- Deployment: Raw Kubernetes manifests (StatefulSet, Services, ConfigMap) — no Helm chart (see [ADR-0003](../decisions/0003-raw-manifests-for-rabbitmq.md))
- Image: `rabbitmq:4.1.0-management-alpine` (official upstream)
- Replicas: 3 (clustered via DNS peer discovery)
- Storage: 8Gi `rabbitmq-storageclass` (Premium_LRS, Retain)
- Connection: `rabbitmq.platform.svc.cluster.local:5672`
- Node affinity: `agentpool=platform` with `workload=platform:NoSchedule` toleration

### Apache Airflow

Workflow orchestration engine for DAG-based task scheduling, deployed using the official Apache Airflow Helm chart (see [ADR-0011](../decisions/0011-airflow-kubernetes-executor-with-nap.md)).

**Configuration**:
- Chart: `apache-airflow/airflow` v1.19.0 (official, from `https://airflow.apache.org`)
- Image: `apache/airflow:3.1.7`
- Executor: **KubernetesExecutor** (creates a pod per task, no persistent workers)
- Database: PostgreSQL (`airflow` DB via CNPG bootstrap job)
- Namespace: `platform`
- Control-plane components on `platform` nodepool; task pods on default pool (scale-to-zero)

### Keycloak

Identity provider for authentication and authorization, deployed as raw Kubernetes manifests (see [ADR-0016](../decisions/0016-raw-manifests-for-keycloak.md)).

**Configuration**:
- Image: `quay.io/keycloak/keycloak:26.5.4` (official, pinned tag)
- Deployment: Raw StatefulSet, Services, ConfigMap — no Helm chart
- Database: PostgreSQL (`keycloak` DB via CNPG bootstrap job)
- Namespace: `platform`
- OSDU realm auto-imported at startup via `--import-realm` with `datafier` confidential client
- JWKS readiness gate: `null_resource.keycloak_jwks_wait` ensures Keycloak is ready before OSDU services deploy
- Internal-only: No HTTPRoute/Gateway exposure; access via `kubectl port-forward`
- Node affinity: `agentpool=platform` with `workload=platform:NoSchedule` toleration

### MinIO

MinIO standalone instance for S3-compatible object storage (dev/test).

**Configuration**:
- Chart: `minio/minio` v5.4.0
- Mode: standalone (single pod)
- Storage: 10Gi managed-csi PVC
- API Port: 9000
- Console Port: 9001
- Connection: `minio.platform.svc.cluster.local:9000`
- Runs on default (auto-provisioned) node pool

### cert-manager

Automatic TLS certificate management with Let's Encrypt.

**Components**:
- cert-manager controller
- ClusterIssuer (Let's Encrypt production)
- HTTP-01 challenge solver (via Istio Gateway)

---

## OSDU Service Layer

OSDU services are deployed into the `osdu` namespace using a reusable Terraform module (see [ADR-0015](../decisions/0015-osdu-service-module-and-sql-extraction.md)). Each service gets ~20 lines in `software/stack/osdu.tf` instead of a full Helm release definition. Services use CIMPL Helm charts from the OCI registry with chart-default images (see [ADR-0013](../decisions/0013-use-chart-default-images.md)).

### Deployed Services

| Service | Chart | Dependencies | Bootstrap |
|---------|-------|-------------|-----------|
| Partition | `core-plus-partition-deploy` | PostgreSQL | Registers data partition (`osdu`) with all service endpoints |
| Entitlements | `core-plus-entitlements-deploy` | Keycloak, Partition, PostgreSQL, Redis | Provisions tenant entitlements groups |
| Wellbore | `core-plus-wellbore-deploy` | Entitlements, Partition, PostgreSQL, Storage | TBD (bootstrap skipped for now) |
| Wellbore Worker | `core-plus-wellbore-worker-deploy` | Entitlements, Partition, Wellbore | None |
| CRS Conversion | `core-plus-crs-conversion-deploy` | Entitlements, Partition | None |
| CRS Catalog | `core-plus-crs-catalog-deploy` | Entitlements, Partition | None |
| EDS-DMS | `core-plus-eds-dms-deploy` | Entitlements, Partition, Storage | None |

### Service Deployment Pattern

Each OSDU service Helm chart includes:

1. **Core Deployment** (`type=core`) — the main Java service on port 8080 with health probes on management port 8081
2. **Bootstrap Deployment** (`type=bootstrap`) — seeds initial data by calling the service API after startup

Kustomize postrender patches (in `software/stack/kustomize/services/<name>/`) add:
- AKS-compliant probes (`initialDelaySeconds: 150-250s` for Java startup)
- Resource requests/limits
- Seccomp profiles
- Security context hardening

### Secrets and Configuration

OSDU services discover middleware via secrets created by the `osdu-common` module:

| Secret | Service | Key fields |
|--------|---------|------------|
| `partition-postgres-secret` | Partition | `OSM_POSTGRES_URL`, `OSM_POSTGRES_USERNAME`, `OSM_POSTGRES_PASSWORD` |
| `entitlements-multi-tenant-postgres-secret` | Entitlements | `ENT_PG_URL_SYSTEM`, `ENT_PG_USER_SYSTEM`, `ENT_PG_PASS_SYSTEM`, `SPRING_DATASOURCE_*` |
| `wellbore-postgres-secret` | Wellbore | `OSM_POSTGRES_URL`, `OSM_POSTGRES_USERNAME`, `OSM_POSTGRES_PASSWORD`, `WELLBORE_POSTGRES_DB_NAME` |
| `datafier-secret` | Entitlements bootstrap | `OPENID_PROVIDER_CLIENT_ID`, `OPENID_PROVIDER_CLIENT_SECRET`, `OPENID_PROVIDER_URL` |
| `entitlements-redis-secret` | Entitlements | `REDIS_PASSWORD` |

Secret key names align with ROSA conventions (see [ADR-0014](../decisions/0014-rosa-alignment-and-deliberate-differences.md)).

---

## Security Architecture

### Authentication & Authorization

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Active Directory                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   User Authentication                    │   │
│  │                                                          │   │
│  │  User ──► az login ──► AAD ──► kubelogin ──► K8s API     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  Workload Identity                       │   │
│  │                                                          │   │
│  │ Pod ──► Service Account ──► Federated Credential ──► AAD │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              OSDU Service Authentication                 │   │
│  │                                                          │   │
│  │ Service ──► Keycloak (osdu realm) ──► JWT validation     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Azure RBAC for Kubernetes

- Local accounts disabled
- Azure AD authentication required
- Azure RBAC roles:
  - `Azure Kubernetes Service RBAC Cluster Admin`
  - `Azure Kubernetes Service RBAC Admin`
  - `Azure Kubernetes Service RBAC Reader`

### AKS Deployment Safeguards

Gatekeeper policies enforcing:
- Resource limits on containers
- Health probes (readiness/liveness)
- Security context (runAsNonRoot, drop capabilities)
- No privileged containers

**Mode**: Enforcement on AKS Automatic (violations blocked at admission); Warning on standard AKS (violations logged)

**Azure Policy Exemption**: CNPG operator Jobs (initdb, join) are short-lived and cannot have health probes. An Azure Policy Exemption is applied at the cluster level in `infra/aks.tf`.

### Istio mTLS

- **`osdu` namespace**: STRICT mTLS via `PeerAuthentication`, full sidecar injection
- **`platform` namespace**: No sidecar injection (blocked by AKS `NET_ADMIN` restrictions for some components). Application-layer TLS where available (ECK self-signed TLS for Elasticsearch).

See [ADR-0007](../decisions/0007-eck-self-signed-tls-for-elasticsearch.md) and [ADR-0008](../decisions/0008-selective-istio-sidecar-injection.md).

### Network Security

- **Azure CNI Overlay**: Pod IPs in overlay network
- **Cilium**: Network policy enforcement
- **Managed NAT Gateway**: Outbound traffic via dedicated NAT
- **Istio mTLS**: STRICT mode in `osdu` namespace

---

## Data Flow

### External Traffic to Kibana

```
1. DNS: kibana.example.com ──► External IP (Azure LB)
2. Azure LB ──► Istio Ingress Gateway Pod (aks-istio-ingress ns)
3. Gateway ──► HTTPRoute routing rule
4. HTTPRoute ──► Kibana Service (platform ns)
5. Service ──► Kibana Pod
```

### Internal Service Communication

```
PostgreSQL (read-write):
  Pod ──► postgresql-rw.platform.svc.cluster.local:5432 ──► PG Primary

PostgreSQL (read-only):
  Pod ──► postgresql-ro.platform.svc.cluster.local:5432 ──► PG Replicas

Elasticsearch:
  Pod ──► elasticsearch-es-http.platform.svc.cluster.local:9200 ──► ES Pods

Redis:
  Pod ──► redis-master.platform.svc.cluster.local:6379 ──► Redis Pod

RabbitMQ:
  Pod ──► rabbitmq.platform.svc.cluster.local:5672 ──► RabbitMQ Pods

MinIO:
  Pod ──► minio.platform.svc.cluster.local:9000 ──► MinIO Pod

Keycloak (internal-only):
  Pod ──► keycloak.platform.svc.cluster.local:8080 ──► Keycloak Pod

OSDU Services (in osdu namespace, cross-namespace):
  Entitlements ──► partition.osdu.svc.cluster.local:80 ──► Partition Pod
  Bootstrap ──► keycloak.platform.svc.cluster.local:8080 ──► Keycloak (token)
  Bootstrap ──► entitlements.osdu.svc.cluster.local:80 ──► Entitlements (provisioning)
```

---

## Deployment Flow

### azd up Sequence (Two-Phase)

The deployment uses a two-phase approach to handle Azure Policy/Gatekeeper eventual consistency:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              azd up                                         │
│                                                                             │
│  ┌──────────────────┐                                                       │
│  │  pre-provision   │ Validate prerequisites (az cli, kubectl, etc.)        │
│  └────────┬─────────┘                                                       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐                                                       │
│  │  terraform apply │ Layer 1: Create AKS cluster + RBAC + policy exemption │
│  │  (infra/)        │ Output: cluster_name, resource_group, oidc_issuer     │
│  └────────┬─────────┘                                                       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  postprovision: post-provision.ps1  [GATE]                          │   │
│  │    1. Configure kubeconfig                                          │   │
│  │    2. Configure AKS safeguards (Warning mode)                       │   │
│  │    3. Wait for Gatekeeper controller ready                          │   │
│  │    4. Verify namespace exclusions / probe exemption                 │   │
│  │    5. EXIT with error if not ready (fail fast)                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                │                                            │
│                   (only if postprovision succeeds)                          │
│                                ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  predeploy: pre-deploy.ps1                                          │   │
│  │    1. Verify cluster access                                          │   │
│  │    2. terraform apply (software/stack/)                               │   │
│  │       - Middleware: ES, PG, Redis, RabbitMQ, MinIO, Keycloak         │   │
│  │       - OSDU: Partition, Entitlements                                 │   │
│  │    3. Verify component health                                        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why two phases?** Azure Policy/Gatekeeper is eventually consistent. Fresh clusters have a window where policies aren't fully reconciled. Making safeguards readiness an explicit gate eliminates the race condition (see [ADR-0005](../decisions/0005-two-phase-deployment-gate.md)).

### Feature Flags

All components default to enabled. To disable a component, set `TF_VAR_enable_<component>=false` in the azd environment. This "opt-out" model avoids cluttering the environment file as more OSDU services are added.

| Flag | Default | Component |
|------|---------|-----------|
| `enable_elasticsearch` | true | Elasticsearch + Kibana + ECK Operator |
| `enable_postgresql` | true | CloudNativePG + PostgreSQL cluster |
| `enable_redis` | true | Redis cache |
| `enable_rabbitmq` | true | RabbitMQ cluster |
| `enable_minio` | true | MinIO object storage |
| `enable_keycloak` | true | Keycloak identity provider |
| `enable_partition` | true | OSDU Partition service |
| `enable_entitlements` | true | OSDU Entitlements service |
| `enable_airflow` | false | Apache Airflow (not yet integrated with OSDU) |
| `enable_external_dns` | false | ExternalDNS (requires Workload Identity setup) |

### Terraform State

```
infra/
  └── terraform.tfstate    # Layer 1 state (AKS cluster)

software/stack/
  └── terraform.tfstate    # Layer 2 state (middleware + OSDU services)
```

---

## Monitoring & Observability

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| Azure Monitor Metrics | Enabled | AKS metrics to Azure Monitor |
| Elasticsearch Logs | Internal | ES stores own logs |
| Kibana Dashboards | Available | Access via external URL |

### Future Enhancements

- [ ] Azure Monitor Container Insights
- [ ] Prometheus + Grafana stack
- [ ] Distributed tracing (Jaeger/Zipkin)
- [ ] Log aggregation to Elasticsearch

---

## Resource Naming Convention

All resources follow the pattern: `<prefix>-<project>-<environment>`

| Resource | Naming Pattern | Example |
|----------|----------------|---------|
| Resource Group | `rg-cimpl-<env>` | rg-cimpl-dev |
| AKS Cluster | `cimpl-<env>` | cimpl-dev |
| Namespaces | `platform`, `osdu` (with optional stack suffix) | platform-blue, osdu-blue |

### Tagging Strategy

All Azure resources include:
- `azd-env-name`: Environment name
- `project`: cimpl
- `Contact`: Owner email address

---

## Scaling Considerations

### Elasticsearch

- Horizontal: Add nodes (terraform variable)
- Vertical: Change VM size (requires node pool recreation)
- Storage: Expandable via PVC (allowVolumeExpansion: true)

### PostgreSQL

- Horizontal: Increase CNPG cluster `instances` count (add read replicas)
- Vertical: Adjust resource requests/limits in the Cluster CR
- Storage: Expandable via PVC (allowVolumeExpansion: true on pg-storageclass)

### MinIO

- Currently single-instance standalone mode
- Consider Azure Blob Storage for production

### AKS Automatic

- Node pools auto-scale based on demand
- Cluster auto-upgrade maintains security patches
- Cost optimization through auto-provisioning

---

## Disaster Recovery

### Backup Targets

| Component | Data | Backup Method |
|-----------|------|---------------|
| Elasticsearch | Indices | Snapshot to Azure Blob |
| PostgreSQL | Database | pg_dump to Azure Blob |
| RabbitMQ | Queues | Export definitions + retain PVCs |
| MinIO | Objects | Already S3-compatible |

### Recovery Strategy

1. **RTO** (Recovery Time Objective): 4 hours
2. **RPO** (Recovery Point Objective): 24 hours
3. **Strategy**: Redeploy infrastructure, restore data from backups

### PVC Retention

- Elasticsearch uses `reclaimPolicy: Retain` (es-storageclass)
- PostgreSQL uses `reclaimPolicy: Retain` (pg-storageclass)
- RabbitMQ uses `reclaimPolicy: Retain` (managed-csi-premium)
- Data persists even if pods are deleted
- Manual cleanup required after intentional deletion

---

## Troubleshooting

### OverconstrainedZonalAllocationRequest

AKS Automatic mandates ephemeral OS disks on system pool VMs. Combined with 3-zone pinning and a specific VM SKU, this can cause `OverconstrainedZonalAllocationRequest` failures when any zone lacks capacity.

**Workaround**: Reduce the system pool to zones with available capacity:

```bash
# Skip zone 2 (example for centralus capacity issues)
azd env set TF_VAR_system_pool_availability_zones '["1", "3"]'

# Or try a different VM size
azd env set TF_VAR_system_pool_vm_size 'Standard_D4as_v5'

# Then redeploy
azd up
```

The platform workload pool uses Karpenter (NAP) with dynamic SKU selection, so it is not affected by this issue.

---

## Known Limitations

1. **Single Region**: No multi-region deployment
2. **No HA for MinIO**: Single instance standalone deployment
3. **Manual DNS**: Requires external DNS configuration (unless ExternalDNS is enabled)
4. **Local Terraform State**: Consider remote state for team use
5. **Safeguards Gate Timeout**: Phase 1 uses a behavioral gate that waits for Gatekeeper constraints to leave deny mode; if Azure Policy sync is slow, re-run `azd provision` to retry
6. **CNPG Policy Exemption**: Azure Policy Exemption for probe enforcement is required for CNPG Jobs; this is a cluster-wide waiver for the specific probe policy

See [Troubleshooting](../operations/troubleshooting.md) for common issues and workarounds.
