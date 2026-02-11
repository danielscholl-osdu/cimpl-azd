# cimpl-azd

Azure Developer CLI (azd) deployment for CIMPL on AKS Automatic.

## Overview

This project deploys a complete platform stack on Azure Kubernetes Service (AKS) Automatic, including:

- **AKS Automatic** - Managed Kubernetes with auto-scaling and built-in Istio
- **Elasticsearch** - Search and analytics engine (3-node cluster)
- **Kibana** - Elasticsearch visualization
- **PostgreSQL** - Relational database
- **MinIO** - S3-compatible object storage
- **cert-manager** - Automatic TLS certificate management
- **Istio Service Mesh** - Traffic management and security (AKS-managed)

## Architecture

The deployment uses a **three-layer architecture**:

```
Layer 1: Cluster Infrastructure (infra/)
    └─ AKS Automatic cluster with node pools
    └─ Azure RBAC and Workload Identity
    └─ Istio service mesh (built-in)

Layer 2: Platform Components (platform/)
    └─ cert-manager + ClusterIssuer
    └─ ECK Operator + Elasticsearch + Kibana
    └─ PostgreSQL (Bitnami chart)
    └─ MinIO (official chart)
    └─ Gateway API configuration

Layer 3: Services (services/) [Future]
    └─ OSDU platform services
    └─ Custom applications
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (v1.5+)
- [Terraform](https://www.terraform.io/downloads) (v1.5+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kubelogin](https://github.com/Azure/kubelogin) (for Azure AD authentication)
- [Helm](https://helm.sh/docs/intro/install/) (v3.12+)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) (for ECK operator probe injection)
- PowerShell Core (for deployment scripts)

## Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd cimpl-azd

# Create environment configuration
azd env new dev
```

### 2. Set Required Environment Variables

```bash
# Required: Your contact email (for resource tagging)
azd env set AZURE_CONTACT_EMAIL "your-email@example.com"

# Required: ACME email for Let's Encrypt certificates
azd env set TF_VAR_acme_email "your-email@example.com"

# Required: Hostname for Kibana external access
azd env set TF_VAR_kibana_hostname "kibana.yourdomain.com"

# Optional: Azure region (default: eastus2)
azd env set AZURE_LOCATION "eastus2"
```

### 3. Deploy

```bash
# Authenticate
az login
azd auth login

# Deploy everything
azd up
```

This will:
1. Run pre-provision validation
2. Create AKS Automatic cluster (Layer 1)
3. Configure kubeconfig and AKS safeguards
4. Deploy platform components (Layer 2)
5. Verify deployment health

### 4. Access Services

After deployment:

```bash
# Get external IP
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external

# Get Elasticsearch password
kubectl get secret elasticsearch-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d
```

Configure DNS to point your Kibana hostname to the external IP, then access:
- **Kibana**: `https://<kibana-hostname>`

## Multi-User Support

The deployment supports multiple instances through environment naming:

```bash
# User A creates their environment
azd env new dev-alice
azd env set AZURE_CONTACT_EMAIL "alice@example.com"
# Creates: rg-cimpl-dev-alice, cimpl-dev-alice

# User B creates their environment
azd env new dev-bob
azd env set AZURE_CONTACT_EMAIL "bob@example.com"
# Creates: rg-cimpl-dev-bob, cimpl-dev-bob
```

All Azure resources are tagged with `Contact: <email>` for owner identification.

## Destroy

```bash
# Tear down all resources
azd down --force --purge
```

## Deployment Flow

The deployment uses a **two-phase approach** to handle Azure Policy/Gatekeeper eventual consistency:

```
azd up
  │
  ├── preprovision        → Validate prerequisites
  ├── provision           → Create AKS cluster (Layer 1)
  └── postprovision       → Two-phase deployment:
        │
        ├── Phase 1: ensure-safeguards.ps1
        │     ├── Configure safeguards (Warning mode)
        │     └── Wait for Gatekeeper reconciliation (gate)
        │
        └── Phase 2: deploy-platform.ps1
              ├── Deploy platform Terraform (Layer 2)
              └── Verify component health
```

**Why two phases?** Azure Policy/Gatekeeper is eventually consistent. Fresh clusters have a window where policies aren't fully reconciled. The two-phase approach makes safeguards readiness an explicit gate, eliminating the race condition.

## Project Structure

```
cimpl-azd/
├── azure.yaml                  # azd configuration
├── .env.example                # Environment template
├── notes.md                    # Development notes and known issues
├── infra/                      # Layer 1: Cluster Infrastructure
│   ├── main.tf                 # Resource group
│   ├── aks.tf                  # AKS Automatic cluster
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Outputs for azd
│   ├── providers.tf            # Azure provider
│   └── versions.tf             # Version constraints
├── platform/                   # Layer 2: Platform Components
│   ├── main.tf                 # Data sources
│   ├── variables.tf            # Platform variables
│   ├── providers.tf            # K8s/Helm providers
│   ├── versions.tf             # Version constraints
│   ├── helm_cert_manager.tf    # cert-manager
│   ├── helm_elastic.tf         # ECK + Elasticsearch + Kibana
│   ├── helm_postgresql.tf      # PostgreSQL
│   ├── helm_minio.tf           # MinIO
│   └── k8s_gateway.tf          # Gateway API config
├── scripts/
│   ├── pre-provision.ps1       # Pre-deploy validation
│   ├── post-provision.ps1      # Orchestrator (calls Phase 1 + 2)
│   ├── ensure-safeguards.ps1   # Phase 1: Safeguards readiness
│   └── deploy-platform.ps1     # Phase 2: Platform deployment
└── docs/
    └── architecture.md         # Detailed architecture
```

## Configuration Reference

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_CONTACT_EMAIL` | Yes | Contact email for resource tagging |
| `TF_VAR_acme_email` | Yes | Email for Let's Encrypt certificates |
| `TF_VAR_kibana_hostname` | Yes | Hostname for Kibana external access |
| `TF_VAR_postgresql_password` | No | PostgreSQL admin password (auto-generated if not set) |
| `TF_VAR_minio_root_user` | No | MinIO root username (default: minioadmin) |
| `TF_VAR_minio_root_password` | No | MinIO root password (auto-generated if not set) |
| `AZURE_LOCATION` | No | Azure region (default: eastus2) |

### AKS Cluster Specifications

| Setting | Value |
|---------|-------|
| Kubernetes Version | 1.32 |
| SKU | Automatic (Standard tier) |
| Network Plugin | Azure CNI Overlay + Cilium |
| Service Mesh | Istio (asm-1-28) |
| System Nodes | 2x Standard_D4lds_v5 |
| Elastic Nodes | 3x Standard_D4as_v5 |

### Platform Components

| Component | Version | Storage |
|-----------|---------|---------|
| Elasticsearch | 8.15.2 | 3x 128Gi Premium SSD |
| Kibana | 8.15.2 | - |
| PostgreSQL | 18.x | 8Gi managed-csi |
| MinIO | Latest | 10Gi managed-csi |
| cert-manager | 1.16.2 | - |

## Troubleshooting

### Common Issues

1. **Safeguards blocking deployments**: The two-phase behavioral gate in post-provision handles Gatekeeper reconciliation automatically. If it times out, re-run `azd provision` to retry the gate and platform deployment
2. **RBAC permission denied**: Grant "Azure Kubernetes Service RBAC Cluster Admin" role to your user
3. **Helm timeout**: Increase timeout or verify node pool capacity

See [notes.md](notes.md) for detailed issue tracking and workarounds.

### Useful Commands

```bash
# Verify cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check component status
kubectl get elasticsearch -n elasticsearch
kubectl get pods -n postgresql
kubectl get pods -n platform -l 'minio.service/variant=api'

# View safeguards violations
kubectl get constraints -o wide

# Manual platform deployment
cd platform && terraform apply
```

## Contributing

See [notes.md](notes.md) for the current backlog and improvement areas.

## License

[Add license information]
