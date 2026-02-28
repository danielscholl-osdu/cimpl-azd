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
