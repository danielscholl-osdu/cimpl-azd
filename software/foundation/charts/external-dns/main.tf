# ExternalDNS for automatic DNS record management via Gateway API HTTPRoutes
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "external-dns"
  version          = "9.0.3"
  namespace        = var.namespace
  create_namespace = false

  set = [
    {
      name  = "global.security.allowInsecureImages"
      value = "true"
    },
    {
      name  = "image.registry"
      value = "registry.k8s.io"
    },
    {
      name  = "image.repository"
      value = "external-dns/external-dns"
    },
    {
      name  = "image.tag"
      value = "v0.15.1"
    },
    {
      name  = "provider"
      value = "azure"
    },
    {
      name  = "sources[0]"
      value = "gateway-httproute"
    },
    {
      name  = "policy"
      value = "sync"
    },
    {
      name  = "domainFilters[0]"
      value = var.dns_zone_name
    },
    {
      name  = "txtOwnerId"
      value = var.cluster_name
    },
    {
      name  = "azure.resourceGroup"
      value = var.dns_zone_resource_group
    },
    {
      name  = "azure.subscriptionId"
      value = var.dns_zone_subscription_id
    },
    {
      name  = "azure.tenantId"
      value = var.tenant_id
    },
    {
      name  = "azure.useWorkloadIdentityExtension"
      value = "true"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = var.external_dns_client_id
    },
    {
      name  = "podLabels.azure\\.workload\\.identity/use"
      value = "true"
      type  = "string"
    },
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "resources.limits.memory"
      value = "128Mi"
    },
  ]
}
