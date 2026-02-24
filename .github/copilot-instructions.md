# Copilot Instructions for cimpl-azd

## Repository Overview

This repository deploys a complete platform stack on **Azure Kubernetes Service (AKS) Automatic** using Azure Developer CLI (azd) and Terraform. It uses a three-layer architecture for deploying Elasticsearch, Kibana, PostgreSQL, MinIO, cert-manager, and Istio service mesh on Kubernetes.

**Key Facts:**
- **Project Type:** Infrastructure as Code (IaC) deployment using Azure Developer CLI (azd)
- **Languages:** Terraform (HCL), PowerShell
- **Target Platform:** Azure Kubernetes Service (AKS) Automatic
- **Repository Size:** ~20 Terraform and PowerShell files
- **Deployment Tool:** azd (Azure Developer CLI) v1.5+

## Build and Validation Commands

### Prerequisites Validation
Before any deployment, run the pre-provision script to validate prerequisites:
```bash
pwsh ./scripts/pre-provision.ps1
```
This checks for required tools (terraform v1.5+, az CLI v2.50+, kubelogin), Azure login status, and the Terraform environment variables `TF_VAR_acme_email` and `TF_VAR_kibana_hostname`.

> **Note:** While `pre-provision.ps1` checks for Terraform v1.5+, the actual Terraform constraint in `infra/versions.tf` requires `~> 1.12` (1.12.x or higher). Use Terraform 1.12+ to match the repository's version constraint.

### Terraform Formatting
**ALWAYS run terraform fmt before committing Terraform changes:**
```bash
# Format infra layer
terraform fmt -recursive ./infra

# Format platform layer
terraform fmt -recursive ./platform

# Check formatting (CI check)
terraform fmt -check -recursive ./infra
terraform fmt -check -recursive ./platform
```

### PowerShell Syntax Validation
**ALWAYS validate PowerShell scripts before committing:**
```bash
pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; foreach ($s in $scripts) { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$null) }'
```

### Full Deployment (requires Azure credentials)
```bash
# Set required environment variables first
azd env set TF_VAR_contact_email "your-email@example.com"
azd env set TF_VAR_acme_email "your-email@example.com"
azd env set TF_VAR_kibana_hostname "kibana.yourdomain.com"

# Deploy everything (takes ~15-20 minutes)
azd up
```

**Deployment Flow:**
1. `preprovision` hook: Runs `./scripts/pre-provision.ps1` - validates prerequisites
2. `provision`: Terraform creates AKS cluster (Layer 1) in `./infra` directory
3. `postprovision` hook: Runs `./scripts/post-provision.ps1` which orchestrates:
   - Phase 1: `./scripts/ensure-safeguards.ps1` - Waits for Gatekeeper/Policy readiness
   - Phase 2: `./scripts/deploy-platform.ps1` - Deploys platform components (Layer 2) via Terraform in `./platform`

### Manual Platform Deployment
If you need to deploy just the platform layer (after cluster exists):
```bash
cd platform
terraform init
terraform plan
terraform apply
```

### Cleanup
```bash
azd down --force --purge
```

## Project Structure

```
cimpl-azd/
├── azure.yaml                     # azd configuration with hooks
├── .github/
│   └── workflows/
│       └── pr-checks.yml         # CI: terraform fmt, PowerShell syntax, secrets scan
├── infra/                        # Layer 1: AKS cluster infrastructure
│   ├── main.tf                   # Resource group
│   ├── aks.tf                    # AKS Automatic cluster configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Outputs (cluster name, RG, etc.)
│   ├── providers.tf              # Azure provider config
│   └── versions.tf               # Terraform and provider versions
├── platform/                     # Layer 2: Platform components (K8s/Helm)
│   ├── main.tf                   # Data sources (cluster info)
│   ├── providers.tf              # K8s, Helm providers
│   ├── helm_cert_manager.tf      # cert-manager for TLS
│   ├── helm_elastic.tf           # ECK Operator + Elasticsearch + Kibana
│   ├── helm_postgresql.tf        # PostgreSQL (Bitnami)
│   ├── helm_minio.tf             # MinIO (Bitnami)
│   ├── k8s_gateway.tf            # Istio Gateway API config
│   ├── variables.tf              # Platform variables
│   └── versions.tf               # Provider versions
├── scripts/
│   ├── pre-provision.ps1         # Pre-deploy validation
│   ├── post-provision.ps1        # Two-phase deployment orchestrator
│   ├── ensure-safeguards.ps1     # Phase 1: Wait for Gatekeeper
│   └── deploy-platform.ps1       # Phase 2: Deploy platform Terraform
├── docs/
│   ├── mkdocs.yml                # Documentation site config
│   └── src/                      # Documentation source (MkDocs)
│       ├── architecture/         # Architecture docs
│       ├── decisions/            # ADRs
│       ├── getting-started/      # Setup guides
│       └── operations/           # Pipelines, troubleshooting
├── README.md                     # Project landing page
```

## Architecture and Key Components

### Three-Layer Architecture
1. **Layer 1 (infra/):** AKS Automatic cluster with node pools, Azure RBAC, Workload Identity
2. **Layer 2 (platform/):** cert-manager, Elasticsearch/Kibana (ECK), PostgreSQL, MinIO, Istio Gateway
3. **Layer 3 (future):** OSDU platform services and custom applications

### AKS Cluster Configuration
- **Kubernetes Version:** 1.32
- **SKU:** Automatic (Standard tier)
- **Network:** Azure CNI Overlay + Cilium
- **Service Mesh:** Istio asm-1-28 (managed by AKS)
- **Node Pools:**
  - System: 2x Standard_D4lds_v5
  - Elastic: 3x Standard_D4as_v5 (dedicated for Elasticsearch)

### Platform Components
| Component | Version | Notes |
|-----------|---------|-------|
| cert-manager | 1.17.0 | Let's Encrypt integration (Helm chart v1.17.0) |
| Elasticsearch | 8.15.2 | 3-node cluster, 128Gi SSD each |
| Kibana | 8.15.2 | External access via Istio |
| PostgreSQL | 16.4.6 | Bitnami Helm chart v16.4.6 (PostgreSQL 18.x image), 8Gi storage |
| MinIO | 5.4.0 | Official MinIO Helm chart v5.4.0 from https://charts.min.io/, 10Gi storage |

## Critical Issues and Workarounds

### Issue 1: AKS Automatic Deployment Safeguards (CRITICAL)
**Problem:** AKS Automatic clusters have Deployment Safeguards **always enforced** with **no option to relax or exclude namespaces**. This is by design per Microsoft.

**What doesn't work:**
- `az aks safeguards update --level Warn` → Rejected
- `az aks safeguards update --excluded-ns` → Rejected
- Any attempts to bypass safeguards

**Required compliance for all workloads:**
1. All containers MUST have `readinessProbe` and `livenessProbe`
2. All containers MUST have resource `requests`
3. NO `:latest` image tags allowed
4. MUST set `seccompProfile: RuntimeDefault` in pod security context
5. Deployments with replicas > 1 MUST have `topologySpreadConstraints` or `podAntiAffinity`
6. Pod Security Standards (runAsNonRoot, etc.) enforced

**Resolution:** Make all workloads compliant, not bypass safeguards. The `ensure-safeguards.ps1` script waits for Gatekeeper readiness before platform deployment.

### Issue 2: Two-Phase Deployment Required
**Problem:** Azure Policy/Gatekeeper is eventually consistent. Fresh clusters need time for policies to reconcile.

**Solution:** The `post-provision.ps1` script uses a two-phase approach:
- Phase 1: Wait for Gatekeeper readiness (explicit gate)
- Phase 2: Deploy platform components

**Always use this pattern when modifying deployment scripts.**

### Issue 3: Helm Provider v3 Syntax
The platform layer uses Helm provider `~> 3.1` and Kubernetes provider `~> 3.0` (pinned in `platform/versions.tf`). Key syntax differences from v2:
- `set {}` blocks are now `set = [{ name = "...", value = "..." }, ...]` (list-of-objects)
- `postrender {}` blocks are now `postrender = { binary_path = "..." }` (object assignment)
- `kubernetes_namespace` / `kubernetes_secret` resource names are kept (deprecated but functional; v1 rename deferred)

### Issue 4: Bitnami Chart Image Pinning
Bitnami free-tier charts default to `image.tag: latest`, which AKS Automatic Gatekeeper rejects (`K8sAzureV2ContainerNoLatestImage`). Pin to `bitnamilegacy/` images with versioned tags:
```yaml
global:
  security:
    allowInsecureImages: true
image:
  registry: docker.io
  repository: bitnamilegacy/redis
  tag: 8.2.1-debian-12-r0
```

### Issue 5: PostgreSQL Version Pinning
PostgreSQL data files are version-specific. The chart is configured with:
```hcl
lifecycle {
  ignore_changes = all  # Prevent accidental upgrades
}
```
Do NOT change PostgreSQL versions without data migration plan.

### Issue 6: Terraform State Separation
This project uses **two separate Terraform states**:
1. `infra/` - Cluster infrastructure
2. `platform/` - Platform components

The platform layer reads cluster info via environment variables or terraform outputs. When making changes that affect both layers, ensure outputs from infra are correctly passed to platform.

## CI/CD Pipeline

The `.github/workflows/pr-checks.yml` workflow runs on all PRs:
1. **Terraform Format Check** - Validates `terraform fmt` on infra/ and platform/
2. **PowerShell Syntax Check** - Validates all .ps1 files parse correctly
3. **Secrets Scan** - Scans for hardcoded secrets using ripgrep patterns

**All three checks must pass before merge.**

## Environment Variables

### Required for Deployment
```bash
TF_VAR_contact_email    # Contact email for resource tagging (required by Terraform)
TF_VAR_acme_email       # Email for Let's Encrypt certificates
TF_VAR_kibana_hostname  # Hostname for Kibana external access
```

### Optional
```bash
AZURE_LOCATION          # Azure region (default: eastus2)
```

These are set via `azd env set` and stored in `.azure/<env>/.env`.

## Common Development Tasks

### Adding a New Terraform Resource
1. Add resource to appropriate .tf file in `infra/` or `platform/`
2. Run `terraform fmt -recursive ./<layer>`
3. Test locally with `terraform plan` and `terraform apply`
4. Commit changes (CI will validate formatting)

### Modifying PowerShell Scripts
1. Edit script in `scripts/`
2. Test syntax: `pwsh -File ./scripts/<script>.ps1 -WhatIf` (if supported)
3. Validate with PSParser (see validation command above)
4. Test full execution in a dev environment
5. Commit changes (CI will validate syntax)

### Modifying Helm Chart Values
1. Edit values in `platform/helm_*.tf`
2. Ensure compliance with AKS safeguards (probes, resources, seccomp, etc.)
3. Run `terraform fmt -recursive ./platform`
4. Test with `terraform plan` to see changes
5. Deploy with `terraform apply` to validate

### Adding a New Platform Component
1. Create new `platform/helm_<component>.tf` or `platform/k8s_<component>.tf`
2. Ensure workload is safeguards-compliant (see Issue 1)
3. Add outputs if needed to `platform/outputs.tf`
4. Update README.md with component details
5. Test full deployment cycle

## Useful Commands

```bash
# Check AKS cluster status
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check Gatekeeper constraints (safeguards)
kubectl get constraints -o wide

# Check Elasticsearch health
kubectl get elasticsearch -n elasticsearch
kubectl get pods -n elasticsearch

# Get Elasticsearch password
kubectl get secret elasticsearch-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d

# Check Istio ingress
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external

# View safeguards violations
kubectl get k8sazurev1antiaffinityrules -o wide
kubectl get k8sazurev2containerenforceprob -o wide

# Check PostgreSQL
kubectl exec -it postgresql-0 -n postgresql -- pg_isready

# Manual platform Terraform operations
cd platform
terraform init
terraform plan
terraform apply
terraform destroy -target=helm_release.postgresql  # Destroy specific resource
```

## Documentation Files

- **README.md**: Project landing page with quick start
- **docs/src/architecture/overview.md**: Detailed architecture documentation
- **docs/src/decisions/**: Architecture Decision Records
- **.env.example**: Environment variable template

**When making significant changes, update relevant documentation files.**

## Key Facts for Code Changes

1. **Always format Terraform** before committing - CI checks this
2. **Always validate PowerShell syntax** before committing - CI checks this
3. **Never commit secrets** - CI scans for this; use environment variables
4. **AKS safeguards are non-negotiable** - Make workloads compliant, don't try to bypass
5. **Two-phase deployment is required** - Don't modify the orchestration pattern
6. **Helm provider is pinned** - Don't upgrade without migration plan
7. **PostgreSQL version is pinned** - Don't change without data migration
8. **Two separate Terraform states** - Be careful with cross-layer dependencies
9. **PowerShell scripts use `$ErrorActionPreference = "Stop"`** - Match this pattern
10. **All deployments use `azd` CLI** - Don't bypass with direct terraform/helm commands

## Trust These Instructions

These instructions are based on thorough analysis of the codebase, documentation, and CI pipeline. Follow them to reduce exploration time and avoid common pitfalls. Only perform additional searches if information is incomplete or found to be incorrect.
