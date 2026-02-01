# cimpl-azd Architecture

This document describes the architecture and design decisions for the CIMPL AKS deployment.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure Subscription                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Resource Group: rg-cimpl-<env>                      │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │  │
│  │  │                 AKS Automatic: cimpl-<env>                        │ │  │
│  │  │                                                                   │ │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │ │  │
│  │  │  │   System    │  │   Default   │  │       Elastic           │  │ │  │
│  │  │  │  Node Pool  │  │  Node Pool  │  │      Node Pool          │  │ │  │
│  │  │  │  (2 nodes)  │  │  (auto)     │  │      (3 nodes)          │  │ │  │
│  │  │  │             │  │             │  │                         │  │ │  │
│  │  │  │ - Istio     │  │ - MinIO     │  │ - Elasticsearch (3)     │  │ │  │
│  │  │  │ - CoreDNS   │  │ - PostgreSQL│  │ - Kibana (1)            │  │ │  │
│  │  │  │ - Gateway   │  │ - cert-mgr  │  │                         │  │ │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │ │  │
│  │  │                                                                   │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────────┐│ │  │
│  │  │  │                    Istio Service Mesh                        ││ │  │
│  │  │  │                                                               ││ │  │
│  │  │  │   Internet ──► Ingress Gateway ──► VirtualService ──► Pods   ││ │  │
│  │  │  │              (External LB)                                    ││ │  │
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
- Elastic node pool (tainted for ES)
- Istio service mesh (AKS-managed)
- Azure RBAC integration
- Workload Identity support
- Storage CSI drivers

**Terraform Resources**:
```
azurerm_resource_group.main
module.aks (Azure Verified Module)
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
- PostgreSQL (Bitnami Helm chart)
- MinIO (Bitnami Helm chart)
- Istio Gateway configuration
- Custom StorageClass for Elasticsearch

**Terraform Resources**:
```
helm_release.cert_manager
helm_release.elastic_operator
kubectl_manifest.elasticsearch
kubectl_manifest.kibana
helm_release.postgresql
helm_release.minio
kubectl_manifest.gateway
kubectl_manifest.http_route
```

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

| Pool | Purpose | VM Size | Count | Taints |
|------|---------|---------|-------|--------|
| system | Critical system components | Standard_D4lds_v5 | 2 | CriticalAddonsOnly |
| default | General workloads | Auto-provisioned | Auto | None |
| elastic | Elasticsearch cluster | Standard_D4as_v5 | 3 | app=elasticsearch:NoSchedule |

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
│                    Elasticsearch Cluster                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  ES Node 1   │  │  ES Node 2   │  │  ES Node 3   │          │
│  │  (master+    │  │  (master+    │  │  (master+    │          │
│  │   data+      │  │   data+      │  │   data+      │          │
│  │   ingest)    │  │   ingest)    │  │   ingest)    │          │
│  │              │  │              │  │              │          │
│  │  128Gi SSD   │  │  128Gi SSD   │  │  128Gi SSD   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                  │                  │
│         └──────────────────┼──────────────────┘                  │
│                            │                                     │
│              ┌─────────────┴─────────────┐                      │
│              │    Elasticsearch Service   │                      │
│              │    (ClusterIP:9200)        │                      │
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
kubectl get svc -n elastic-search -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.selector}{"\n"}{end}'
```

### PostgreSQL

Bitnami PostgreSQL chart deployed in standalone mode.

**Configuration**:
- Image: `public.ecr.aws/bitnami/postgresql:18`
- Storage: 8Gi managed-csi PVC
- Database: `osdu`
- Connection: `postgresql.postgresql.svc.cluster.local:5432`

### MinIO

Bitnami MinIO chart for S3-compatible object storage.

**Configuration**:
- Storage: 10Gi managed-csi PVC
- API Port: 9000
- Console Port: 9001
- Connection: `minio.minio.svc.cluster.local:9000`

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
│                    Azure Active Directory                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   User Authentication                     │  │
│  │                                                           │  │
│  │  User ──► az login ──► AAD ──► kubelogin ──► K8s API     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Workload Identity                        │  │
│  │                                                           │  │
│  │  Pod ──► Service Account ──► Federated Credential ──► AAD │  │
│  └──────────────────────────────────────────────────────────┘  │
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

**Mode**: Warning (violations logged, not blocked)

**Excluded Namespaces** (configured in `scripts/post-provision.ps1`):
- kube-system (Kubernetes system)
- gatekeeper-system (Policy controller)
- elastic-system (ECK operator)
- elastic-search (Elasticsearch/Kibana)
- cert-manager (TLS certificates)
- aks-istio-ingress (Istio ingress)
- postgresql (Database)
- minio (Object storage)

### Network Security

- **Azure CNI Overlay**: Pod IPs in overlay network
- **Cilium**: Network policy enforcement
- **Managed NAT Gateway**: Outbound traffic via dedicated NAT
- **Istio mTLS**: Service-to-service encryption (optional)

---

## Data Flow

### External Traffic to Kibana

```
1. DNS: kibana.example.com ──► External IP (Azure LB)
2. Azure LB ──► Istio Ingress Gateway Pod (aks-istio-ingress ns)
3. Gateway ──► VirtualService routing rule
4. VirtualService ──► Kibana Service (elastic-search ns)
5. Service ──► Kibana Pod
```

### Internal Service Communication

```
PostgreSQL Client:
  Pod ──► postgresql.postgresql.svc.cluster.local:5432 ──► PostgreSQL Pod

MinIO Client:
  Pod ──► minio.minio.svc.cluster.local:9000 ──► MinIO Pod

Elasticsearch Client:
  Pod ──► elasticsearch-es-http.elastic-search.svc.cluster.local:9200 ──► ES Pods
```

---

## Deployment Flow

### azd up Sequence (Two-Phase)

The deployment uses a two-phase approach to handle Azure Policy/Gatekeeper eventual consistency:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              azd up                                          │
│                                                                              │
│  ┌──────────────────┐                                                       │
│  │  pre-provision   │ Validate prerequisites (az cli, kubectl, etc.)        │
│  └────────┬─────────┘                                                       │
│           │                                                                  │
│           ▼                                                                  │
│  ┌──────────────────┐                                                       │
│  │  terraform apply │ Layer 1: Create AKS cluster + node pools              │
│  │  (infra/)        │ Output: cluster_name, resource_group, oidc_issuer     │
│  └────────┬─────────┘                                                       │
│           │                                                                  │
│           ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  post-provision (orchestrator)                                        │  │
│  │                                                                       │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │  Phase 1: ensure-safeguards.ps1  [GATE]                        │  │  │
│  │  │    1. Configure kubeconfig                                      │  │  │
│  │  │    2. Configure AKS safeguards (Warning mode)                   │  │  │
│  │  │    3. Wait for Gatekeeper controller ready                      │  │  │
│  │  │    4. Wait for ALL constraints to leave deny mode               │  │  │
│  │  │    5. EXIT with error if not ready (fail fast)                  │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  │                              │                                        │  │
│  │                     (only if Phase 1 succeeds)                        │  │
│  │                              ▼                                        │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │  Phase 2: deploy-platform.ps1                                  │  │  │
│  │  │    1. Verify cluster access                                     │  │  │
│  │  │    2. terraform apply (platform/)                               │  │  │
│  │  │    3. Verify component health                                   │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
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
| Node Pools | `system`, `elastic` | - |
| Namespaces | Descriptive | elastic-search, postgresql |

### Tagging Strategy

All Azure resources include:
- `azd-env-name`: Environment name
- `project`: cimpl
- `Contact`: Owner email address

---

## Scaling Considerations

### Elasticsearch

- Horizontal: Add nodes to elastic pool (terraform variable)
- Vertical: Change VM size (requires node pool recreation)
- Storage: Expandable via PVC (allowVolumeExpansion: true)

### PostgreSQL / MinIO

- Currently single-instance
- Consider managed services (Azure Database for PostgreSQL, Azure Blob) for production

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
| MinIO | Objects | Already S3-compatible |

### Recovery Strategy

1. **RTO** (Recovery Time Objective): 4 hours
2. **RPO** (Recovery Point Objective): 24 hours
3. **Strategy**: Redeploy infrastructure, restore data from backups

### PVC Retention

- Elasticsearch uses `reclaimPolicy: Retain`
- Data persists even if pods are deleted
- Manual cleanup required after intentional deletion

---

## Known Limitations

1. **Single Region**: No multi-region deployment
2. **No HA for PostgreSQL/MinIO**: Single instance deployments
3. **Manual DNS**: Requires external DNS configuration
4. **Local Terraform State**: Consider remote state for team use
5. **Safeguards Gate Timeout**: Phase 1 waits up to 5 minutes for Gatekeeper; if Azure Policy is slow, may need manual retry

See [notes.md](../notes.md) for detailed issue tracking.
