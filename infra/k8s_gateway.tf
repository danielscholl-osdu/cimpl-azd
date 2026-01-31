# Gateway API CRDs (required for Istio Gateway API support)
# AKS-managed Istio may not install these by default
resource "kubectl_manifest" "gateway_api_crds" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: gateway-system
      labels:
        app.kubernetes.io/name: gateway-api
  YAML

  depends_on = [module.aks]
}

# Install Gateway API standard CRDs
resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml"
  }

  depends_on = [module.aks]
}

# Gateway for external HTTPS access (AKS-managed Istio)
# References the AKS Istio external ingress gateway service
resource "kubectl_manifest" "gateway" {
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

  depends_on = [
    module.aks,
    null_resource.gateway_api_crds
  ]
}

# HTTPRoute for Kibana
resource "kubectl_manifest" "kibana_route" {
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
    kubernetes_namespace.elastic_search,
    kubectl_manifest.kibana
  ]
}

# TLS Certificate for Kibana (in aks-istio-ingress namespace)
resource "kubectl_manifest" "kibana_certificate" {
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
        name: letsencrypt-prod
        kind: ClusterIssuer
  YAML

  depends_on = [kubectl_manifest.cluster_issuer]
}
