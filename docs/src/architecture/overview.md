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
│  │  │  │   System    │  │   Default   │  │   Stateful (Karpenter)  │   │ │  │
│  │  │  │  Node Pool  │  │  Node Pool  │  │      Node Pool          │   │ │  │
│  │  │  │  (2 nodes)  │  │  (auto)     │  │      (auto)             │   │ │  │
│  │  │  │             │  │             │  │                         │   │ │  │
│  │  │  │ - Istio     │  │ - MinIO     │  │ - Elasticsearch (3)     │   │ │  │
│  │  │  │ - CoreDNS   │  │ - cert-mgr  │  │ - PostgreSQL HA (3)     │   │ │  │
│  │  │  │ - Gateway   │  │ - Airflow   │  │ - Redis                 │   │ │  │
│  │  │  │             │  │   task pods │  │ - Airflow (sched/web)   │   │ │  │
│  │  │  │             │  │             │  │ - Keycloak              │   │ │  │
│  │  │  │             │  │             │  │ - Kibana (1)            │   │ │  │
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

## Three-Layer Deployment Model

The deployment is split into three distinct layers, each with its own terraform state:

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

### Layer 2: Platform Components (`platform/`)

**Purpose**: Deploy shared platform services that applications depend on.

**Components**:
- cert-manager with Let's Encrypt ClusterIssuer
- ECK Operator + Elasticsearch + Kibana
- Elastic Bootstrap job (index templates, ILM policies, aliases)
- CloudNativePG (CNPG) Operator + 3-instance HA PostgreSQL cluster
- Redis (Bitnami chart, cache layer)
- Apache Airflow 3.1.7 (KubernetesExecutor, official chart)
- Keycloak 26.5.4 (Bitnami chart, official image)
- MinIO (standalone, S3-compatible object storage)
- Gateway API configuration (Istio)
- Karpenter NodePool + AKSNodeClass for stateful workloads (NAP)
- Custom StorageClasses for Elasticsearch and PostgreSQL

**Terraform Resources**:
```
helm_release.cert_manager
helm_release.elastic_operator
kubectl_manifest.elasticsearch
kubectl_manifest.elasticsearch_peer_authentication
kubectl_manifest.kibana
helm_release.cnpg_operator
kubectl_manifest.postgresql_cluster
kubectl_manifest.postgresql_peer_authentication
kubectl_manifest.pg_storage_class
kubernetes_secret.postgresql_superuser
kubernetes_secret.postgresql_user
kubernetes_namespace.postgresql
helm_release.minio
kubectl_manifest.gateway_api_crds (for_each)
kubectl_manifest.gateway
kubectl_manifest.http_route
kubectl_manifest.karpenter_nodepool_stateful
kubectl_manifest.karpenter_aksnodeclass_stateful
```

**Gateway API CRDs**: Gateway API Custom Resource Definitions are managed declaratively via Terraform `kubectl_manifest` resources using `for_each`, with the CRD file pinned at `platform/crds/gateway-api-v1.2.1.yaml`. This replaces the previous `local-exec` approach that used `kubectl apply` and `kubectl wait`, providing better state tracking and idempotent management.

### Layer 3: Services (`services/`) [Future]

**Purpose**: Deploy application services on top of the platform.

**Planned Components**:
- OSDU platform services
- Custom applications
- API definitions

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
| stateful | Elasticsearch, PostgreSQL, Redis, Airflow, Keycloak | D-series (4-8 vCPU) | Auto | workload=stateful:NoSchedule | NAP (Karpenter) |

**System Pool Variables**:
- `system_pool_vm_size` — VM SKU for system nodes (default: `Standard_D4lds_v5`)
- `system_pool_availability_zones` — Zones for system nodes (default: `["1", "2", "3"]`)

### Why Karpenter (NAP) for Stateful Workloads?

The stateful node pool uses AKS Node Auto-Provisioning (NAP), powered by Karpenter, instead of a traditional VMSS-based agent pool. This change was made because:

1. **Eliminates `OverconstrainedZonalAllocationRequest` failures**: Traditional VMSS pools pin a single VM SKU (e.g., `Standard_D4as_v5`) across all 3 availability zones. When any zone lacks capacity for that exact SKU, cluster creation fails entirely.
2. **Dynamic SKU selection**: Karpenter selects from any D-series VM with 4-8 vCPUs and premium storage support, choosing the best available option per zone.
3. **Automatic scaling**: Nodes are provisioned on-demand when pods are pending and consolidated when empty, rather than maintaining a fixed pool.

The Karpenter `NodePool` and `AKSNodeClass` CRDs are deployed in the platform layer (`platform/k8s_karpenter.tf`). Workloads target these nodes via the same `agentpool: stateful` label and `workload=stateful:NoSchedule` toleration used previously.

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
- Automatic sidecar injection (via namespace label)
- Traffic management (VirtualServices, DestinationRules)
- External ingress gateway
- mTLS between services

```yaml
# Enable Istio injection for a namespace
metadata:
  labels:
    istio-injection: enabled
```

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

Single-replica deployment with external access via Istio Gateway.

**Traffic Flow**:
```
Internet ──► External IP ──► Istio Gateway ──► VirtualService ──► Kibana Service ──► Pod
                                                     │
                                           cert-manager TLS
```

### ECK Operator

Elastic Cloud on Kubernetes (ECK) operator manages the Elasticsearch and Kibana deployments.

**Version**: 2.16.0

**Probe Injection Workaround**:
The ECK operator Helm chart does not expose probe configuration, which is required by AKS Automatic Deployment Safeguards. We use a Helm postrenderer with kustomize to inject tcpSocket probes on the webhook port (9443) during deployment.

**Implementation**:
- Postrenderer script: `platform/kustomize/eck-operator-postrender.sh`
- Kustomize patch: `platform/kustomize/eck-operator/statefulset-probes.yaml`
- Automatically applied during `helm install` via `postrender` block in Terraform

**Unique Service Selector Workaround**:
ECK creates multiple services (`elasticsearch-es-http`, `elasticsearch-es-transport`, `elasticsearch-es-internal-http`, `elasticsearch-es-default`) that can have overlapping selectors, violating AKS Automatic's `K8sAzureV1UniqueServiceSelector` policy. We use ECK's native service selector overrides to differentiate them:

- Pod labels: `elasticsearch.service/http: "true"` and `elasticsearch.service/transport: "true"` added to all ES pods
- HTTP service: configured via `spec.http.service.spec.selector` to require `elasticsearch.service/http: "true"`
- Transport service: configured via `spec.transport.service.spec.selector` to require `elasticsearch.service/transport: "true"`
- Internal-HTTP and Default services: use default selectors (automatically unique due to other label differences)

This is configured directly in the Elasticsearch CR in `platform/helm_elastic.tf` using ECK's documented service customization capabilities. See [ECK HTTP Service Settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-http-settings-tls-sans.html) and [ECK Transport Settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-transport-settings.html).

**Important**: When adding new nodeSets, each must include both `elasticsearch.service/http: "true"` and `elasticsearch.service/transport: "true"` labels in its podTemplate.

**Verification**: After ECK upgrades or configuration changes, verify all service selectors remain unique:
```bash
kubectl get svc -n elasticsearch -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.selector}{"\n"}{end}'
```

### Elastic Bootstrap

Post-deploy Job that configures index templates, ILM policies, and aliases required by OSDU services. It runs after Elasticsearch is healthy, uses the CIMPL elastic-bootstrap chart/image, and pulls credentials from the `elasticsearch-es-elastic-user` secret. The Job is AKS safeguards compliant and cleaned up via TTL.

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
- Operator: CNPG chart `cloudnative-pg` v0.27.1 (namespace: `platform`)
- Instances: 3 (synchronous quorum replication: `minSyncReplicas: 1, maxSyncReplicas: 1`)
- Replication slots: HA enabled
- Database: `osdu` (owner: `osdu`)
- Additional databases: `keycloak`, `airflow` (created via idempotent Job in `platform/k8s_cnpg_bootstrap.tf`, DDL in `platform/sql/*.sql.tftpl`)
- Storage: 8Gi data + 4Gi WAL per instance on `pg-storageclass` (Premium_LRS, Retain)
- Read-write: `postgresql-rw.postgresql.svc.cluster.local:5432`
- Read-only: `postgresql-ro.postgresql.svc.cluster.local:5432`
- Node affinity: `agentpool=stateful` with `workload=stateful:NoSchedule` toleration
- Zone topology: `DoNotSchedule` for zone spread, `ScheduleAnyway` for host spread
- Istio STRICT mTLS via `PeerAuthentication` in postgresql namespace

**CNPG Probe Exemption**: CNPG creates short-lived initdb/join Jobs that cannot have health probes. AKS Automatic's `K8sAzureV2ContainerEnforceProbes` policy blocks these Jobs. An Azure Policy Exemption (`azurerm_resource_policy_exemption.cnpg_probe_exemption`) is configured in `infra/aks.tf` to waive the probe requirement for CNPG Jobs.

### RabbitMQ

RabbitMQ cluster for async messaging (OSDU service broker).

**Configuration**:
- Deployment: Raw Kubernetes manifests (StatefulSet, Services, ConfigMap) — no Helm chart (see [ADR-0003](../decisions/0003-raw-manifests-for-rabbitmq.md))
- Image: `rabbitmq:4.1.0-management-alpine` (official upstream)
- Replicas: 3 (clustered via DNS peer discovery)
- Storage: 8Gi `rabbitmq-storageclass` (Premium_LRS, Retain)
- Connection: `rabbitmq.rabbitmq.svc.cluster.local:5672`
- Node affinity: `agentpool=stateful` with `workload=stateful:NoSchedule` toleration
- No Istio sidecar injection (NET_ADMIN blocked by AKS Automatic — see [ADR-0008](../decisions/0008-selective-istio-sidecar-injection.md))

### Apache Airflow

Workflow orchestration engine for DAG-based task scheduling, deployed using the official Apache Airflow Helm chart (see [ADR-0011](../decisions/0011-airflow-kubernetes-executor-with-nap.md)).

**Configuration**:
- Chart: `apache-airflow/airflow` v1.19.0 (official, from `https://airflow.apache.org`)
- Image: `apache/airflow:3.1.7`
- Executor: **KubernetesExecutor** (creates a pod per task, no persistent workers)
- Database: PostgreSQL (`airflow` DB via CNPG bootstrap job)
- Namespace: `airflow` (Istio STRICT mTLS)
- Node affinity: `agentpool=stateful` with `workload=stateful:NoSchedule` toleration

**Components** (all on stateful nodepool):

| Component | Replicas | Purpose |
|-----------|----------|---------|
| Webserver | 1 | Airflow UI |
| API Server | 1 | REST API (new in Airflow 3.x) |
| Scheduler | 1 | DAG parsing and task scheduling |
| Triggerer | 1 | Async deferred task execution |

**Task Pod Scaling via NAP**:

With KubernetesExecutor, each DAG task runs as an ephemeral pod. These task pods have no tolerations or nodeSelector, so they land on the **default** node pool where Karpenter NAP auto-provisions right-sized nodes on demand:

```
DAG task triggers
  → Scheduler creates task pod (no tolerations)
  → Pod goes Pending on default pool
  → NAP provisions a node sized for the task
  → Task runs → pod completes
  → Node consolidates after idle timeout
```

This provides **scale-to-zero for DAG execution** — compute cost is incurred only when tasks are running. For specialized workloads (e.g., GPU tasks), a custom Karpenter NodePool can be created and targeted via the KubernetesExecutor pod template.

### Keycloak

Identity provider for authentication and authorization, deployed using the Bitnami Helm chart with the official Keycloak image from `quay.io` (see [ADR-0012](../decisions/0012-bitnami-chart-with-official-keycloak-image.md)).

**Configuration**:
- Chart: `bitnamicharts/keycloak` v25.3.2 (Bitnami, OCI registry)
- Image: `quay.io/keycloak/keycloak:26.5.4` (official; Bitnami free images deprecated Aug 2025)
- Database: PostgreSQL (`keycloak` DB via CNPG bootstrap job)
- Namespace: `keycloak` (Istio STRICT mTLS)
- Internal-only: No HTTPRoute/Gateway exposure; access via `kubectl port-forward`
- OSDU realm auto-imported at startup via `--import-realm`
- Node affinity: `agentpool=stateful` with `workload=stateful:NoSchedule` toleration
- JWKS readiness gate: `null_resource.keycloak_jwks_wait` polls the OSDU realm JWKS endpoint before downstream services deploy

### MinIO

MinIO standalone instance for S3-compatible object storage (dev/test).

**Configuration**:
- Chart: `minio/minio` v5.4.0
- Mode: standalone (single pod)
- Storage: 10Gi managed-csi PVC
- API Port: 9000
- Console Port: 9001
- Connection: `minio.platform.svc.cluster.local:9000` (namespace: `platform`)
- Runs on default (auto-provisioned) node pool

### cert-manager

Automatic TLS certificate management with Let's Encrypt.

**Components**:
- cert-manager controller
- ClusterIssuer (Let's Encrypt production)
- HTTP-01 challenge solver (via Istio Gateway)

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

**Excluded Namespaces** (configured in `scripts/post-provision.ps1`):
- kube-system (Kubernetes system)
- gatekeeper-system (Policy controller)
- platform (Operators: cert-manager, CNPG, ECK, ExternalDNS, MinIO)
- elasticsearch (Elasticsearch/Kibana)
- aks-istio-ingress (Istio ingress)
- postgresql (Database)
- redis (Cache)

**Azure Policy Exemption**: CNPG operator Jobs (initdb, join) are short-lived and cannot have health probes. An Azure Policy Exemption for `ensureProbesConfiguredInKubernetesCluster` is applied at the cluster level in `infra/aks.tf`.

### Istio STRICT mTLS

The Elasticsearch (`elasticsearch`), PostgreSQL (`postgresql`), Redis (`redis`), Airflow (`airflow`), and Keycloak (`keycloak`) namespaces have Istio STRICT mTLS enforced via `PeerAuthentication` resources. Elasticsearch uses ECK self-signed TLS for HTTP transport in addition to mesh-layer encryption (see [ADR-0007](../decisions/0007-eck-self-signed-tls-for-elasticsearch.md)). RabbitMQ does **not** have Istio sidecar injection because AKS Automatic blocks the `NET_ADMIN` capability required by `istio-init` (see [ADR-0008](../decisions/0008-selective-istio-sidecar-injection.md)).

- Elasticsearch: `PeerAuthentication` managed in `platform/helm_elastic.tf` (+ ECK self-signed TLS)
- PostgreSQL: `PeerAuthentication` managed in `platform/helm_cnpg.tf`
- Redis: `PeerAuthentication` managed in `platform/helm_redis.tf`
- Airflow: `PeerAuthentication` managed in `platform/helm_airflow.tf`
- Keycloak: `PeerAuthentication` managed in `platform/helm_keycloak.tf`
- RabbitMQ: No Istio injection (ambient mode aspiration — see ADR-0008)

### Network Security

- **Azure CNI Overlay**: Pod IPs in overlay network
- **Cilium**: Network policy enforcement
- **Managed NAT Gateway**: Outbound traffic via dedicated NAT
- **Istio mTLS**: STRICT mode enforced for Elasticsearch, PostgreSQL, and Redis namespaces; PERMISSIVE (default) for other namespaces; RabbitMQ excluded (no sidecar injection)

---

## Data Flow

### External Traffic to Kibana

```
1. DNS: kibana.example.com ──► External IP (Azure LB)
2. Azure LB ──► Istio Ingress Gateway Pod (aks-istio-ingress ns)
3. Gateway ──► VirtualService routing rule
4. VirtualService ──► Kibana Service (elasticsearch ns)
5. Service ──► Kibana Pod
```

### Internal Service Communication

```
PostgreSQL Client (read-write):
  Pod ──► postgresql-rw.postgresql.svc.cluster.local:5432 ──► PG Primary

PostgreSQL Client (read-only):
  Pod ──► postgresql-ro.postgresql.svc.cluster.local:5432 ──► PG Replicas

MinIO Client:
  Pod ──► minio.platform.svc.cluster.local:9000 ──► MinIO Pod

Elasticsearch Client:
  Pod ──► elasticsearch-es-http.elasticsearch.svc.cluster.local:9200 ──► ES Pods

Airflow Webserver:
  Pod ──► airflow-webserver.airflow.svc.cluster.local:8080 ──► Webserver Pod

Keycloak (internal-only):
  Pod ──► keycloak.keycloak.svc.cluster.local:8080 ──► Keycloak Pod
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
│  │  terraform apply │ Layer 1: Create AKS cluster + node pools              │
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
│  │    2. terraform apply (platform/)                                    │   │
│  │    3. Verify component health                                        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why two phases?** Azure Policy/Gatekeeper is eventually consistent. Fresh clusters have a window where policies aren't fully reconciled. Making safeguards readiness an explicit gate eliminates the race condition.

### Terraform State

```
infra/
  └── terraform.tfstate    # Layer 1 state (AKS cluster)

platform/
  └── terraform.tfstate    # Layer 2 state (platform components)
```

---

## Monitoring & Observability

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| Azure Monitor Metrics | Enabled | AKS metrics to Azure Monitor |
| Prometheus Metrics | Disabled | Can be enabled per component |
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
| Node Pools | `system`, `stateful` | - |
| Namespaces | Descriptive | platform, elasticsearch, postgresql, redis, rabbitmq, airflow, keycloak |

### Tagging Strategy

All Azure resources include:
- `azd-env-name`: Environment name
- `project`: cimpl
- `Contact`: Owner email address

---

## Scaling Considerations

### Elasticsearch

- Horizontal: Add nodes to stateful pool (terraform variable)
- Vertical: Change VM size (requires node pool recreation)
- Storage: Expandable via PVC (allowVolumeExpansion: true)

### PostgreSQL

- Horizontal: Increase CNPG cluster `instances` count (add read replicas)
- Vertical: Adjust resource requests/limits in the Cluster CR
- Storage: Expandable via PVC (allowVolumeExpansion: true on pg-storageclass)
- Consider Azure Database for PostgreSQL Flexible Server for production

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

The stateful workload pool uses Karpenter (NAP) with dynamic SKU selection, so it is not affected by this issue.

---

## Known Limitations

1. **Single Region**: No multi-region deployment
2. **No HA for MinIO**: Single instance standalone deployment
3. **Manual DNS**: Requires external DNS configuration
4. **Local Terraform State**: Consider remote state for team use
5. **Safeguards Gate Timeout**: Phase 1 uses a behavioral gate that waits for Gatekeeper constraints to leave deny mode; if Azure Policy sync is slow, re-run `azd provision` to retry
6. **CNPG Policy Exemption**: Azure Policy Exemption for probe enforcement is required for CNPG Jobs; this is a cluster-wide waiver for the specific probe policy

See [Troubleshooting](../operations/troubleshooting.md) for common issues and workarounds.
