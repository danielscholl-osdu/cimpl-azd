# Derive ingress hostnames from prefix + DNS zone
# Pattern: {prefix}-{service}.{dns_zone}  e.g. a3kf9x2m-kibana.developer.msft-osdu-test.org
# Gateway API CRDs (required for Istio Gateway API support)
# Managed in Terraform state via local CRD file instead of remote kubectl apply
locals {
  kibana_hostname      = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}-kibana.${var.dns_zone_name}" : ""
  has_ingress_hostname = local.kibana_hostname != ""
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

# Ensure the AKS-managed Istio ingress gateway service uses a public LoadBalancer.
# AKS Automatic may default to internal LBs; this annotation overrides that.
resource "kubernetes_annotations" "istio_gateway_public" {
  count       = var.enable_gateway ? 1 : 0
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "aks-istio-ingressgateway-external"
    namespace = "aks-istio-ingress"
  }
  annotations = {
    "service.beta.kubernetes.io/azure-load-balancer-internal" = "false"
  }
  force = true
}

# Gateway for external HTTPS access (AKS-managed Istio)
# References the AKS Istio external ingress gateway service
resource "kubectl_manifest" "gateway" {
  count = var.enable_gateway && local.has_ingress_hostname ? 1 : 0

  yaml_body = <<-YAML
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
        - name: https
          protocol: HTTPS
          port: 443
          hostname: "${local.kibana_hostname}"
          tls:
            mode: Terminate
            certificateRefs:
              - kind: Secret
                name: kibana-tls
                namespace: aks-istio-ingress
          allowedRoutes:
            namespaces:
              from: All
  YAML

  depends_on = [kubectl_manifest.gateway_api_crds]
}

# HTTPRoute for Kibana
resource "kubectl_manifest" "kibana_route" {
  count = var.enable_gateway && var.enable_elasticsearch && local.has_ingress_hostname ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: kibana-route
      namespace: aks-istio-ingress
    spec:
      parentRefs:
        - name: istio
          namespace: aks-istio-ingress
      hostnames:
        - "${local.kibana_hostname}"
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: kibana-kb-http
              namespace: elastic-search
              port: 5601
  YAML

  depends_on = [
    kubectl_manifest.gateway,
    kubectl_manifest.kibana
  ]
}

# ReferenceGrant to allow HTTPRoute in aks-istio-ingress to reference Service in elastic-search
resource "kubectl_manifest" "kibana_reference_grant" {
  count = var.enable_gateway && var.enable_elasticsearch ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: ReferenceGrant
    metadata:
      name: allow-istio-ingress
      namespace: elastic-search
    spec:
      from:
        - group: gateway.networking.k8s.io
          kind: HTTPRoute
          namespace: aks-istio-ingress
      to:
        - group: ""
          kind: Service
          name: kibana-kb-http
  YAML

  depends_on = [
    kubectl_manifest.gateway_api_crds,
    kubernetes_namespace.elastic_search,
    kubectl_manifest.kibana
  ]
}

# TLS Certificate for Kibana (in aks-istio-ingress namespace)
resource "kubectl_manifest" "kibana_certificate" {
  count = var.enable_gateway && var.enable_cert_manager && local.has_ingress_hostname ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: kibana-tls
      namespace: aks-istio-ingress
    spec:
      secretName: kibana-tls
      duration: 2160h
      renewBefore: 360h
      commonName: "${local.kibana_hostname}"
      dnsNames:
        - "${local.kibana_hostname}"
      issuerRef:
        name: ${local.active_cluster_issuer}
        kind: ClusterIssuer
  YAML

  depends_on = [
    kubectl_manifest.cluster_issuer,
    kubectl_manifest.cluster_issuer_staging
  ]
}
