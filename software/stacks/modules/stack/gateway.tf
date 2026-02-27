# Stack-specific Gateway listeners, HTTPRoutes, and TLS Certificates

# Add HTTPS listener to the shared Gateway for this stack's Kibana
resource "null_resource" "gateway_https_listener" {
  count = var.enable_gateway && var.enable_elasticsearch && local.has_ingress_hostname ? 1 : 0

  triggers = {
    kibana_hostname = local.kibana_hostname
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
          - name: https-stack-${var.stack_id}
            protocol: HTTPS
            port: 443
            hostname: "${local.kibana_hostname}"
            tls:
              mode: Terminate
              certificateRefs:
                - kind: Secret
                  name: kibana-tls-stack-${var.stack_id}
                  namespace: aks-istio-ingress
            allowedRoutes:
              namespaces:
                from: All
      YAML
    EOT
  }
}

# HTTPRoute for Kibana
resource "null_resource" "kibana_route" {
  count = var.enable_gateway && var.enable_elasticsearch && local.has_ingress_hostname ? 1 : 0

  triggers = {
    kibana_hostname = local.kibana_hostname
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'YAML' | kubectl apply --as=system:admin --as-group=system:masters -f -
      apiVersion: gateway.networking.k8s.io/v1
      kind: HTTPRoute
      metadata:
        name: kibana-route-stack-${var.stack_id}
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
                namespace: ${local.platform_namespace}
                port: 5601
      YAML
    EOT
  }

  depends_on = [
    null_resource.gateway_https_listener,
    kubectl_manifest.kibana
  ]
}

# ReferenceGrant for cross-namespace service access
resource "kubectl_manifest" "kibana_reference_grant" {
  count = var.enable_gateway && var.enable_elasticsearch ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: ReferenceGrant
    metadata:
      name: allow-istio-ingress-stack-${var.stack_id}
      namespace: ${local.platform_namespace}
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
    kubernetes_namespace.platform,
    kubectl_manifest.kibana
  ]
}

# TLS Certificate
resource "null_resource" "kibana_certificate" {
  count = var.enable_gateway && var.enable_cert_manager && local.has_ingress_hostname ? 1 : 0

  triggers = {
    kibana_hostname = local.kibana_hostname
    cluster_issuer  = local.active_cluster_issuer
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'YAML' | kubectl apply --as=system:admin --as-group=system:masters -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: kibana-tls-stack-${var.stack_id}
        namespace: aks-istio-ingress
      spec:
        secretName: kibana-tls-stack-${var.stack_id}
        duration: 2160h
        renewBefore: 360h
        commonName: "${local.kibana_hostname}"
        dnsNames:
          - "${local.kibana_hostname}"
        issuerRef:
          name: ${local.active_cluster_issuer}
          kind: ClusterIssuer
      YAML
    EOT
  }
}
