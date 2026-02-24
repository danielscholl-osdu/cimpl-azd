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
| `TF_VAR_airflow_db_password` | No | Airflow database password (auto-generated if not set) |
| `TF_VAR_minio_root_user` | No | MinIO root username (default: minioadmin) |
| `TF_VAR_minio_root_password` | No | MinIO root password (auto-generated if not set) |
| `TF_VAR_rabbitmq_username` | No | RabbitMQ username (default: rabbitmq) |
| `TF_VAR_rabbitmq_password` | No | RabbitMQ password (auto-generated if not set) |
| `TF_VAR_rabbitmq_erlang_cookie` | No | RabbitMQ Erlang cookie (auto-generated if not set) |
| `TF_VAR_cimpl_subscriber_private_key_id` | No | Subscriber private key identifier for OSDU services |
| `TF_VAR_cimpl_project` | No | CIMPL project/group identifier |
| `TF_VAR_cimpl_tenant` | No | CIMPL data partition ID (default: osdu) |
| `TF_VAR_enable_common` | No | Enable OSDU common namespace resources (default: true) |
| `AZURE_LOCATION` | No | Azure region (default: eastus2) |

## AKS Cluster Specifications

| Setting | Value |
|---------|-------|
| Kubernetes Version | 1.32 |
| SKU | Automatic (Standard tier) |
| Network Plugin | Azure CNI Overlay + Cilium |
| Service Mesh | Istio (asm-1-28) |
| System Nodes | 2x Standard_D4lds_v5 |
| Elastic Nodes | 3x Standard_D4as_v5 |

## Platform Components

| Component | Version | Storage |
|-----------|---------|---------|
| Elasticsearch | 8.15.2 | 3x 128Gi Premium SSD |
| Kibana | 8.15.2 | — |
| PostgreSQL (CNPG) | 17 | 3x 8Gi + 4Gi WAL |
| RabbitMQ | 4.1.0 | 3x 8Gi managed-csi-premium |
| MinIO | Latest | 10Gi managed-csi |
| cert-manager | 1.16.2 | — |

## Deployment Flow

The deployment uses a **two-phase approach** to handle Azure Policy/Gatekeeper eventual consistency:

```
azd up
  |
  +-- preprovision        -> Validate prerequisites
  +-- provision           -> Create AKS cluster (Layer 1)
  +-- postprovision       -> Two-phase deployment:
        |
        +-- Phase 1: ensure-safeguards.ps1
        |     +-- Configure safeguards (Warning mode)
        |     +-- Wait for Gatekeeper reconciliation (gate)
        |
        +-- Phase 2: deploy-platform.ps1
              +-- Deploy platform Terraform (Layer 2)
              +-- Verify component health
```

!!! info "Why Two Phases?"
    Azure Policy/Gatekeeper is eventually consistent. Fresh clusters have a window where policies aren't fully reconciled. The two-phase approach makes safeguards readiness an explicit gate, eliminating the race condition.

## Project Structure

```
cimpl-azd/
+-- azure.yaml                  # azd configuration
+-- .env.example                # Environment template
+-- infra/                      # Layer 1: Cluster Infrastructure
|   +-- main.tf                 # Resource group
|   +-- aks.tf                  # AKS Automatic cluster
|   +-- variables.tf            # Input variables
|   +-- outputs.tf              # Outputs for azd
|   +-- providers.tf            # Azure provider
|   +-- versions.tf             # Version constraints
+-- platform/                   # Layer 2: Platform Components
|   +-- main.tf                 # Data sources
|   +-- variables.tf            # Platform variables
|   +-- providers.tf            # K8s/Helm providers
|   +-- helm_cert_manager.tf    # cert-manager
|   +-- helm_elastic.tf         # ECK + Elasticsearch + Kibana
|   +-- helm_postgresql.tf      # PostgreSQL
|   +-- helm_minio.tf           # MinIO
|   +-- k8s_gateway.tf          # Gateway API config
+-- scripts/
|   +-- pre-provision.ps1       # Pre-deploy validation
|   +-- post-provision.ps1      # Orchestrator (calls Phase 1 + 2)
|   +-- ensure-safeguards.ps1   # Phase 1: Safeguards readiness
|   +-- deploy-platform.ps1     # Phase 2: Platform deployment
+-- docs/                       # Documentation (this site)
```
