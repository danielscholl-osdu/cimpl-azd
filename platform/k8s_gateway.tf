# Gateway API CRDs (required for Istio Gateway API support)
# Managed in Terraform state via local CRD file instead of remote kubectl apply
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

# Gateway for external HTTPS access (AKS-managed Istio)
# References the AKS Istio external ingress gateway service
resource "kubectl_manifest" "gateway" {
  count = var.enable_gateway ? 1 : 0

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
          hostname: "${var.kibana_hostname}"
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
  count = var.enable_gateway && var.enable_elasticsearch ? 1 : 0

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
        - "${var.kibana_hostname}"
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
  count = var.enable_gateway && var.enable_cert_manager ? 1 : 0

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
      commonName: "${var.kibana_hostname}"
      dnsNames:
        - "${var.kibana_hostname}"
      issuerRef:
        name: ${local.active_cluster_issuer}
        kind: ClusterIssuer
  YAML

  depends_on = [
    kubectl_manifest.cluster_issuer,
    kubectl_manifest.cluster_issuer_staging
  ]
}
