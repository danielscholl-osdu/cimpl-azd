# ─── Middleware modules ───────────────────────────────────────────────────────

module "elastic" {
  source = "./modules/elastic"
  count  = var.enable_elasticsearch ? 1 : 0

  namespace            = kubernetes_namespace_v1.platform.metadata[0].name
  enable_bootstrap     = var.enable_elastic_bootstrap
  kibana_hostname      = local.kibana_hostname
  has_ingress_hostname = local.has_ingress_hostname
}

module "postgresql" {
  source = "./modules/postgresql"
  count  = var.enable_postgresql ? 1 : 0

  namespace            = kubernetes_namespace_v1.platform.metadata[0].name
  postgresql_password  = var.postgresql_password
  postgresql_username  = var.postgresql_username
  keycloak_db_password = var.keycloak_db_password
  airflow_db_password  = var.airflow_db_password
  cimpl_tenant         = var.cimpl_tenant
}

module "redis" {
  source = "./modules/redis"
  count  = var.enable_redis ? 1 : 0

  namespace      = kubernetes_namespace_v1.platform.metadata[0].name
  redis_password = var.redis_password
}

module "rabbitmq" {
  source = "./modules/rabbitmq"
  count  = var.enable_rabbitmq ? 1 : 0

  namespace              = kubernetes_namespace_v1.platform.metadata[0].name
  rabbitmq_username      = var.rabbitmq_username
  rabbitmq_password      = var.rabbitmq_password
  rabbitmq_erlang_cookie = var.rabbitmq_erlang_cookie
}

module "minio" {
  source = "./modules/minio"
  count  = var.enable_minio ? 1 : 0

  namespace           = kubernetes_namespace_v1.platform.metadata[0].name
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
}

module "keycloak" {
  source = "./modules/keycloak"
  count  = var.enable_keycloak ? 1 : 0

  namespace               = kubernetes_namespace_v1.platform.metadata[0].name
  postgresql_host         = local.postgresql_host
  keycloak_db_password    = var.keycloak_db_password
  keycloak_admin_password = var.keycloak_admin_password
  datafier_client_secret  = var.datafier_client_secret
  osdu_namespace          = local.osdu_namespace

  depends_on = [module.postgresql]
}

module "airflow" {
  source = "./modules/airflow"
  count  = var.enable_airflow ? 1 : 0

  namespace           = kubernetes_namespace_v1.platform.metadata[0].name
  postgresql_host     = local.postgresql_host
  airflow_db_password = var.airflow_db_password

  depends_on = [module.postgresql]
}

module "gateway" {
  source = "./modules/gateway"
  count  = var.enable_gateway && var.enable_elasticsearch && local.has_ingress_hostname ? 1 : 0

  namespace             = kubernetes_namespace_v1.platform.metadata[0].name
  stack_label           = local.stack_label
  kibana_hostname       = local.kibana_hostname
  active_cluster_issuer = local.active_cluster_issuer
  enable_cert_manager   = var.enable_cert_manager

  depends_on = [module.elastic]
}
