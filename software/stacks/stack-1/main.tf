# Stack 1 — Default stack instance
#
# Calls the shared stack module with stack_id = "1"
# Produces namespaces: platform-1, osdu-1
# Karpenter NodePool: stack-1

module "stack" {
  source = "../modules/stack"

  stack_id        = "1"
  kubeconfig_path = var.kubeconfig_path

  # Feature flags
  enable_elasticsearch     = var.enable_elasticsearch
  enable_elastic_bootstrap = var.enable_elastic_bootstrap
  enable_postgresql        = var.enable_postgresql
  enable_minio             = var.enable_minio
  enable_redis             = var.enable_redis
  enable_rabbitmq          = var.enable_rabbitmq
  enable_keycloak          = var.enable_keycloak
  enable_airflow           = var.enable_airflow
  enable_gateway           = var.enable_gateway
  enable_common            = var.enable_common
  enable_partition         = var.enable_partition
  enable_entitlements      = var.enable_entitlements
  enable_nodepool          = var.enable_stateful_nodepool
  enable_cert_manager      = var.enable_cert_manager

  # Ingress / DNS
  ingress_prefix             = var.ingress_prefix
  dns_zone_name              = var.dns_zone_name
  use_letsencrypt_production = var.use_letsencrypt_production

  # Credentials
  postgresql_password     = var.postgresql_password
  postgresql_username     = var.postgresql_username
  keycloak_db_password    = var.keycloak_db_password
  keycloak_admin_password = var.keycloak_admin_password
  datafier_client_secret  = var.datafier_client_secret
  airflow_db_password     = var.airflow_db_password
  redis_password          = var.redis_password
  rabbitmq_username       = var.rabbitmq_username
  rabbitmq_password       = var.rabbitmq_password
  rabbitmq_erlang_cookie  = var.rabbitmq_erlang_cookie
  minio_root_user         = var.minio_root_user
  minio_root_password     = var.minio_root_password

  # OSDU config
  cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  cimpl_project                   = var.cimpl_project
  cimpl_tenant                    = var.cimpl_tenant

  # Postrender path
  kustomize_path = path.module

  # OSDU versions
  osdu_chart_version    = var.osdu_chart_version
  osdu_service_versions = var.osdu_service_versions
}
