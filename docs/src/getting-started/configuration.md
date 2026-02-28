# Configuration Reference

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_CONTACT_EMAIL` | Yes | Contact email for resource tagging |
| `TF_VAR_acme_email` | Yes | Email for Let's Encrypt certificates |
| `TF_VAR_dns_zone_name` | Yes | Azure DNS zone name (e.g., `yourdomain.com`) |
| `TF_VAR_dns_zone_resource_group` | Yes | Resource group containing the DNS zone |
| `TF_VAR_dns_zone_subscription_id` | Yes | Subscription ID containing the DNS zone |
| `CIMPL_INGRESS_PREFIX` | No | Ingress hostname prefix (auto-generated if not set) |
| `TF_VAR_postgresql_password` | No | PostgreSQL admin password (auto-generated if not set) |
| `TF_VAR_keycloak_db_password` | No | Keycloak database password (auto-generated if not set) |
| `TF_VAR_keycloak_admin_password` | No | Keycloak admin console password (auto-generated if not set) |
| `TF_VAR_airflow_db_password` | No | Airflow database password (auto-generated if not set) |
| `TF_VAR_minio_root_user` | No | MinIO root username (default: minioadmin) |
| `TF_VAR_minio_root_password` | No | MinIO root password (auto-generated if not set) |
| `TF_VAR_rabbitmq_username` | No | RabbitMQ username (default: rabbitmq) |
| `TF_VAR_rabbitmq_password` | No | RabbitMQ password (auto-generated if not set) |
| `TF_VAR_rabbitmq_erlang_cookie` | No | RabbitMQ Erlang cookie (auto-generated if not set) |
| `TF_VAR_redis_password` | No | Redis authentication password (auto-generated if not set) |
| `TF_VAR_datafier_client_secret` | No | Keycloak client secret for entitlements datafier service account (auto-generated if not set) |
| `TF_VAR_cimpl_subscriber_private_key_id` | No | Subscriber private key identifier for OSDU services |
| `TF_VAR_cimpl_project` | No | CIMPL project/group identifier |
| `TF_VAR_cimpl_tenant` | No | CIMPL data partition ID (default: osdu) |
| `AZURE_LOCATION` | No | Azure region (default: eastus2) |

!!! note "Feature flags"
    All middleware and OSDU services default to **enabled**. You only need to set `TF_VAR_enable_<component>=false` to disable something. This keeps the environment file clean as more services are added.

!!! warning "Security note"
    Public ingress exposes the Istio gateway to the internet. Set `TF_VAR_enable_public_ingress=false` to use an internal LoadBalancer limited to the VNet.

## AKS Cluster Specifications

| Setting | Value |
|---------|-------|
| Kubernetes Version | 1.32 |
| SKU | Automatic (Standard tier) |
| Network Plugin | Azure CNI Overlay + Cilium |
| Service Mesh | Istio (asm-1-28) |
| System Nodes | 2x Standard_D4lds_v5 |
| Platform Nodes | D-series (4-8 vCPU), auto-provisioned via Karpenter NAP |

## Platform Components

| Component | Version | Storage | Enable Flag |
|-----------|---------|---------|-------------|
| Elasticsearch | 8.15.2 | 3x 128Gi Premium SSD | `enable_elasticsearch` (default: true) |
| Kibana | 8.15.2 | — | (with Elasticsearch) |
| PostgreSQL (CNPG) | 17 | 3x 8Gi + 4Gi WAL | `enable_postgresql` (default: true) |
| RabbitMQ | 4.1.0 | 3x 8Gi managed-csi-premium | `enable_rabbitmq` (default: true) |
| Redis | latest | — | `enable_redis` (default: true) |
| MinIO | Latest | 10Gi managed-csi | `enable_minio` (default: true) |
| cert-manager | 1.16.2 | — | `enable_cert_manager` (default: true) |
| Keycloak | 26.5.4 | — (uses PostgreSQL) | `enable_keycloak` (default: true) |
| Airflow | 3.1.7 | — (uses PostgreSQL) | `enable_airflow` (default: false) |

## OSDU Services

| Service | Chart Version | Dependencies | Enable Flag |
|---------|---------------|-------------|-------------|
| Partition | `0.0.7-latest` | PostgreSQL | `enable_partition` (default: true) |
| Entitlements | `0.0.7-latest` | Keycloak, Partition, PostgreSQL, Redis | `enable_entitlements` (default: true) |

## Deployment Flow

The deployment uses a **two-phase approach** to handle Azure Policy/Gatekeeper eventual consistency:

```
azd up
  |
  +-- preprovision        -> Validate prerequisites
  +-- provision           -> Create AKS cluster (Layer 1)
  +-- postprovision       -> Ensure safeguards readiness (gate)
  |     +-- Configure safeguards (Warning mode)
  |     +-- Wait for Gatekeeper reconciliation
  |
  +-- predeploy           -> Deploy software stack (Layer 2)
        +-- pre-deploy.ps1 (software/stack/ Terraform)
        +-- Middleware + OSDU services in dependency order
        +-- Verify component health
```

!!! info "Why Two Phases?"
    Azure Policy/Gatekeeper is eventually consistent. Fresh clusters have a window where policies aren't fully reconciled. The two-phase approach makes safeguards readiness an explicit gate, eliminating the race condition.

## Project Structure

```
cimpl-azd/
+-- azure.yaml                       # azd configuration
+-- infra/                           # Layer 1: Cluster Infrastructure
|   +-- main.tf                      # Resource group
|   +-- aks.tf                       # AKS Automatic cluster
|   +-- variables.tf                 # Input variables
|   +-- outputs.tf                   # Outputs for azd
+-- software/stack/                  # Layer 2: Middleware + OSDU Services
|   +-- main.tf                      # Namespace locals, Karpenter, module calls
|   +-- osdu.tf                      # OSDU service module calls
|   +-- variables.tf                 # Feature flags, credentials, config
|   +-- outputs.tf                   # Stack outputs (hosts, URLs)
|   +-- charts/                      # Per-component Terraform modules
|   |   +-- elastic/                 # ECK + Elasticsearch + Kibana
|   |   +-- postgresql/              # CNPG + PostgreSQL + SQL DDL
|   |   +-- redis/                   # Redis cache
|   |   +-- rabbitmq/                # RabbitMQ (raw manifests)
|   |   +-- minio/                   # MinIO object storage
|   |   +-- keycloak/                # Keycloak (raw manifests)
|   |   +-- airflow/                 # Apache Airflow
|   |   +-- gateway/                 # Gateway API + TLS
|   |   +-- osdu-common/             # OSDU namespace + shared secrets
|   +-- modules/
|   |   +-- osdu-service/            # Reusable OSDU Helm wrapper
|   +-- kustomize/                   # Postrender patches per service
+-- scripts/
|   +-- pre-provision.ps1            # Pre-provision validation & env defaults
|   +-- post-provision.ps1           # Post-provision: safeguards readiness
|   +-- pre-deploy.ps1               # Pre-deploy: stack Terraform apply
+-- docs/                            # Documentation (this site)
```
