# Gateway API CRDs (required for Istio Gateway API support)
# AKS-managed Istio may not install these by default
resource "kubectl_manifest" "gateway_api_crds" {
  count = var.enable_gateway ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: gateway-system
      labels:
        app.kubernetes.io/name: gateway-api
  YAML
}

# Install Gateway API standard CRDs
resource "null_resource" "gateway_api_crds" {
  count = var.enable_gateway ? 1 : 0

  triggers = {
    gateway_api_version = "v1.2.1"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${self.triggers.gateway_api_version}/standard-install.yaml"
  }
}

# Wait for Gateway API CRDs to be fully established
resource "null_resource" "gateway_api_crds_wait" {
  count = var.enable_gateway ? 1 : 0

  triggers = {
    gateway_api_version = "v1.2.1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for condition=Established --timeout=120s \
        crd/gatewayclasses.gateway.networking.k8s.io \
        crd/gateways.gateway.networking.k8s.io \
        crd/httproutes.gateway.networking.k8s.io \
        crd/grpcroutes.gateway.networking.k8s.io \
        crd/referencegrants.gateway.networking.k8s.io
    EOT
  }

  depends_on = [null_resource.gateway_api_crds]
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

  depends_on = [null_resource.gateway_api_crds_wait]
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
    null_resource.gateway_api_crds_wait,
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
        name: letsencrypt-prod
        kind: ClusterIssuer
  YAML

  depends_on = [kubectl_manifest.cluster_issuer]
}
