# OSDU domain data management and external data service deployments
# Ref: https://community.opengroup.org/osdu/platform

module "wellbore" {
  source = "./modules/osdu-service"

  service_name              = "wellbore"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/cimpl-helm"
  chart                     = "core-plus-wellbore-deploy"
  chart_version             = lookup(var.osdu_service_versions, "wellbore", var.osdu_chart_version)
  enable                    = local.deploy_wellbore
  enable_common             = local.deploy_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !local.deploy_wellbore || local.deploy_entitlements, error_message = "Wellbore requires Entitlements." },
    { condition = !local.deploy_wellbore || local.deploy_partition, error_message = "Wellbore requires Partition." },
    { condition = !local.deploy_wellbore || local.deploy_storage, error_message = "Wellbore requires Storage." },
    { condition = !local.deploy_wellbore || var.enable_postgresql, error_message = "Wellbore requires PostgreSQL." },
  ]

  depends_on = [module.osdu_common, module.storage]
}

module "wellbore_worker" {
  source = "./modules/osdu-service"

  service_name              = "wellbore-worker"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/wellbore/cimpl-helm"
  chart                     = "core-plus-wellbore-worker-deploy"
  chart_version             = lookup(var.osdu_service_versions, "wellbore_worker", var.osdu_chart_version)
  enable                    = local.deploy_wellbore_worker
  enable_common             = local.deploy_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !local.deploy_wellbore_worker || local.deploy_entitlements, error_message = "Wellbore Worker requires Entitlements." },
    { condition = !local.deploy_wellbore_worker || local.deploy_partition, error_message = "Wellbore Worker requires Partition." },
    { condition = !local.deploy_wellbore_worker || local.deploy_wellbore, error_message = "Wellbore Worker requires Wellbore." },
  ]

  depends_on = [module.osdu_common, module.wellbore]
}

module "eds_dms" {
  source = "./modules/osdu-service"

  service_name              = "eds-dms"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/data-flow/enrichment/eds-dms/cimpl-helm"
  chart                     = "core-plus-eds-dms-deploy"
  chart_version             = lookup(var.osdu_service_versions, "eds_dms", var.osdu_chart_version)
  enable                    = local.deploy_eds_dms
  enable_common             = local.deploy_common
  namespace                 = local.osdu_namespace
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  preconditions = [
    { condition = !local.deploy_eds_dms || local.deploy_entitlements, error_message = "EDS-DMS requires Entitlements." },
    { condition = !local.deploy_eds_dms || local.deploy_partition, error_message = "EDS-DMS requires Partition." },
    { condition = !local.deploy_eds_dms || local.deploy_storage, error_message = "EDS-DMS requires Storage." },
  ]

  depends_on = [module.osdu_common, module.storage]
}
