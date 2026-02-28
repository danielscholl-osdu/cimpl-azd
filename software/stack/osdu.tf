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
  chart_version             = lookup(var.osdu_service_versions, "wellbore-worker", var.osdu_chart_version)
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
  chart_version             = lookup(var.osdu_service_versions, "crs-conversion", var.osdu_chart_version)
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
  chart_version             = lookup(var.osdu_service_versions, "crs-catalog", var.osdu_chart_version)
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
  chart_version             = lookup(var.osdu_service_versions, "eds-dms", var.osdu_chart_version)
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
