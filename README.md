# cimpl-azd

Azure Developer CLI (azd) deployment for CIMPL on AKS Automatic.

This project deploys a complete platform stack on Azure Kubernetes Service (AKS) Automatic with Airflow, Elasticsearch, PostgreSQL, RabbitMQ, MinIO, and Istio service mesh.

- [Documentation](https://azure.github.io/cimpl-azd/): Detailed architecture and operations
- [Getting Started](https://azure.github.io/cimpl-azd/getting-started/prerequisites/): Prerequisites and setup
- [Architecture](https://azure.github.io/cimpl-azd/architecture/overview/): Component details and deployment flow
- [ADR Index](https://azure.github.io/cimpl-azd/decisions/): Design decision records

## Quick Start

```bash
# Authenticate
az login
azd auth login

# Create environment
azd init -e dev

# Configure
azd env set AZURE_CONTACT_EMAIL "your-email@example.com"
azd env set TF_VAR_acme_email "your-email@example.com"
azd env set TF_VAR_dns_zone_name "yourdomain.com"
azd env set TF_VAR_dns_zone_resource_group "your-dns-rg"
azd env set TF_VAR_dns_zone_subscription_id "your-subscription-id"

# Deploy
azd up

# Cleanup
azd down --force --purge
```

Ingress defaults to a public LoadBalancer. Set `TF_VAR_enable_public_ingress=false` for internal-only access within the VNet.

See the [Quick Start guide](https://azure.github.io/cimpl-azd/getting-started/quickstart/) for full instructions and the [Configuration Reference](https://azure.github.io/cimpl-azd/getting-started/configuration/) for all environment variables.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branching model, quality checks, and conventions.

## License

[Add license information]
