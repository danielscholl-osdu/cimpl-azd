# Core Services

Core services form the minimum viable OSDU platform. They are all enabled by default and deployed in dependency order.

## Partition

| | |
|---|---|
| **Purpose** | Multi-tenant data partition management |
| **Chart** | `core-plus-partition-deploy` |
| **Dependencies** | PostgreSQL |
| **Flag** | `enable_partition` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `partition` (schema: `partition`) |

The Partition service is the first OSDU service to deploy. Its bootstrap container registers the `osdu` data partition with endpoints for all middleware (PostgreSQL, Elasticsearch, Redis, RabbitMQ, MinIO).

**Key configuration:**
Partition properties map environment variable names to middleware connection details. Other OSDU services query the Partition service to discover their backend endpoints at runtime.

---

## Entitlements

| | |
|---|---|
| **Purpose** | Authorization and access control (groups, permissions) |
| **Chart** | `core-plus-entitlements-deploy` |
| **Dependencies** | Keycloak, Partition, PostgreSQL, Redis |
| **Flag** | `enable_entitlements` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `entitlements` (schema: `entitlements`, 5 tables) |

Entitlements manages user/group membership and access control. It uses a multi-tenant datasource pattern: database configuration is resolved dynamically via the Partition service.

**Key secrets:**

- `entitlements-multi-tenant-postgres-secret`: DB connection (`ENT_PG_URL_SYSTEM`, `ENT_PG_USER_SYSTEM`, `ENT_PG_PASS_SYSTEM`)
- `entitlements-redis-secret`: Redis password
- `datafier-secret`: Keycloak client credentials for bootstrap

**Bootstrap:** Acquires a token from Keycloak's `datafier` client and provisions tenant entitlements groups.

---

## Legal

| | |
|---|---|
| **Purpose** | Legal tag management for data governance |
| **Chart** | `core-plus-legal-deploy` |
| **Dependencies** | Entitlements, Partition, PostgreSQL |
| **Flag** | `enable_legal` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `legal` (schema: `legal`) |

Legal manages legal tags that govern data access and compliance policies within the OSDU platform.

---

## Schema

| | |
|---|---|
| **Purpose** | Schema registry for OSDU data types |
| **Chart** | `core-plus-schema-deploy` |
| **Dependencies** | Entitlements, Partition, PostgreSQL |
| **Flag** | `enable_schema` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `schema` (schema: `schema`) |

Schema provides a registry of data type definitions. Services validate records against registered schemas before storage.

---

## Storage

| | |
|---|---|
| **Purpose** | Record storage and retrieval |
| **Chart** | `core-plus-storage-deploy` |
| **Dependencies** | Legal, Entitlements, Partition, PostgreSQL |
| **Flag** | `enable_storage` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `storage` (schema: `storage`) |

Storage is the primary record persistence service. It validates legal tags via Legal, checks entitlements via Entitlements, and publishes change events to RabbitMQ for Indexer consumption.

---

## Search

| | |
|---|---|
| **Purpose** | Full-text and structured search over OSDU records |
| **Chart** | `core-plus-search-deploy` |
| **Dependencies** | Entitlements, Partition, Elasticsearch |
| **Flag** | `enable_search` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Search queries Elasticsearch indices maintained by the Indexer service. It does not use PostgreSQL directly.

---

## Indexer

| | |
|---|---|
| **Purpose** | Index OSDU records into Elasticsearch |
| **Chart** | `core-plus-indexer-deploy` |
| **Dependencies** | Entitlements, Partition, Elasticsearch |
| **Flag** | `enable_indexer` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Indexer consumes record change events from RabbitMQ and updates Elasticsearch indices. It works in tandem with the Elastic Bootstrap job which pre-creates index templates, ILM policies, and aliases.

---

## File

| | |
|---|---|
| **Purpose** | File metadata and binary object management |
| **Chart** | `core-plus-file-deploy` |
| **Dependencies** | Legal, Entitlements, Partition, PostgreSQL |
| **Flag** | `enable_file` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `file` (schema: `file`) |

File manages file metadata in PostgreSQL and binary objects in MinIO (S3-compatible storage).

---

## Notification

| | |
|---|---|
| **Purpose** | Event notification for record changes |
| **Chart** | `core-plus-notification-deploy` |
| **Dependencies** | Entitlements, Partition, RabbitMQ |
| **Flag** | `enable_notification` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Notification provides a pub/sub interface for downstream consumers to receive record change events.

---

## Dataset

| | |
|---|---|
| **Purpose** | Dataset metadata management |
| **Chart** | `core-plus-dataset-deploy` |
| **Dependencies** | Entitlements, Partition, Storage, PostgreSQL |
| **Flag** | `enable_dataset` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `dataset` (schema: `dataset`) |

Dataset manages metadata for logical collections of OSDU records.

---

## Register

| | |
|---|---|
| **Purpose** | Service and subscription registration |
| **Chart** | `core-plus-register-deploy` |
| **Dependencies** | Entitlements, Partition, PostgreSQL |
| **Flag** | `enable_register` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `register` (schema: `register`) |

Register manages service endpoint registrations and event subscriptions within the OSDU platform.

---

## Policy

| | |
|---|---|
| **Purpose** | Policy evaluation (OPA-based) |
| **Chart** | `core-plus-policy-deploy` |
| **Dependencies** | Entitlements, Partition |
| **Flag** | `enable_policy` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Policy provides Open Policy Agent (OPA) based policy evaluation for data access decisions.

---

## Secret

| | |
|---|---|
| **Purpose** | Secret management for OSDU services |
| **Chart** | `core-plus-secret-deploy` |
| **Dependencies** | Entitlements, Partition |
| **Flag** | `enable_secret` (default: true) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Secret manages application-level secrets and credentials used by OSDU services.
