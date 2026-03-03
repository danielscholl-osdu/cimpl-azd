# Feature Flags

cimpl-azd uses an **opt-out model**: all middleware and core OSDU services are enabled by default. Set `TF_VAR_enable_<component>=false` to disable any component. This keeps the environment file clean for the default deployment.

```bash
# Example: disable a component
azd env set TF_VAR_enable_elasticsearch false
```

---

## Infrastructure Flags

These variables control the AKS cluster and node pool configuration (Layer 1: `infra/`). Foundation and stack flags are in `software/foundation/` and `software/stack/` respectively.

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_VAR_system_pool_vm_size` | `Standard_D4lds_v5` | VM SKU for AKS system node pool |
| `TF_VAR_system_pool_availability_zones` | `["1", "2", "3"]` | Availability zones for system nodes. Reduce to avoid capacity issues (e.g., `["1", "3"]`) |
| `AZURE_LOCATION` | `eastus2` | Azure region for all resources |

---

## Networking & Ingress Flags

| Flag | Default | Description |
|------|---------|-------------|
| `enable_public_ingress` | `true` | Expose Istio gateway to the internet. Set `false` for internal-only LoadBalancer |
| `enable_gateway` | `true` | Deploy Gateway API resources (HTTPRoute, TLS certificates) |
| `enable_external_dns` | `false` | Deploy ExternalDNS for automatic DNS record management |
| `enable_cert_manager` | `true` | Deploy cert-manager for automatic TLS certificate provisioning |

---

## Middleware Flags

All middleware defaults to **enabled**.

| Flag | Default | Description |
|------|---------|-------------|
| `enable_elasticsearch` | `true` | Elasticsearch + Kibana + ECK Operator (search & analytics) |
| `enable_elastic_bootstrap` | `true` | Elastic Bootstrap job (index templates, ILM policies, aliases) |
| `enable_postgresql` | `true` | CloudNativePG + PostgreSQL 3-instance HA cluster |
| `enable_redis` | `true` | Redis cache (used by Entitlements) |
| `enable_rabbitmq` | `true` | RabbitMQ 3-node cluster (async messaging) |
| `enable_minio` | `true` | MinIO standalone (S3-compatible object storage) |
| `enable_keycloak` | `true` | Keycloak identity provider (OSDU realm + datafier client) |
| `enable_airflow` | `false` | Apache Airflow (not yet integrated with OSDU DAGs) |
| `enable_nodepool` | `true` | Shared Karpenter NodePool for platform workloads |

---

## OSDU Service Flags: Core

Core services are all **enabled by default**. They form the minimum viable OSDU platform.

| Flag | Default | Dependencies |
|------|---------|-------------|
| `enable_common` | `true` | OSDU namespace, ConfigMaps, shared secrets, mTLS policy |
| `enable_partition` | `true` | PostgreSQL |
| `enable_entitlements` | `true` | Keycloak, Partition, PostgreSQL, Redis |
| `enable_legal` | `true` | Entitlements, Partition, PostgreSQL |
| `enable_schema` | `true` | Entitlements, Partition, PostgreSQL |
| `enable_storage` | `true` | Legal, Entitlements, Partition, PostgreSQL |
| `enable_search` | `true` | Entitlements, Partition, Elasticsearch |
| `enable_indexer` | `true` | Entitlements, Partition, Elasticsearch |
| `enable_file` | `true` | Legal, Entitlements, Partition, PostgreSQL |
| `enable_notification` | `true` | Entitlements, Partition, RabbitMQ |
| `enable_dataset` | `true` | Entitlements, Partition, Storage, PostgreSQL |
| `enable_register` | `true` | Entitlements, Partition, PostgreSQL |
| `enable_policy` | `true` | Entitlements, Partition |
| `enable_secret` | `true` | Entitlements, Partition |

---

## OSDU Service Flags: Reference Systems

Reference services are all **disabled by default**.

| Flag | Default | Dependencies |
|------|---------|-------------|
| `enable_crs_conversion` | `false` | Entitlements, Partition |
| `enable_crs_catalog` | `false` | Entitlements, Partition |
| `enable_unit` | `false` | Entitlements, Partition |

---

## OSDU Service Flags: Domain & Orchestration

Domain and orchestration services are all **disabled by default**.

| Flag | Default | Dependencies |
|------|---------|-------------|
| `enable_wellbore` | `false` | Entitlements, Partition, Storage, PostgreSQL |
| `enable_wellbore_worker` | `false` | Entitlements, Partition, Wellbore |
| `enable_eds_dms` | `false` | Entitlements, Partition, Storage |
| `enable_workflow` | `false` | Entitlements, Partition, Storage, PostgreSQL, Airflow |

---

## DNS & Certificate Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TF_VAR_dns_zone_name` | Yes | Azure DNS zone name (e.g., `yourdomain.com`) |
| `TF_VAR_dns_zone_resource_group` | Yes | Resource group containing the DNS zone |
| `TF_VAR_dns_zone_subscription_id` | Yes | Subscription ID containing the DNS zone |
| `TF_VAR_acme_email` | Yes | Email for Let's Encrypt certificate notifications |
| `CIMPL_INGRESS_PREFIX` | No | Ingress hostname prefix (auto-generated if not set) |
| `TF_VAR_use_letsencrypt_production` | No | Use Let's Encrypt production issuer (default: `false` = staging) |

---

## Credential Variables

All credential variables are marked `sensitive` in Terraform. Most are auto-generated during pre-provision if not explicitly set.

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_VAR_postgresql_password` | auto-generated | PostgreSQL admin password |
| `TF_VAR_postgresql_username` | `osdu` | PostgreSQL application DB owner username |
| `TF_VAR_keycloak_db_password` | auto-generated | Keycloak database password |
| `TF_VAR_keycloak_admin_password` | auto-generated | Keycloak admin console password |
| `TF_VAR_datafier_client_secret` | auto-generated | Keycloak `datafier` client secret |
| `TF_VAR_airflow_db_password` | auto-generated | Airflow database password |
| `TF_VAR_redis_password` | auto-generated | Redis authentication password |
| `TF_VAR_rabbitmq_username` | `rabbitmq` | RabbitMQ admin username |
| `TF_VAR_rabbitmq_password` | auto-generated | RabbitMQ admin password |
| `TF_VAR_rabbitmq_erlang_cookie` | auto-generated | RabbitMQ Erlang clustering cookie |
| `TF_VAR_minio_root_user` | `minioadmin` | MinIO root username |
| `TF_VAR_minio_root_password` | auto-generated | MinIO root password |

!!! warning "Security"
    Never commit credential values to source control. Use `azd env set` which stores values in `.azure/<env>/.env` (gitignored) or set them as environment variables in CI/CD pipelines.

---

## OSDU Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_VAR_cimpl_tenant` | `osdu` | CIMPL data partition ID |
| `TF_VAR_cimpl_project` | (empty) | CIMPL project/group identifier |
| `TF_VAR_cimpl_subscriber_private_key_id` | (empty) | Subscriber private key identifier |
| `TF_VAR_osdu_chart_version` | `0.0.7-latest` | Default Helm chart version for all OSDU services |
| `TF_VAR_osdu_service_versions` | `{}` | Per-service chart version overrides (map) |

---

## Other Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_CONTACT_EMAIL` | Yes | Contact email for Azure resource tagging |
| `TF_VAR_stack_id` | No | Stack name suffix for multi-stack support (e.g., `blue`) |

---

## Usage Examples

### Minimal Deployment (Core Only)

```bash
azd env new dev
azd env set AZURE_CONTACT_EMAIL "you@example.com"
azd env set TF_VAR_acme_email "you@example.com"
azd env set TF_VAR_dns_zone_name "yourdomain.com"
azd env set TF_VAR_dns_zone_resource_group "dns-rg"
azd env set TF_VAR_dns_zone_subscription_id "sub-id"
azd up
```

### Enable Domain Services

```bash
azd env set TF_VAR_enable_wellbore true
azd env set TF_VAR_enable_wellbore_worker true
azd env set TF_VAR_enable_crs_conversion true
azd up
```

### Middleware-Only (No OSDU Services)

```bash
azd env set TF_VAR_enable_common false
azd env set TF_VAR_enable_partition false
# All OSDU services will be skipped since they depend on Partition
azd up
```

### Reduced Footprint (Skip Heavy Components)

```bash
azd env set TF_VAR_enable_elasticsearch false
azd env set TF_VAR_enable_rabbitmq false
# Search, Indexer, Notification will be skipped (missing dependencies)
azd up
```
