# Elastic bootstrap resources (per-stack)

resource "kubernetes_service_account" "elastic_bootstrap" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  metadata {
    name      = "bootstrap-sa"
    namespace = local.platform_namespace
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "time_sleep" "wait_for_eck_reconciliation" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  depends_on      = [kubectl_manifest.elasticsearch]
  create_duration = "60s"
}

data "kubernetes_secret" "elasticsearch_password" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  metadata {
    name      = "elasticsearch-es-elastic-user"
    namespace = local.platform_namespace
  }

  depends_on = [time_sleep.wait_for_eck_reconciliation]
}

resource "kubernetes_secret" "elastic_bootstrap_secret" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  metadata {
    name      = "elastic-bootstrap-secret"
    namespace = local.platform_namespace
  }

  data = {
    ELASTIC_HOST_SYSTEM = "elasticsearch-es-http.${local.platform_namespace}.svc"
    ELASTIC_PORT_SYSTEM = "9200"
    ELASTIC_USER_SYSTEM = "elastic"
    ELASTIC_PASS_SYSTEM = data.kubernetes_secret.elasticsearch_password[0].data["elastic"]
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubernetes_secret" "indexer_elastic_secret" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  metadata {
    name      = "indexer-elastic-secret"
    namespace = local.platform_namespace
  }

  data = {
    ELASTIC_USER_SYSTEM = "elastic"
    ELASTIC_PASS_SYSTEM = data.kubernetes_secret.elasticsearch_password[0].data["elastic"]
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubernetes_secret" "search_elastic_secret" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  metadata {
    name      = "search-elastic-secret"
    namespace = local.platform_namespace
  }

  data = {
    ELASTIC_USER_SYSTEM = "elastic"
    ELASTIC_PASS_SYSTEM = data.kubernetes_secret.elasticsearch_password[0].data["elastic"]
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "helm_release" "elastic_bootstrap" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  name             = "elastic-bootstrap"
  repository       = "oci://community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/elastic-bootstrap/cimpl-helm"
  chart            = "elastic-bootstrap"
  version          = "0.0.7-latest"
  namespace        = local.platform_namespace
  create_namespace = false

  set = [
    {
      name  = "elasticsearch.image"
      value = "community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/elastic-bootstrap/elastic-bootstrap:f72735fb"
    },
    {
      name  = "elasticsearch.host"
      value = "elasticsearch-es-http.${local.platform_namespace}.svc"
    },
    {
      name  = "elasticsearch.port"
      value = "9200"
    },
    {
      name  = "elasticsearch.protocol"
      value = "https"
    },
    {
      name  = "elasticsearch.username"
      value = "elastic"
    },
  ]

  postrender = {
    binary_path = "${var.kustomize_path}/postrender-elastic-bootstrap.sh"
  }

  depends_on = [
    kubernetes_namespace.platform,
    kubectl_manifest.elasticsearch,
    kubernetes_service_account.elastic_bootstrap,
    kubernetes_secret.elastic_bootstrap_secret,
    kubernetes_secret.indexer_elastic_secret,
    kubernetes_secret.search_elastic_secret
  ]
}
