# software/stack/ — Config-driven OSDU Stack

This Terraform root module deploys middleware and OSDU services onto an AKS cluster.
Feature flags (`enable_*` variables) control which components are deployed.

## File Layout

| File | Purpose |
|------|---------|
| `locals.tf` | Naming derivation, cross-namespace FQDNs, ingress hostnames |
| `platform.tf` | Platform namespace, Istio mTLS, Karpenter NodePool/AKSNodeClass |
| `middleware.tf` | 8 middleware module calls (elastic, postgresql, redis, rabbitmq, minio, keycloak, airflow, gateway) |
| `osdu-common.tf` | OSDU common namespace resources module call |
| `osdu-services-core.tf` | Core OSDU services: partition, entitlements, legal, schema, storage, search, indexer, file, notification, dataset, register, policy, secret, workflow |
| `osdu-services-reference.tf` | Reference systems: crs_conversion, crs_catalog, unit |
| `osdu-services-domain.tf` | Domain data management + external data: wellbore, wellbore_worker, eds_dms |
| `variables-flags.tf` | All `enable_*` feature-flag variables |
| `variables-infra.tf` | Infrastructure variables (cluster, DNS, tags) |
| `variables-credentials.tf` | Sensitive credential variables |
| `variables-osdu.tf` | OSDU project/tenant/version variables |
| `providers.tf` | Provider configuration |
| `versions.tf` | Required providers and Terraform version |
| `outputs.tf` | Stack outputs |

## Child Modules (`modules/`)

| Module | Type | Description |
|--------|------|-------------|
| `elastic` | Helm + CRDs | Elasticsearch + Kibana via ECK operator |
| `postgresql` | CRDs | CloudNativePG cluster + bootstrap databases |
| `redis` | Helm | Redis cache via Bitnami chart |
| `rabbitmq` | Helm | RabbitMQ message broker |
| `minio` | Helm | MinIO object storage |
| `keycloak` | Helm | Keycloak identity provider + realm import |
| `airflow` | Helm | Apache Airflow workflow engine |
| `gateway` | kubectl | Gateway API routes + TLS certificates |
| `osdu-common` | K8s resources | OSDU namespace, ConfigMap, secrets, service accounts |
| `osdu-service` | Helm | Reusable module for deploying any OSDU service chart |
