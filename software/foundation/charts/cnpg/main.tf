# CloudNativePG Operator (cluster-wide singleton)
resource "helm_release" "cnpg_operator" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.27.1"
  namespace        = var.namespace
  create_namespace = false

  set = [
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "1"
    },
    {
      name  = "resources.limits.memory"
      value = "512Mi"
    },
  ]
}
