# Deployment Walkthrough

This guide provides a detailed walkthrough of deploying cimpl-azd, with more context than the [Quick Start](../getting-started/quickstart.md). It covers environment setup, configuration decisions, what happens during `azd up`, and how to verify the deployment.

## Prerequisites

Ensure all tools are installed per the [Prerequisites](../getting-started/prerequisites.md) page. Verify:

```bash
az version          # Azure CLI v2.50+
azd version         # Azure Developer CLI v1.5+
terraform version   # Terraform v1.5+
kubectl version --client
kubelogin --version
helm version        # Helm v3.12+
kustomize version
pwsh --version      # PowerShell Core v7+
```

!!! tip "Before you begin"
    Confirm the following before starting Step 1:

    - [ ] Authenticated to Azure (`az login` and `azd auth login`)
    - [ ] Correct subscription selected (`az account show`)
    - [ ] Environment created (`azd env new <name>`)
    - [ ] Required variables set (contact email, DNS zone, ACME email)
    - [ ] DNS zone exists and you have DNS Zone Contributor access

## Step 1: Authenticate

```bash
# Log in to Azure
az login

# Log in to Azure Developer CLI
azd auth login

# Verify your subscription
az account show --query "{name:name, id:id}" -o table
```

!!! tip
    If you have multiple subscriptions, set the correct one:
    ```bash
    az account set --subscription "your-subscription-id"
    ```

## Step 2: Create an Environment

```bash
# Clone the repository
git clone <repository-url>
cd cimpl-azd

# Create a named environment
azd env new dev
```

The environment name becomes part of all resource names (e.g., `rg-cimpl-dev`, `cimpl-dev`). Use distinct names for parallel deployments (e.g., `dev-alice`, `staging`).

## Step 3: Configure Required Variables

```bash
# Contact email (for Azure resource tagging)
azd env set AZURE_CONTACT_EMAIL "your-email@example.com"

# ACME email for Let's Encrypt TLS certificates
azd env set TF_VAR_acme_email "your-email@example.com"

# DNS zone configuration
azd env set TF_VAR_dns_zone_name "yourdomain.com"
azd env set TF_VAR_dns_zone_resource_group "your-dns-rg"
azd env set TF_VAR_dns_zone_subscription_id "your-dns-subscription-id"
```

## Step 4: Configuration Decisions

### Region Selection

```bash
# Default is eastus2; change if needed
azd env set AZURE_LOCATION "centralus"
```

Consider: VM SKU availability varies by region. If you hit `OverconstrainedZonalAllocationRequest`, try reducing availability zones:

```bash
azd env set TF_VAR_system_pool_availability_zones '["1", "3"]'
```

### Ingress Mode

By default, the Istio gateway gets a public IP. For internal-only access:

```bash
azd env set TF_VAR_enable_public_ingress false
```

### VM Size

AKS Automatic may override your VM size. If you see `PropertyChangeNotAllowed`, match the actual SKU:

```bash
azd env set TF_VAR_system_pool_vm_size "Standard_D4lds_v5"
```

### Optional Services

Review [Feature Flags](../getting-started/feature-flags.md) to decide which optional services to enable.

## Step 5: Deploy

```bash
azd up
```

### What Happens During `azd up`

**Phase 1 — Pre-Provision** (`scripts/pre-provision.ps1`):

- Validates all required tools are installed
- Auto-generates credential variables if not set (PostgreSQL password, Redis password, etc.)
- Generates an ingress prefix if `CIMPL_INGRESS_PREFIX` is not set

**Phase 2 — Provision** (`infra/`):

- Creates the Azure Resource Group (`rg-cimpl-<env>`)
- Deploys AKS Automatic cluster with Istio service mesh
- Configures system node pool across availability zones
- Sets up Azure RBAC and policy exemptions
- **Duration:** ~10-15 minutes

**Phase 3 — Post-Provision** (`scripts/post-provision.ps1`):

- Configures kubeconfig for kubectl access
- Configures AKS deployment safeguards (Warning mode)
- **Waits for Gatekeeper controller to reconcile** (this is the gate)
- Verifies namespace exclusions and probe exemptions are active
- **Deploys the foundation layer** (`software/foundation/`):
    - cert-manager (v1.19.3) + ClusterIssuers
    - ECK operator (v3.3.0)
    - CNPG operator (v0.27.1)
    - ExternalDNS (if enabled)
    - Gateway API CRDs + base Gateway resource
    - Shared StorageClasses (ES, PG, Redis, RabbitMQ)
- **Duration:** ~5-10 minutes

**Phase 4 — Pre-Deploy** (`scripts/pre-deploy.ps1`):

- Verifies cluster access
- Runs `terraform apply` for `software/stack/`
- Deploys middleware in dependency order:
    1. Karpenter NodePool + platform namespace (with Istio STRICT mTLS)
    2. Elasticsearch + Kibana (using ECK operator from foundation)
    3. PostgreSQL cluster + database bootstrap (using CNPG operator from foundation)
    4. Redis, RabbitMQ, MinIO
    5. Keycloak + realm import + JWKS readiness wait
    6. Gateway HTTPRoutes + TLS certificates
    7. Airflow (if enabled)
- Deploys OSDU services in dependency order
- Verifies component health
- **Duration:** ~15-25 minutes (Java services have slow startup)

**Total deployment time:** ~30-45 minutes for a fresh environment.

## Step 6: Verify the Deployment

### Check Cluster Access

```bash
# Get kubeconfig
az aks get-credentials --resource-group rg-cimpl-dev --name cimpl-dev

# Verify nodes
kubectl get nodes
```

### Check Foundation Layer

```bash
# Foundation namespace
kubectl get pods -n foundation

# cert-manager
kubectl get clusterissuers

# ECK operator
kubectl get pods -n foundation -l app.kubernetes.io/name=elastic-operator

# CNPG operator
kubectl get pods -n foundation -l app.kubernetes.io/name=cloudnative-pg
```

### Check Middleware Health

```bash
# Elasticsearch (expect green status)
kubectl get elasticsearch -n platform

# PostgreSQL (expect "Cluster in healthy state")
kubectl get clusters.postgresql.cnpg.io -n platform

# Redis
kubectl get pods -n platform -l app.kubernetes.io/name=redis

# RabbitMQ
kubectl get pods -n platform -l app=rabbitmq

# Keycloak
kubectl get pods -n platform -l app=keycloak

# MinIO
kubectl get pods -n platform -l app=minio
```

### Check OSDU Services

```bash
# All OSDU pods
kubectl get pods -n osdu

# Check a specific service
kubectl logs -n osdu -l app=partition -c partition --tail=50
```

### Check Gateway and Ingress

```bash
# External IP
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external

# HTTPRoutes
kubectl get httproute -A

# TLS certificates
kubectl get certificates -n platform
```

### API Smoke Test

Verify the platform is responding through the gateway:

```bash
# Get the ingress prefix and DNS zone from your environment
INGRESS_PREFIX=$(azd env get-value CIMPL_INGRESS_PREFIX)
DNS_ZONE=$(azd env get-value TF_VAR_dns_zone_name)

# Test the partition service health endpoint
curl -s "https://${INGRESS_PREFIX}.${DNS_ZONE}/api/partition/v1/_ah/readiness_check"
```

!!! success "Deployment complete"
    Your deployment is successful when all of the following are true:

    - All foundation pods in `Running` state (`kubectl get pods -n foundation`)
    - Elasticsearch shows `green` health, PostgreSQL shows `Cluster in healthy state`
    - Redis, RabbitMQ, MinIO, and Keycloak pods are `Running`
    - OSDU service pods are `Running` (core) or `Completed` (bootstrap)
    - Gateway has an external IP assigned
    - API smoke test returns a successful response

### Access Kibana

1. Get the external IP from the Istio gateway
2. Create a DNS record pointing your Kibana hostname to the external IP
3. Get the Elasticsearch password:
    ```bash
    kubectl get secret elasticsearch-es-elastic-user -n platform \
      -o jsonpath='{.data.elastic}' | base64 -d
    ```
4. Browse to `https://<prefix>-kibana.<dns_zone_name>`

## Step 7: Multi-User Access

Grant other users access to the AKS cluster:

```bash
# Grant cluster admin
az role assignment create \
  --assignee "user@example.com" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "/subscriptions/<sub>/resourceGroups/rg-cimpl-dev/providers/Microsoft.ContainerService/managedClusters/cimpl-dev"
```

## Tear Down

```bash
# Destroy all resources
azd down --force --purge
```

!!! warning
    `azd down` deletes the resource group and all resources within it. PVCs with `Retain` reclaim policy will be lost when the cluster is deleted.

## What's Next

- **[Troubleshooting](../operations/troubleshooting.md)** — common deployment issues and how to resolve them
- **[Pipelines](../operations/pipelines.md)** — understand the CI/CD release flow
- **[Feature Flags](../getting-started/feature-flags.md)** — enable additional OSDU services
