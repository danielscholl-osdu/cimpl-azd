# Elastic Bootstrap job for OSDU index initialization
resource "helm_release" "elastic_bootstrap" {
  count = var.enable_elasticsearch && var.enable_elastic_bootstrap ? 1 : 0

  name             = "elastic-bootstrap"
  repository       = "oci://community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/elastic-bootstrap/cimpl-helm"
  chart            = "elastic-bootstrap"
  version          = "0.0.7-latest"
  namespace        = "elasticsearch"
  create_namespace = false

  set = [
    {
      name  = "elasticsearch.image"
      value = "community.opengroup.org:5555/osdu/platform/deployment-and-operations/base-containers-cimpl/elastic-bootstrap/elastic-bootstrap:f72735fb"
    },
    {
      name  = "elasticsearch.host"
      value = "elasticsearch-es-http.elasticsearch.svc"
    },
    {
      name  = "elasticsearch.port"
      value = "9200"
    },
    {
      name  = "elasticsearch.protocol"
      value = "http"
    },
    {
      name  = "elasticsearch.username"
      value = "elastic"
    },
  ]

  postrender = {
    binary_path = "${path.module}/postrender-elastic-bootstrap.sh"
  }

  depends_on = [
    kubernetes_namespace.elasticsearch,
    kubectl_manifest.elasticsearch
  ]
}
