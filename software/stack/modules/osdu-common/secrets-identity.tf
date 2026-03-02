# Keycloak/OpenID and KMS identity secrets

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

resource "kubernetes_secret" "storage_keycloak" {
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

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "file_keycloak" {
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

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "notification_keycloak" {
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

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "register_keycloak" {
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

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "register_kms" {
  count = var.enable_register ? 1 : 0

  metadata {
    name      = "register-kms-secret"
    namespace = var.namespace
  }

  data = {
    ENCRYPTION_KEY = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "indexer_keycloak" {
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

  depends_on = [kubernetes_namespace.osdu]
}
