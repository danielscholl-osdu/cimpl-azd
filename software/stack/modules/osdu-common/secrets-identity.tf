# Keycloak/OpenID and KMS identity secrets

resource "kubernetes_secret_v1" "datafier" {
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

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "storage_keycloak" {
  count = var.enable_storage ? 1 : 0

  metadata {
    name      = "storage-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "file_keycloak" {
  count = var.enable_file ? 1 : 0

  metadata {
    name      = "file-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "notification_keycloak" {
  count = var.enable_notification ? 1 : 0

  metadata {
    name      = "notification-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "register_keycloak" {
  count = var.enable_register ? 1 : 0

  metadata {
    name      = "register-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "register_kms" {
  count = var.enable_register ? 1 : 0

  metadata {
    name      = "register-kms-secret"
    namespace = var.namespace
  }

  data = {
    ENCRYPTION_KEY = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "workflow_keycloak" {
  count = var.enable_workflow ? 1 : 0

  metadata {
    name      = "workflow-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "indexer_keycloak" {
  count = var.enable_indexer ? 1 : 0

  metadata {
    name      = "indexer-keycloak-secret"
    namespace = var.namespace
  }

  data = {
    OPENID_PROVIDER_CLIENT_ID     = "datafier"
    OPENID_PROVIDER_CLIENT_SECRET = var.datafier_client_secret
    OPENID_PROVIDER_URL           = "http://${var.keycloak_host}:8080/realms/osdu"
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

# State migration: renamed deprecated types to _v1 equivalents
moved {
  from = kubernetes_secret.datafier
  to   = kubernetes_secret_v1.datafier
}

moved {
  from = kubernetes_secret.storage_keycloak
  to   = kubernetes_secret_v1.storage_keycloak
}

moved {
  from = kubernetes_secret.file_keycloak
  to   = kubernetes_secret_v1.file_keycloak
}

moved {
  from = kubernetes_secret.notification_keycloak
  to   = kubernetes_secret_v1.notification_keycloak
}

moved {
  from = kubernetes_secret.register_keycloak
  to   = kubernetes_secret_v1.register_keycloak
}

moved {
  from = kubernetes_secret.register_kms
  to   = kubernetes_secret_v1.register_kms
}

moved {
  from = kubernetes_secret.indexer_keycloak
  to   = kubernetes_secret_v1.indexer_keycloak
}
