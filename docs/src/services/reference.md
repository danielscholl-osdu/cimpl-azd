# Reference & Domain Services

Reference systems and domain services provide specialized OSDU capabilities. They are all **disabled by default** and can be enabled via [feature flags](../getting-started/feature-flags.md).

---

## Reference Systems

Reference systems provide coordinate conversion, unit handling, and catalog services used by domain applications.

**Terraform file:** `software/stack/osdu-services-reference.tf`

### CRS Conversion

| | |
|---|---|
| **Purpose** | Coordinate Reference System conversion |
| **Chart** | `core-plus-crs-conversion-deploy` |
| **Dependencies** | Entitlements, Partition |
| **Flag** | `enable_crs_conversion` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Converts geospatial coordinates between different coordinate reference systems (CRS). Used by domain services that work with spatial data.

### CRS Catalog

| | |
|---|---|
| **Purpose** | Coordinate Reference System catalog/registry |
| **Chart** | `core-plus-crs-catalog-deploy` |
| **Dependencies** | Entitlements, Partition |
| **Flag** | `enable_crs_catalog` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Provides a catalog of available coordinate reference systems. Works with CRS Conversion for spatial data operations.

### Unit

| | |
|---|---|
| **Purpose** | Unit of measurement conversion and catalog |
| **Chart** | `core-plus-unit-deploy` |
| **Dependencies** | Entitlements, Partition |
| **Flag** | `enable_unit` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Manages unit-of-measure definitions and conversions (e.g., feet to meters, barrels to cubic meters).

---

## Domain Services

Domain services implement specific E&P (Exploration & Production) data management capabilities.

**Terraform file:** `software/stack/osdu-services-domain.tf`

### Wellbore

| | |
|---|---|
| **Purpose** | Wellbore data management (DDMS) |
| **Chart** | `core-plus-wellbore-deploy` |
| **Dependencies** | Entitlements, Partition, Storage, PostgreSQL |
| **Flag** | `enable_wellbore` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | Uses PostgreSQL for wellbore-specific data |

Wellbore is a Domain Data Management Service (DDMS) that provides specialized APIs for wellbore trajectory, log, and completion data.

### Wellbore Worker

| | |
|---|---|
| **Purpose** | Background processing for wellbore operations |
| **Chart** | `core-plus-wellbore-worker-deploy` |
| **Dependencies** | Entitlements, Partition, Wellbore |
| **Flag** | `enable_wellbore_worker` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Handles async background tasks for the Wellbore DDMS, including data transformations, bulk operations, and indexing.

### EDS-DMS

| | |
|---|---|
| **Purpose** | External Data Sources Data Management Service |
| **Chart** | `core-plus-eds-dms-deploy` |
| **Dependencies** | Entitlements, Partition, Storage |
| **Flag** | `enable_eds_dms` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |

Manages connections to external data sources, enabling OSDU to federate data from outside the platform.

---

## Orchestration Services

### Workflow

| | |
|---|---|
| **Purpose** | Workflow orchestration (Airflow integration) |
| **Chart** | `core-plus-workflow-deploy` |
| **Dependencies** | Entitlements, Partition, Storage, PostgreSQL, Airflow |
| **Flag** | `enable_workflow` (default: false) |
| **Health** | `:8081/health/liveness`, `:8081/health/readiness` |
| **Database** | `workflow` (schema: `workflow`) |

Workflow provides an API layer over Apache Airflow for managing DAG-based data processing pipelines. Requires Airflow to be enabled (`enable_airflow = true`).

---

## Enabling Optional Services

To enable any optional service:

```bash
# Enable a single service
azd env set TF_VAR_enable_wellbore true

# Enable multiple services
azd env set TF_VAR_enable_crs_conversion true
azd env set TF_VAR_enable_crs_catalog true
azd env set TF_VAR_enable_unit true

# Redeploy
azd up
```

!!! note
    Ensure all upstream dependencies are enabled. For example, `enable_wellbore` requires `enable_storage`, `enable_entitlements`, and `enable_partition` (all enabled by default).
