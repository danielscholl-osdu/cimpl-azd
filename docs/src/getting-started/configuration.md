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

All OSDU services use the reusable `modules/osdu-service` wrapper and default to chart version `0.0.7-latest` (override per-service via `osdu_service_versions` map).

**Core Services** (`osdu-services-core.tf`):

| Service | Dependencies | Enable Flag |
|---------|-------------|-------------|
| Partition | PostgreSQL | `enable_partition` (default: true) |
| Entitlements | Keycloak, Partition, PostgreSQL | `enable_entitlements` (default: true) |
| Legal | Entitlements, Partition, PostgreSQL | `enable_legal` (default: true) |
| Schema | Entitlements, Partition, PostgreSQL | `enable_schema` (default: true) |
| Storage | Legal, Entitlements, Partition, PostgreSQL | `enable_storage` (default: true) |
| Search | Entitlements, Partition, Elasticsearch | `enable_search` (default: true) |
| Indexer | Entitlements, Partition, Elasticsearch | `enable_indexer` (default: true) |
| File | Legal, Entitlements, Partition, PostgreSQL | `enable_file` (default: true) |
| Notification | Entitlements, Partition, RabbitMQ | `enable_notification` (default: true) |
| Dataset | Entitlements, Partition, Storage, PostgreSQL | `enable_dataset` (default: true) |
| Register | Entitlements, Partition, PostgreSQL | `enable_register` (default: true) |
| Policy | Entitlements, Partition | `enable_policy` (default: true) |
| Secret | Entitlements, Partition | `enable_secret` (default: true) |
| Workflow | Entitlements, Partition, Storage, PostgreSQL, Airflow | `enable_workflow` (default: false) |

**Reference Systems** (`osdu-services-reference.tf`):

| Service | Dependencies | Enable Flag |
|---------|-------------|-------------|
| CRS Conversion | Entitlements, Partition | `enable_crs_conversion` (default: false) |
| CRS Catalog | Entitlements, Partition | `enable_crs_catalog` (default: false) |
| Unit | Entitlements, Partition | `enable_unit` (default: false) |

**Domain + External Data** (`osdu-services-domain.tf`):

| Service | Dependencies | Enable Flag |
|---------|-------------|-------------|
| Wellbore | Entitlements, Partition, Storage, PostgreSQL | `enable_wellbore` (default: false) |
| Wellbore Worker | Entitlements, Partition, Wellbore | `enable_wellbore_worker` (default: false) |
| EDS-DMS | Entitlements, Partition, Storage | `enable_eds_dms` (default: false) |

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
|   +-- locals.tf                    # Naming derivation, FQDNs, hostnames
|   +-- platform.tf                  # Platform namespace, Istio mTLS, Karpenter
|   +-- middleware.tf                # 8 middleware module calls
|   +-- osdu-common.tf              # OSDU common resources module call
|   +-- osdu-services-core.tf       # Core OSDU services (14)
|   +-- osdu-services-reference.tf  # Reference systems (3)
|   +-- osdu-services-domain.tf     # Domain + external data services (3)
|   +-- variables-flags.tf          # enable_* feature flags
|   +-- variables-infra.tf          # Infrastructure variables
|   +-- variables-credentials.tf    # Sensitive credential variables
|   +-- variables-osdu.tf           # OSDU project/tenant/version config
|   +-- outputs.tf                   # Stack outputs (hosts, URLs)
|   +-- modules/                     # Child Terraform modules
|   |   +-- elastic/                 # ECK + Elasticsearch + Kibana
|   |   +-- postgresql/              # CNPG + PostgreSQL + SQL DDL
|   |   +-- redis/                   # Redis cache
|   |   +-- rabbitmq/                # RabbitMQ (raw manifests)
|   |   +-- minio/                   # MinIO object storage
|   |   +-- keycloak/                # Keycloak (raw manifests)
|   |   +-- airflow/                 # Apache Airflow
|   |   +-- gateway/                 # Gateway API + TLS
|   |   +-- osdu-common/             # OSDU namespace + shared secrets
|   |   +-- osdu-service/            # Reusable OSDU Helm wrapper
|   +-- kustomize/                   # Postrender patches per service
+-- scripts/
|   +-- pre-provision.ps1            # Pre-provision validation & env defaults
|   +-- post-provision.ps1           # Post-provision: safeguards readiness
|   +-- pre-deploy.ps1               # Pre-deploy: stack Terraform apply
+-- docs/                            # Documentation (this site)
```
