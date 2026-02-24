# Quick Start

## 1. Clone and Configure

```bash
git clone <repository-url>
cd cimpl-azd

# Create environment configuration
azd env new dev
```

## 2. Set Required Environment Variables

```bash
# Required: Your contact email (for resource tagging)
azd env set AZURE_CONTACT_EMAIL "your-email@example.com"

# Required: ACME email for Let's Encrypt certificates
azd env set TF_VAR_acme_email "your-email@example.com"

# Required: DNS zone for ingress (ExternalDNS + TLS certificates)
azd env set TF_VAR_dns_zone_name "yourdomain.com"
azd env set TF_VAR_dns_zone_resource_group "your-dns-rg"
azd env set TF_VAR_dns_zone_subscription_id "your-subscription-id"

# Optional: Azure region (default: eastus2)
azd env set AZURE_LOCATION "eastus2"

# Optional: Override the auto-generated ingress prefix
# azd env set CIMPL_INGRESS_PREFIX "myteam"
```

!!! note "Ingress Prefix"
    An ingress prefix (`CIMPL_INGRESS_PREFIX`) is auto-generated during pre-provision if not set. Hostnames are derived as `<prefix>.<dns_zone_name>` (e.g., `a1b2c3d4-kibana.yourdomain.com`).

## 3. Deploy

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

## 4. Access Services

After deployment:

```bash
# Get external IP
kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external

# Get Elasticsearch password
kubectl get secret elasticsearch-es-elastic-user -n elasticsearch \
  -o jsonpath='{.data.elastic}' | base64 -d
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

## 5. Destroy

```bash
# Tear down all resources
azd down --force --purge
```
