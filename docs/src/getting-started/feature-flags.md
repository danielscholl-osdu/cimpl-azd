# Feature Flags

cimpl-azd uses an **opt-out model**: all middleware and core OSDU services are enabled by default. Set `TF_VAR_enable_<component>=false` to disable any component. This keeps the environment file clean for the default deployment.

```bash
# Example: disable a component
azd env set TF_VAR_enable_elasticsearch false
```

---

## Deployment Scope

The deployment uses three Terraform layers. `azd provision` deploys Layers 1 and 2. `azd deploy` deploys Layer 3.

| Layer | What it deploys | Controlled by |
|-------|----------------|---------------|
| **1. Infrastructure** (`infra/`) | AKS cluster, system node pool, RBAC | Infrastructure variables |
| **2. Foundation** (`software/foundation/`) | cert-manager, ECK operator, CNPG operator, ExternalDNS, Gateway CRDs | Foundation variables |
| **3. Software Stack** (`software/stack/`) | Platform middleware + OSDU services | Feature flags (this page) |

Within Layer 3, feature flags control two levels of the stack:

- **Platform middleware** (Elasticsearch, PostgreSQL, Redis, etc.) — deployed into the `platform` namespace
- **OSDU services** (Partition, Entitlements, Legal, etc.) — deployed into the `osdu` namespace

---

## Group Flags (Coarse Control)

Group flags let you disable entire capability blocks without toggling individual services. They encode the OSDU dependency chain: reference and domain services require core, so disabling core automatically disables everything downstream (see [ADR-0019](../decisions/0019-group-feature-flags-with-cascading-locals.md)).

| Flag | Default | Effect |
|------|---------|--------|
| `enable_osdu_core_services` | `true` | Master switch for all core services (partition through workflow) |
| `enable_osdu_reference_services` | `true` | Master switch for reference services; cascades through core |
| `enable_osdu_domain_services` | `false` | Master switch for domain services; cascades through core |

**Cascade rules:**

- Disabling core disables reference and domain regardless of their flags
- Disabling reference does not affect core or domain
- Disabling domain does not affect core or reference
- Individual service flags (below) are ANDed with their group flag

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

Core services are all **enabled by default**. They form the minimum viable OSDU platform. Set `enable_osdu_core_services=false` to disable all of them at once.

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
| `enable_workflow` | `true` | Entitlements, Partition, Storage, PostgreSQL, Airflow |

---

## OSDU Service Flags: Reference Systems

Reference services are all **enabled by default** (but require core). Set `enable_osdu_reference_services=false` to disable all of them at once.

| Flag | Default | Dependencies |
|------|---------|-------------|
| `enable_crs_conversion` | `true` | Entitlements, Partition |
| `enable_crs_catalog` | `true` | Entitlements, Partition |
| `enable_unit` | `true` | Entitlements, Partition |

---

## OSDU Service Flags: Domain Services

Domain services are all **disabled by default**. Set `enable_osdu_domain_services=true` to enable the group, then individual flags to select services.

| Flag | Default | Dependencies |
|------|---------|-------------|
| `enable_wellbore` | `false` | Entitlements, Partition, Storage, PostgreSQL |
| `enable_wellbore_worker` | `false` | Entitlements, Partition, Wellbore |
| `enable_eds_dms` | `false` | Entitlements, Partition, Storage |

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

### Platform Only (No OSDU Services)

```bash
azd env set TF_VAR_enable_osdu_core_services false
azd up
# All middleware deploys; no OSDU services (reference + domain also off)
```

### Core + Reference Only (No Domain)

```bash
# This is the default — domain services are off by default
azd up
```

### Full Deployment (All Service Groups)

```bash
azd env set TF_VAR_enable_osdu_domain_services true
azd env set TF_VAR_enable_wellbore true
azd env set TF_VAR_enable_eds_dms true
azd up
```

### Core Services with Specific Opt-Outs

```bash
# Deploy everything except search and indexer
azd env set TF_VAR_enable_search false
azd env set TF_VAR_enable_indexer false
azd up
```

### Reduced Footprint (Skip Heavy Middleware)

```bash
azd env set TF_VAR_enable_elasticsearch false
azd env set TF_VAR_enable_rabbitmq false
# Search, Indexer, Notification will be skipped (missing dependencies)
azd up
```
