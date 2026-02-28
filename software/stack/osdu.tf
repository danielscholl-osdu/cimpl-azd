# OSDU service deployments

module "partition" {
  source = "./modules/osdu-service"

  service_name              = "partition"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/partition/cimpl-helm"
  chart                     = "core-plus-partition-deploy"
  chart_version             = lookup(var.osdu_service_versions, "partition", var.osdu_chart_version)
  enable                    = var.enable_partition
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  depends_on = [module.osdu_common, module.postgresql]
}

module "entitlements" {
  source = "./modules/osdu-service"

  service_name              = "entitlements"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/entitlements/cimpl-helm"
  chart                     = "core-plus-entitlements-deploy"
  chart_version             = lookup(var.osdu_service_versions, "entitlements", var.osdu_chart_version)
  enable                    = var.enable_entitlements
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  extra_set = [
    {
      name  = "data.redisEntHost"
      value = local.redis_host
    }
  ]

  preconditions = [
    { condition = !var.enable_entitlements || var.enable_keycloak, error_message = "Entitlements requires Keycloak." },
    { condition = !var.enable_entitlements || var.enable_partition, error_message = "Entitlements requires Partition." },
    { condition = !var.enable_entitlements || var.enable_postgresql, error_message = "Entitlements requires PostgreSQL." },
    { condition = !var.enable_entitlements || var.enable_redis, error_message = "Entitlements requires Redis." },
  ]

  depends_on = [module.osdu_common, module.keycloak, module.partition]
}

module "legal" {
  source = "./modules/osdu-service"

  service_name              = "legal"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/cimpl-helm"
  chart                     = "core-plus-legal-deploy"
  chart_version             = lookup(var.osdu_service_versions, "legal", var.osdu_chart_version)
  enable                    = var.enable_legal
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_legal || var.enable_entitlements, error_message = "Legal requires Entitlements." },
    { condition = !var.enable_legal || var.enable_partition, error_message = "Legal requires Partition." },
    { condition = !var.enable_legal || var.enable_postgresql, error_message = "Legal requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "schema" {
  source = "./modules/osdu-service"

  service_name              = "schema"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/schema-service/cimpl-helm"
  chart                     = "core-plus-schema-deploy"
  chart_version             = lookup(var.osdu_service_versions, "schema", var.osdu_chart_version)
  enable                    = var.enable_schema
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_schema || var.enable_entitlements, error_message = "Schema requires Entitlements." },
    { condition = !var.enable_schema || var.enable_partition, error_message = "Schema requires Partition." },
    { condition = !var.enable_schema || var.enable_postgresql, error_message = "Schema requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "storage" {
  source = "./modules/osdu-service"

  service_name              = "storage"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/storage/cimpl-helm"
  chart                     = "core-plus-storage-deploy"
  chart_version             = lookup(var.osdu_service_versions, "storage", var.osdu_chart_version)
  enable                    = var.enable_storage
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_storage || var.enable_legal, error_message = "Storage requires Legal." },
    { condition = !var.enable_storage || var.enable_entitlements, error_message = "Storage requires Entitlements." },
    { condition = !var.enable_storage || var.enable_partition, error_message = "Storage requires Partition." },
    { condition = !var.enable_storage || var.enable_postgresql, error_message = "Storage requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.legal]
}

module "search" {
  source = "./modules/osdu-service"

  service_name              = "search"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/search-service/cimpl-helm"
  chart                     = "core-plus-search-deploy"
  chart_version             = lookup(var.osdu_service_versions, "search", var.osdu_chart_version)
  enable                    = var.enable_search
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  extra_set = [
    {
      name  = "data.elasticHost"
      value = "elasticsearch-es-http.${local.platform_namespace}.svc.cluster.local"
    },
    {
      name  = "data.elasticPort"
      value = "9200"
    },
  ]

  preconditions = [
    { condition = !var.enable_search || var.enable_entitlements, error_message = "Search requires Entitlements." },
    { condition = !var.enable_search || var.enable_partition, error_message = "Search requires Partition." },
    { condition = !var.enable_search || var.enable_elasticsearch, error_message = "Search requires Elasticsearch." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "indexer" {
  source = "./modules/osdu-service"

  service_name              = "indexer"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/indexer-service/cimpl-helm"
  chart                     = "core-plus-indexer-deploy"
  chart_version             = lookup(var.osdu_service_versions, "indexer", var.osdu_chart_version)
  enable                    = var.enable_indexer
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  extra_set = [
    {
      name  = "data.elasticHost"
      value = "elasticsearch-es-http.${local.platform_namespace}.svc.cluster.local"
    },
    {
      name  = "data.elasticPort"
      value = "9200"
    },
  ]

  preconditions = [
    { condition = !var.enable_indexer || var.enable_entitlements, error_message = "Indexer requires Entitlements." },
    { condition = !var.enable_indexer || var.enable_partition, error_message = "Indexer requires Partition." },
    { condition = !var.enable_indexer || var.enable_elasticsearch, error_message = "Indexer requires Elasticsearch." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "file" {
  source = "./modules/osdu-service"

  service_name              = "file"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/file/cimpl-helm"
  chart                     = "core-plus-file-deploy"
  chart_version             = lookup(var.osdu_service_versions, "file", var.osdu_chart_version)
  enable                    = var.enable_file
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_file || var.enable_legal, error_message = "File requires Legal." },
    { condition = !var.enable_file || var.enable_entitlements, error_message = "File requires Entitlements." },
    { condition = !var.enable_file || var.enable_partition, error_message = "File requires Partition." },
    { condition = !var.enable_file || var.enable_postgresql, error_message = "File requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.legal]
}

module "notification" {
  source = "./modules/osdu-service"

  service_name              = "notification"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/notification/cimpl-helm"
  chart                     = "core-plus-notification-deploy"
  chart_version             = lookup(var.osdu_service_versions, "notification", var.osdu_chart_version)
  enable                    = var.enable_notification
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  extra_set = [
    {
      name  = "data.rabbitmqHost"
      value = local.rabbitmq_host
    }
  ]

  preconditions = [
    { condition = !var.enable_notification || var.enable_entitlements, error_message = "Notification requires Entitlements." },
    { condition = !var.enable_notification || var.enable_partition, error_message = "Notification requires Partition." },
    { condition = !var.enable_notification || var.enable_rabbitmq, error_message = "Notification requires RabbitMQ." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "dataset" {
  source = "./modules/osdu-service"

  service_name              = "dataset"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/dataset/cimpl-helm"
  chart                     = "core-plus-dataset-deploy"
  chart_version             = lookup(var.osdu_service_versions, "dataset", var.osdu_chart_version)
  enable                    = var.enable_dataset
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_dataset || var.enable_entitlements, error_message = "Dataset requires Entitlements." },
    { condition = !var.enable_dataset || var.enable_partition, error_message = "Dataset requires Partition." },
    { condition = !var.enable_dataset || var.enable_storage, error_message = "Dataset requires Storage." },
    { condition = !var.enable_dataset || var.enable_postgresql, error_message = "Dataset requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "register" {
  source = "./modules/osdu-service"

  service_name              = "register"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/register/cimpl-helm"
  chart                     = "core-plus-register-deploy"
  chart_version             = lookup(var.osdu_service_versions, "register", var.osdu_chart_version)
  enable                    = var.enable_register
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_register || var.enable_entitlements, error_message = "Register requires Entitlements." },
    { condition = !var.enable_register || var.enable_partition, error_message = "Register requires Partition." },
    { condition = !var.enable_register || var.enable_postgresql, error_message = "Register requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "policy" {
  source = "./modules/osdu-service"

  service_name              = "policy"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/policy/cimpl-helm"
  chart                     = "core-plus-policy-deploy"
  chart_version             = lookup(var.osdu_service_versions, "policy", var.osdu_chart_version)
  enable                    = var.enable_policy
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_policy || var.enable_entitlements, error_message = "Policy requires Entitlements." },
    { condition = !var.enable_policy || var.enable_partition, error_message = "Policy requires Partition." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "secret" {
  source = "./modules/osdu-service"

  service_name              = "secret"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/secret/cimpl-helm"
  chart                     = "core-plus-secret-deploy"
  chart_version             = lookup(var.osdu_service_versions, "secret", var.osdu_chart_version)
  enable                    = var.enable_secret
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_secret || var.enable_entitlements, error_message = "Secret requires Entitlements." },
    { condition = !var.enable_secret || var.enable_partition, error_message = "Secret requires Partition." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "unit" {
  source = "./modules/osdu-service"

  service_name              = "unit"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/unit/cimpl-helm"
  chart                     = "core-plus-unit-deploy"
  chart_version             = lookup(var.osdu_service_versions, "unit", var.osdu_chart_version)
  enable                    = var.enable_unit
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_unit || var.enable_entitlements, error_message = "Unit requires Entitlements." },
    { condition = !var.enable_unit || var.enable_partition, error_message = "Unit requires Partition." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "workflow" {
  source = "./modules/osdu-service"

  service_name              = "workflow"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/data-flow/ingestion/workflow/cimpl-helm"
  chart                     = "core-plus-workflow-deploy"
  chart_version             = lookup(var.osdu_service_versions, "workflow", var.osdu_chart_version)
  enable                    = var.enable_workflow
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_workflow || var.enable_entitlements, error_message = "Workflow requires Entitlements." },
    { condition = !var.enable_workflow || var.enable_partition, error_message = "Workflow requires Partition." },
    { condition = !var.enable_workflow || var.enable_storage, error_message = "Workflow requires Storage." },
    { condition = !var.enable_workflow || var.enable_postgresql, error_message = "Workflow requires PostgreSQL." },
    { condition = !var.enable_workflow || var.enable_airflow, error_message = "Workflow requires Airflow." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "wellbore" {
  source = "./modules/osdu-service"

  service_name              = "wellbore"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/cimpl-helm"
  chart                     = "core-plus-wellbore-deploy"
  chart_version             = lookup(var.osdu_service_versions, "wellbore", var.osdu_chart_version)
  enable                    = var.enable_wellbore
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_wellbore || var.enable_entitlements, error_message = "Wellbore requires Entitlements." },
    { condition = !var.enable_wellbore || var.enable_partition, error_message = "Wellbore requires Partition." },
    { condition = !var.enable_wellbore || var.enable_storage, error_message = "Wellbore requires Storage." },
    { condition = !var.enable_wellbore || var.enable_postgresql, error_message = "Wellbore requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "wellbore_worker" {
  source = "./modules/osdu-service"

  service_name              = "wellbore-worker"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/cimpl-helm"
  chart                     = "core-plus-wellbore-worker-deploy"
  chart_version             = lookup(var.osdu_service_versions, "wellbore_worker", var.osdu_chart_version)
  enable                    = var.enable_wellbore_worker
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_wellbore_worker || var.enable_entitlements, error_message = "Wellbore Worker requires Entitlements." },
    { condition = !var.enable_wellbore_worker || var.enable_partition, error_message = "Wellbore Worker requires Partition." },
    { condition = !var.enable_wellbore_worker || var.enable_wellbore, error_message = "Wellbore Worker requires Wellbore." },
  ]

  depends_on = [module.osdu_common, module.wellbore]
}

module "crs_conversion" {
  source = "./modules/osdu-service"

  service_name              = "crs-conversion"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/crs-conversion-service/cimpl-helm"
  chart                     = "core-plus-crs-conversion-deploy"
  chart_version             = lookup(var.osdu_service_versions, "crs_conversion", var.osdu_chart_version)
  enable                    = var.enable_crs_conversion
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_crs_conversion || var.enable_entitlements, error_message = "CRS Conversion requires Entitlements." },
    { condition = !var.enable_crs_conversion || var.enable_partition, error_message = "CRS Conversion requires Partition." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "crs_catalog" {
  source = "./modules/osdu-service"

  service_name              = "crs-catalog"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/crs-catalog-service/cimpl-helm"
  chart                     = "core-plus-crs-catalog-deploy"
  chart_version             = lookup(var.osdu_service_versions, "crs_catalog", var.osdu_chart_version)
  enable                    = var.enable_crs_catalog
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_crs_catalog || var.enable_entitlements, error_message = "CRS Catalog requires Entitlements." },
    { condition = !var.enable_crs_catalog || var.enable_partition, error_message = "CRS Catalog requires Partition." },
  ]

  depends_on = [module.osdu_common, module.entitlements]
}

module "eds_dms" {
  source = "./modules/osdu-service"

  service_name              = "eds-dms"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/data-flow/enrichment/eds-dms/cimpl-helm"
  chart                     = "core-plus-eds-dms-deploy"
  chart_version             = lookup(var.osdu_service_versions, "eds_dms", var.osdu_chart_version)
  enable                    = var.enable_eds_dms
  enable_common             = var.enable_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !var.enable_eds_dms || var.enable_entitlements, error_message = "EDS-DMS requires Entitlements." },
    { condition = !var.enable_eds_dms || var.enable_partition, error_message = "EDS-DMS requires Partition." },
    { condition = !var.enable_eds_dms || var.enable_storage, error_message = "EDS-DMS requires Storage." },
  ]

  depends_on = [module.osdu_common, module.storage]
}
