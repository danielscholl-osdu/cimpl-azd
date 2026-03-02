# Platform Components

The platform layer deploys all middleware into the `platform` namespace. These components provide the data, messaging, identity, and networking foundation that OSDU services depend on.

![Platform Architecture](../images/platform-architecture.png)

## Component Summary

| Component | Version | Storage | Enable Flag |
|-----------|---------|---------|-------------|
| Elasticsearch | 8.15.2 | 3x 128Gi Premium SSD | `enable_elasticsearch` |
| Kibana | 8.15.2 | — | (with Elasticsearch) |
| PostgreSQL (CNPG) | 17 | 3x 8Gi + 4Gi WAL | `enable_postgresql` |
| RabbitMQ | 4.1.0 | 3x 8Gi Premium SSD | `enable_rabbitmq` |
| Redis | 8.2.1 (Bitnami chart 24.1.3) | 1x master 8Gi + 2x replica 8Gi | `enable_redis` |
| MinIO | RELEASE.2024-12-18 (chart 5.4.0) | 10Gi managed-csi | `enable_minio` |
| Keycloak | 26.5.4 | — (uses PostgreSQL) | `enable_keycloak` |
| Airflow | chart 1.19.0 | — (uses PostgreSQL) | `enable_airflow` |

!!! info "Foundation-layer components"
    cert-manager (v1.19.3), ECK operator (v3.3.0), and CNPG operator (v0.27.1) are deployed in the **foundation** layer (`software/foundation/`), not the stack. They are cluster-wide singletons shared across all stacks. See [Design Overview](overview.md) for the three-layer model.

All components default to enabled except Airflow. See [Feature Flags](../getting-started/feature-flags.md) for the complete list.

---

## Elasticsearch Cluster

**Architecture:** 3-node cluster with combined master/data/ingest roles, managed by the ECK operator (v3.3.0, deployed in the foundation layer).

**Storage:** Custom StorageClass with Premium LRS and Retain policy:

```yaml
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

**Internal endpoint:** `elasticsearch-es-http.platform.svc.cluster.local:9200`

**Probe workaround:** The ECK Helm chart does not expose probe configuration. A Helm postrenderer injects tcpSocket probes on the webhook port (9443) during deployment (see [ADR-0002](../decisions/0002-helm-postrender-kustomize-for-safeguards.md)).

**Selector workaround:** ECK creates services with overlapping selectors, violating AKS `K8sAzureV1UniqueServiceSelector`. ECK's native service selector overrides differentiate them (see [ADR-0010](../decisions/0010-unique-service-selector-label-pattern.md)).

### Elastic Bootstrap

Post-deploy Job that configures index templates, ILM policies, and aliases required by OSDU services. Runs after Elasticsearch is healthy and pulls credentials from the `elasticsearch-es-elastic-user` secret.

### Kibana

Single-replica deployment with external access via Gateway API:

```
Internet → Istio Ingress Gateway → HTTPRoute → Kibana Service → Pod
                                      │
                               cert-manager TLS
```

---

## PostgreSQL (CloudNativePG)

3-instance HA PostgreSQL cluster managed by the CNPG operator with synchronous replication.

**Architecture:** 1 primary (read-write) + 2 sync replicas (read-only), spread across 3 availability zones.

**Configuration:**

| Setting | Value |
|---------|-------|
| Operator | CNPG chart `cloudnative-pg` v0.27.1 |
| Instances | 3 (synchronous quorum: `minSyncReplicas: 1, maxSyncReplicas: 1`) |
| Databases | 14 separate databases (one per OSDU service), matching ROSA topology |
| Storage | 8Gi data + 4Gi WAL per instance on `pg-storageclass` (Premium_LRS, Retain) |
| Read-write | `postgresql-rw.platform.svc.cluster.local:5432` |
| Read-only | `postgresql-ro.platform.svc.cluster.local:5432` |

**CNPG probe exemption:** CNPG creates short-lived initdb/join Jobs that cannot have health probes. An Azure Policy Exemption is configured in `infra/aks.tf` (see [ADR-0005](../decisions/0005-two-phase-deployment-gate.md)).

See [ADR-0014](../decisions/0014-rosa-alignment-and-deliberate-differences.md) for the ROSA-aligned database model.

---

## Redis

Bitnami Redis chart providing an in-memory cache layer for OSDU services (primarily Entitlements).

**Internal endpoint:** `redis-master.platform.svc.cluster.local:6379`

---

## RabbitMQ

RabbitMQ cluster for async messaging between OSDU services.

**Configuration:**

| Setting | Value |
|---------|-------|
| Deployment | Raw Kubernetes manifests (StatefulSet, Services, ConfigMap) |
| Image | `rabbitmq:4.1.0-management-alpine` |
| Replicas | 3 (clustered via DNS peer discovery) |
| Storage | 8Gi per node on `rabbitmq-storageclass` (Premium_LRS, Retain) |

**Internal endpoint:** `rabbitmq.platform.svc.cluster.local:5672`

No Helm chart is used — see [ADR-0003](../decisions/0003-raw-manifests-for-rabbitmq.md) for the rationale.

---

## Keycloak

Identity provider for OSDU authentication and authorization, deployed as raw Kubernetes manifests (see [ADR-0016](../decisions/0016-raw-manifests-for-keycloak.md)).

**Configuration:**

| Setting | Value |
|---------|-------|
| Image | `quay.io/keycloak/keycloak:26.5.4` |
| Deployment | Raw StatefulSet |
| Database | PostgreSQL (`keycloak` DB via CNPG bootstrap) |
| OSDU realm | Auto-imported at startup with `datafier` confidential client |

**Access:** Internal-only (no HTTPRoute). Use `kubectl port-forward` to reach the admin console.

**JWKS readiness gate:** A `null_resource.keycloak_jwks_wait` ensures Keycloak is issuing valid tokens before OSDU services deploy.

---

## Apache Airflow

Workflow orchestration for DAG-based task scheduling (see [ADR-0011](../decisions/0011-airflow-kubernetes-executor-with-nap.md)).

**Configuration:**

| Setting | Value |
|---------|-------|
| Chart | `apache-airflow/airflow` v1.19.0 |
| Image | `apache/airflow:3.1.7` |
| Executor | KubernetesExecutor (pod per task, no persistent workers) |
| Database | PostgreSQL (`airflow` DB via CNPG bootstrap) |

Control-plane components run on the `platform` nodepool; task pods run on the default pool (scale-to-zero).

!!! note
    Airflow defaults to disabled (`enable_airflow = false`) as it is not yet integrated with OSDU DAGs.

---

## MinIO

S3-compatible object storage for development and testing.

**Configuration:**

| Setting | Value |
|---------|-------|
| Chart | `minio/minio` v5.4.0 |
| Mode | Standalone (single pod) |
| Storage | 10Gi managed-csi PVC |

**Internal endpoints:**

- API: `minio.platform.svc.cluster.local:9000`
- Console: `minio.platform.svc.cluster.local:9001`

---

## cert-manager

Automatic TLS certificate management with Let's Encrypt. Deployed in the **foundation** layer.

- cert-manager v1.19.3 (with Gateway API support enabled)
- ClusterIssuer (Let's Encrypt production and staging)
- HTTP-01 challenge solver via Istio Gateway

---

## Gateway API

Modern ingress routing using Kubernetes Gateway API with Istio as the implementation.

- External Istio ingress gateway with Azure Load Balancer
- HTTPRoute resources for service-specific routing
- Automatic TLS via cert-manager Certificates
- Public or internal ingress controlled by `enable_public_ingress` flag

---

## AKS Safeguards Compliance

AKS Automatic enforces Gatekeeper policies at admission. All Helm charts must produce compliant manifests. The shared Kustomize postrender framework in `software/stack/kustomize/` patches charts to add:

- Health probes (readiness/liveness) with appropriate `initialDelaySeconds`
- Resource requests and limits
- Seccomp profiles (`RuntimeDefault`)
- Security context hardening (`runAsNonRoot`, `drop ALL` capabilities)
- Unique service selectors

See [ADR-0002](../decisions/0002-helm-postrender-kustomize-for-safeguards.md) for the postrender approach.

---

## Security

### Istio mTLS

Both namespaces have Istio sidecar injection enabled with STRICT mTLS:

- **`platform` namespace:** `istio-injection: enabled` with STRICT `PeerAuthentication`. Specific pods that require `NET_ADMIN` capabilities opt out at the pod level (e.g., RabbitMQ uses `sidecar.istio.io/inject: "false"`).
- **`osdu` namespace:** STRICT mTLS via `PeerAuthentication`, full sidecar injection.

Elasticsearch additionally uses ECK self-signed TLS for transport-layer encryption (see [ADR-0007](../decisions/0007-eck-self-signed-tls-for-elasticsearch.md)). See [ADR-0008](../decisions/0008-selective-istio-sidecar-injection.md) for the selective injection strategy.

### Pod Security

All workloads comply with AKS deployment safeguards:

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- Seccomp profile: `RuntimeDefault`
- Capabilities: drop `ALL`
