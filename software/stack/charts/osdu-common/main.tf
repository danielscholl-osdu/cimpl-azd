# OSDU namespace resources: namespace, ConfigMap, secrets, service account, mTLS

resource "kubernetes_namespace" "osdu" {
  metadata {
    name = var.namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_config_map" "osdu_config" {
  metadata {
    name      = "osdu-config"
    namespace = var.namespace
  }

  data = {
    domain        = var.osdu_domain
    cimpl_project = var.cimpl_project
    cimpl_tenant  = var.cimpl_tenant
  }

  lifecycle {
    precondition {
      condition     = var.osdu_domain != ""
      error_message = "osdu-config: domain must be non-empty when enable_common is true."
    }
    precondition {
      condition     = var.cimpl_tenant != ""
      error_message = "osdu-config: cimpl_tenant must be non-empty when enable_common is true."
    }
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "osdu_credentials" {
  metadata {
    name      = "osdu-credentials"
    namespace = var.namespace
  }

  data = {
    cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_service_account" "bootstrap" {
  metadata {
    name      = "bootstrap-sa"
    namespace = var.namespace
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "partition_postgres" {
  count = var.enable_partition ? 1 : 0

  metadata {
    name      = "partition-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL           = "jdbc:postgresql://${var.postgresql_host}:5432/partition"
    OSM_POSTGRES_USERNAME      = var.postgresql_username
    OSM_POSTGRES_PASSWORD      = var.postgresql_password
    PARTITION_POSTGRES_DB_NAME = "partition"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_postgres" {
  count = var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-multi-tenant-postgres-secret"
    namespace = var.namespace
  }

  data = {
    ENT_PG_URL_SYSTEM          = "jdbc:postgresql://${var.postgresql_host}:5432/entitlements"
    ENT_PG_USER_SYSTEM         = var.postgresql_username
    ENT_PG_PASS_SYSTEM         = var.postgresql_password
    ENT_PG_SCHEMA_OSDU         = "entitlements"
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/entitlements"
    SPRING_DATASOURCE_USERNAME = var.postgresql_username
    SPRING_DATASOURCE_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "legal_postgres" {
  count = var.enable_legal ? 1 : 0

  metadata {
    name      = "legal-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/legal"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "schema_postgres" {
  count = var.enable_schema ? 1 : 0

  metadata {
    name      = "schema-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/schema"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "storage_postgres" {
  count = var.enable_storage ? 1 : 0

  metadata {
    name      = "storage-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/storage"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "file_postgres" {
  count = var.enable_file ? 1 : 0

  metadata {
    name      = "file-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/file"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "dataset_postgres" {
  count = var.enable_dataset ? 1 : 0

  metadata {
    name      = "dataset-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/dataset"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "register_postgres" {
  count = var.enable_register ? 1 : 0

  metadata {
    name      = "register-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/register"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "workflow_postgres" {
  count = var.enable_workflow ? 1 : 0

  metadata {
    name      = "workflow-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/workflow"
    OSM_POSTGRES_USERNAME = var.postgresql_username
    OSM_POSTGRES_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "datafier" {
  count = var.enable_entitlements ? 1 : 0

  metadata {
    name      = "datafier-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_redis" {
  count = var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubectl_manifest" "osdu_peer_authentication" {
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: osdu-strict-mtls
      namespace: ${var.namespace}
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.osdu]
}
