# OSDU reference systems service deployments
# Ref: https://community.opengroup.org/osdu/platform

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
