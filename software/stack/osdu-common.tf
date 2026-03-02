# OSDU common namespace resources (secrets, configmaps, service accounts)

module "osdu_common" {
  source = "./modules/osdu-common"
  count  = var.enable_common ? 1 : 0

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
  enable_search                   = var.enable_search
  enable_indexer                  = var.enable_indexer
  enable_partition                = var.enable_partition
  enable_entitlements             = var.enable_entitlements
  enable_legal                    = var.enable_legal
  enable_schema                   = var.enable_schema
  enable_storage                  = var.enable_storage
  enable_file                     = var.enable_file
  enable_dataset                  = var.enable_dataset
  enable_register                 = var.enable_register
  enable_notification             = var.enable_notification
  enable_policy                   = var.enable_policy
  enable_workflow                 = var.enable_workflow
  enable_wellbore                 = var.enable_wellbore
}
