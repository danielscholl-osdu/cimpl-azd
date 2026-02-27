# OSDU namespace resources — namespace, ConfigMap, secrets, ServiceAccount, PeerAuthentication
# Replaces ROSA common-infra-bootstrap chart.
locals {
  osdu_domain = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}.${var.dns_zone_name}" : ""
}

resource "kubernetes_namespace" "osdu" {
  count = var.enable_common ? 1 : 0

  metadata {
    name = "osdu"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_config_map" "osdu_config" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "osdu-config"
    namespace = "osdu"
  }

  data = {
    domain        = local.osdu_domain
    cimpl_project = var.cimpl_project
    cimpl_tenant  = var.cimpl_tenant
  }

  lifecycle {
    precondition {
      condition     = !var.enable_common || local.osdu_domain != ""
      error_message = "osdu-config: domain must be non-empty when enable_common is true. Ensure ingress_prefix and dns_zone_name are set."
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
    namespace = "osdu"
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
    namespace = "osdu"
  }

  depends_on = [kubernetes_namespace.osdu]
}

# Per-service PostgreSQL secrets
# OSDU services expect a secret with DB connection details injected via envFrom.
# Our CNPG cluster runs in the postgresql namespace; these secrets bridge to osdu namespace.
resource "kubernetes_secret" "partition_postgres" {
  count = var.enable_common && var.enable_partition ? 1 : 0

  metadata {
    name      = "partition-postgres-secret"
    namespace = "osdu"
  }

  data = {
    OSM_POSTGRES_URL           = "jdbc:postgresql://postgresql-rw.postgresql.svc.cluster.local:5432/partition"
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
    namespace = "osdu"
  }

  data = {
    ENT_PG_URL_SYSTEM          = "jdbc:postgresql://postgresql-rw.postgresql.svc.cluster.local:5432/entitlements"
    ENT_PG_USER_SYSTEM         = var.postgresql_username
    ENT_PG_PASS_SYSTEM         = var.postgresql_password
    ENT_PG_SCHEMA_OSDU         = "entitlements"
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://postgresql-rw.postgresql.svc.cluster.local:5432/entitlements"
    SPRING_DATASOURCE_USERNAME = var.postgresql_username
    SPRING_DATASOURCE_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "datafier" {
  count = var.enable_common && var.enable_entitlements ? 1 : 0

  metadata {
    name      = "datafier-secret"
    namespace = "osdu"
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://keycloak.keycloak.svc.cluster.local:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_redis" {
  count = var.enable_common && var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-redis-secret"
    namespace = "osdu"
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
      namespace: osdu
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.osdu]
}
