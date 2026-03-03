# OSDU namespace, ConfigMap, credentials, and service account

resource "kubernetes_namespace_v1" "osdu" {
  metadata {
    name = var.namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_config_map_v1" "osdu_config" {
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

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_secret_v1" "osdu_credentials" {
  metadata {
    name      = "osdu-credentials"
    namespace = var.namespace
  }

  data = {
    cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

resource "kubernetes_service_account_v1" "bootstrap" {
  metadata {
    name      = "bootstrap-sa"
    namespace = var.namespace
  }

  depends_on = [kubernetes_namespace_v1.osdu]
}

# State migration: renamed deprecated types to _v1 equivalents
moved {
  from = kubernetes_namespace.osdu
  to   = kubernetes_namespace_v1.osdu
}

moved {
  from = kubernetes_config_map.osdu_config
  to   = kubernetes_config_map_v1.osdu_config
}

moved {
  from = kubernetes_secret.osdu_credentials
  to   = kubernetes_secret_v1.osdu_credentials
}

moved {
  from = kubernetes_service_account.bootstrap
  to   = kubernetes_service_account_v1.bootstrap
}
