# Foundation Layer - Cluster-wide shared components (singletons)
#
# Deploys shared components that all stacks depend on:
# - cert-manager for TLS certificate management
# - ECK operator for Elasticsearch
# - CNPG operator for PostgreSQL
# - ExternalDNS for DNS record management
# - Gateway API CRDs and base Gateway resource
# - Shared StorageClasses
#
# Prerequisites:
# - AKS cluster must be provisioned (Layer 1: infra/)
# - kubeconfig must be configured

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "cimpl-foundation"
  }
}

# Shared namespace for foundation components
resource "kubernetes_namespace" "platform" {
  metadata {
    name = "foundation"
  }
}


# ---------------------------------------------------------------------------
# Charts — each chart is a self-contained sub-module
# ---------------------------------------------------------------------------

module "cert_manager" {
  source = "./charts/cert-manager"
  count  = var.enable_cert_manager ? 1 : 0

  namespace                  = kubernetes_namespace.platform.metadata[0].name
  acme_email                 = var.acme_email
  use_letsencrypt_production = var.use_letsencrypt_production
}

module "cnpg" {
  source = "./charts/cnpg"
  count  = var.enable_postgresql ? 1 : 0

  namespace = kubernetes_namespace.platform.metadata[0].name
}

module "elastic" {
  source = "./charts/elastic"
  count  = var.enable_elasticsearch ? 1 : 0

  namespace = kubernetes_namespace.platform.metadata[0].name
}

module "external_dns" {
  source = "./charts/external-dns"
  count  = var.enable_external_dns ? 1 : 0

  namespace                = kubernetes_namespace.platform.metadata[0].name
  cluster_name             = var.cluster_name
  dns_zone_name            = var.dns_zone_name
  dns_zone_resource_group  = var.dns_zone_resource_group
  dns_zone_subscription_id = var.dns_zone_subscription_id
  tenant_id                = var.tenant_id
  external_dns_client_id   = var.external_dns_client_id
}


# ---------------------------------------------------------------------------
# Gateway API — CRDs and base Gateway resource
# ---------------------------------------------------------------------------

locals {
  gateway_api_crd_file = "${path.module}/crds/gateway-api-v1.2.1.yaml"
  gateway_api_crds = [
    for doc in split("---", file(local.gateway_api_crd_file)) :
    doc if trimspace(doc) != "" && can(yamldecode(doc))
  ]
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = var.enable_gateway ? { for doc in local.gateway_api_crds : yamldecode(doc).metadata.name => doc } : {}

  yaml_body         = each.value
  wait              = true
  server_side_apply = true
}

# Ensure the AKS-managed Istio ingress gateway service uses the desired LoadBalancer type
resource "null_resource" "istio_gateway_public" {
  count = var.enable_gateway ? 1 : 0

  triggers = {
    internal = var.enable_public_ingress ? "false" : "true"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      kubectl annotate svc aks-istio-ingressgateway-external \
        -n aks-istio-ingress \
        --as=system:admin --as-group=system:masters \
        --overwrite \
        service.beta.kubernetes.io/azure-load-balancer-internal=${var.enable_public_ingress ? "false" : "true"}
    EOT
  }
}

# Base Gateway with HTTP listener only — stacks add HTTPS listeners
resource "null_resource" "gateway" {
  count = var.enable_gateway ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'YAML' | kubectl apply --as=system:admin --as-group=system:masters -f -
      apiVersion: gateway.networking.k8s.io/v1
      kind: Gateway
      metadata:
        name: istio
        namespace: aks-istio-ingress
      spec:
        gatewayClassName: istio
        addresses:
          - value: aks-istio-ingressgateway-external
            type: Hostname
        listeners:
          - name: http
            protocol: HTTP
            port: 80
            allowedRoutes:
              namespaces:
                from: All
      YAML
    EOT
  }

  depends_on = [kubectl_manifest.gateway_api_crds]
}


# ---------------------------------------------------------------------------
# Storage Classes — shared across all stacks
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "pg_storage_class" {
  count     = var.enable_postgresql ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: pg-storageclass
      labels:
        app: postgresql
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}

resource "kubectl_manifest" "elastic_storage_class" {
  count     = var.enable_elasticsearch ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: es-storageclass
      labels:
        app: elasticsearch
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
      tags: costcenter=dev,app=elasticsearch
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}

resource "kubectl_manifest" "redis_storage_class" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: redis-storageclass
      labels:
        app: redis
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}

resource "kubectl_manifest" "rabbitmq_storage_class" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: rabbitmq-storageclass
      labels:
        app: rabbitmq
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}
