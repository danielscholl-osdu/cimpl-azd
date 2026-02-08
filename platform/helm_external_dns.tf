# ExternalDNS for automatic DNS record management via Gateway API HTTPRoutes

resource "kubernetes_namespace" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  metadata {
    name = "external-dns"
    labels = {
      "istio.io/rev" = "asm-1-28"
    }
  }
}

resource "helm_release" "external_dns" {
  count            = var.enable_external_dns ? 1 : 0
  name             = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "external-dns"
  version          = "9.0.3"
  namespace        = kubernetes_namespace.external_dns[0].metadata[0].name
  create_namespace = false

  set = [
    # Azure DNS provider
    {
      name  = "provider"
      value = "azure"
    },
    # Watch Gateway API HTTPRoute hostnames
    {
      name  = "sources[0]"
      value = "gateway-httproute"
    },
    # Sync policy: create and delete DNS records
    {
      name  = "policy"
      value = "sync"
    },
    # Domain filter
    {
      name  = "domainFilters[0]"
      value = var.dns_zone_name
    },
    # TXT owner ID to prevent cross-cluster conflicts
    {
      name  = "txtOwnerId"
      value = var.cluster_name
    },
    # Azure configuration
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
      name  = "azure.useManagedIdentityExtension"
      value = "true"
    },
    # Workload Identity: ServiceAccount annotation
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = var.external_dns_client_id
    },
    # Workload Identity: Pod label
    {
      name  = "podLabels.azure\\.workload\\.identity/use"
      value = "true"
    },
    # Resource requests/limits for AKS Automatic safeguards compliance
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
