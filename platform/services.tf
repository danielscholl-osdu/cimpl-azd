# OSDU service deployments via reusable module
#
# Each service gets an explicit module call (not for_each) to allow
# per-service dependency control, extra_set overrides, and preconditions.

module "partition" {
  source = "./modules/osdu-service"

  service_name              = "partition"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/system/partition/cimpl-helm"
  chart                     = "core-plus-partition-deploy"
  enable                    = var.enable_partition
  enable_common             = var.enable_common
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  depends_on = [
    kubernetes_namespace.osdu,
    kubernetes_config_map.osdu_config,
    kubernetes_secret.osdu_credentials,
    kubernetes_secret.partition_postgres
  ]
}

module "entitlements" {
  source = "./modules/osdu-service"

  service_name              = "entitlements"
  repository                = "oci://community.opengroup.org:5555/osdu/platform/security-and-compliance/entitlements/cimpl-helm"
  chart                     = "core-plus-entitlements-deploy"
  enable                    = var.enable_entitlements
  enable_common             = var.enable_common
  osdu_domain               = local.osdu_domain
  cimpl_tenant              = var.cimpl_tenant
  cimpl_project             = var.cimpl_project
  subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  kustomize_path            = path.module

  extra_set = [
    {
      name  = "data.redisEntHost"
      value = "redis-master.redis.svc.cluster.local"
    }
  ]

  preconditions = [
    { condition = !var.enable_entitlements || var.enable_keycloak, error_message = "Entitlements requires Keycloak (enable_keycloak must be true when enable_entitlements is true)." },
    { condition = !var.enable_entitlements || var.enable_partition, error_message = "Entitlements requires the Partition service (enable_partition must be true when enable_entitlements is true)." },
    { condition = !var.enable_entitlements || var.enable_postgresql, error_message = "Entitlements requires PostgreSQL (enable_postgresql must be true when enable_entitlements is true)." },
    { condition = !var.enable_entitlements || var.enable_redis, error_message = "Entitlements requires Redis (enable_redis must be true when enable_entitlements is true)." },
  ]

  depends_on = [
    kubernetes_namespace.osdu,
    kubernetes_config_map.osdu_config,
    kubernetes_secret.osdu_credentials,
    kubernetes_secret.entitlements_postgres,
    kubernetes_secret.entitlements_redis,
    kubernetes_secret.datafier,
    module.partition,
    kubectl_manifest.keycloak_statefulset
  ]
}
