# ECK Operator (cluster-wide singleton)
resource "helm_release" "elastic_operator" {
  name             = "elastic-operator"
  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  version          = "3.3.0"
  namespace        = var.namespace
  create_namespace = false

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "150Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "1"
    },
    {
      name  = "resources.limits.memory"
      value = "1Gi"
    },
  ]

  postrender = {
    binary_path = "${path.module}/postrender.sh"
  }
}
