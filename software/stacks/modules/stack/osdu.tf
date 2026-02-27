# OSDU namespace resources and service deployments (per-stack)

resource "kubernetes_namespace" "osdu" {
  count = var.enable_common ? 1 : 0

  metadata {
    name = local.osdu_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_config_map" "osdu_config" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "osdu-config"
    namespace = local.osdu_namespace
  }

  data = {
    domain        = local.osdu_domain
    cimpl_project = var.cimpl_project
    cimpl_tenant  = var.cimpl_tenant
  }

  lifecycle {
    precondition {
      condition     = !var.enable_common || local.osdu_domain != ""
      error_message = "osdu-config: domain must be non-empty when enable_common is true."
    }
    precondition {
      condition     = !var.enable_common || var.cimpl_tenant != ""
      error_message = "osdu-config: cimpl_tenant must be non-empty when enable_common is true."
    }
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "osdu_credentials" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "osdu-credentials"
    namespace = local.osdu_namespace
  }

  data = {
    cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_service_account" "bootstrap" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "bootstrap-sa"
    namespace = local.osdu_namespace
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "partition_postgres" {
  count = var.enable_common && var.enable_partition ? 1 : 0

  metadata {
    name      = "partition-postgres-secret"
    namespace = local.osdu_namespace
  }

  data = {
    OSM_POSTGRES_URL           = "jdbc:postgresql://${local.postgresql_host}:5432/partition"
    OSM_POSTGRES_USERNAME      = var.postgresql_username
    OSM_POSTGRES_PASSWORD      = var.postgresql_password
    PARTITION_POSTGRES_DB_NAME = "partition"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_postgres" {
  count = var.enable_common && var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-multi-tenant-postgres-secret"
    namespace = local.osdu_namespace
  }

  data = {
    ENT_PG_URL_SYSTEM          = "jdbc:postgresql://${local.postgresql_host}:5432/entitlements"
    ENT_PG_USER_SYSTEM         = var.postgresql_username
    ENT_PG_PASS_SYSTEM         = var.postgresql_password
    ENT_PG_SCHEMA_OSDU         = "entitlements"
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${local.postgresql_host}:5432/entitlements"
    SPRING_DATASOURCE_USERNAME = var.postgresql_username
    SPRING_DATASOURCE_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "datafier" {
  count = var.enable_common && var.enable_entitlements ? 1 : 0

  metadata {
    name      = "datafier-secret"
    namespace = local.osdu_namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${local.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_redis" {
  count = var.enable_common && var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-redis-secret"
    namespace = local.osdu_namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubectl_manifest" "osdu_peer_authentication" {
  count = var.enable_common ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: osdu-strict-mtls
      namespace: ${local.osdu_namespace}
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.osdu]
}

# OSDU service deployments
module "partition" {
  source = "../osdu-service"

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
  kustomize_path            = var.kustomize_path

  depends_on = [
    kubernetes_namespace.osdu,
    kubernetes_config_map.osdu_config,
    kubernetes_secret.osdu_credentials,
    kubernetes_secret.partition_postgres
  ]
}

module "entitlements" {
  source = "../osdu-service"

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
  kustomize_path            = var.kustomize_path

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
