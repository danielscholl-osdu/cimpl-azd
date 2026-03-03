# OSDU common namespace resources (secrets, configmaps, service accounts)

module "osdu_common" {
  source = "./modules/osdu-common"
  count  = local.deploy_common ? 1 : 0

  namespace                       = local.osdu_namespace
  platform_namespace              = local.platform_namespace
  osdu_domain                     = local.osdu_domain
  cimpl_project                   = var.cimpl_project
  cimpl_tenant                    = var.cimpl_tenant
  cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  postgresql_host                 = local.postgresql_host
  postgresql_username             = var.postgresql_username
  postgresql_password             = var.postgresql_password
  keycloak_host                   = local.keycloak_host
  redis_password                  = var.redis_password
  datafier_client_secret          = var.datafier_client_secret
  minio_root_user                 = var.minio_root_user
  minio_root_password             = var.minio_root_password
  rabbitmq_username               = var.rabbitmq_username
  rabbitmq_password               = var.rabbitmq_password
  elastic_password                = var.enable_elasticsearch && var.enable_elastic_bootstrap ? module.elastic[0].elastic_password : ""
  elastic_host                    = "elasticsearch-es-http.${local.platform_namespace}.svc.cluster.local"
  enable_search                   = local.deploy_search
  enable_indexer                  = local.deploy_indexer
  enable_partition                = local.deploy_partition
  enable_entitlements             = local.deploy_entitlements
  enable_legal                    = local.deploy_legal
  enable_schema                   = local.deploy_schema
  enable_storage                  = local.deploy_storage
  enable_file                     = local.deploy_file
  enable_dataset                  = local.deploy_dataset
  enable_register                 = local.deploy_register
  enable_notification             = local.deploy_notification
  enable_policy                   = local.deploy_policy
  enable_workflow                 = local.deploy_workflow
  enable_wellbore                 = local.deploy_wellbore
}
