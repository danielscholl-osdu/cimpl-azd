# Stack-specific Gateway listeners, HTTPRoutes, and TLS Certificates

# Add HTTPS listener to the shared Gateway for this stack's Kibana
resource "null_resource" "gateway_https_listener" {
  triggers = {
    kibana_hostname = var.kibana_hostname
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
          - name: https-stack-${var.stack_label}
            protocol: HTTPS
            port: 443
            hostname: "${var.kibana_hostname}"
            tls:
              mode: Terminate
              certificateRefs:
                - kind: Secret
                  name: kibana-tls-stack-${var.stack_label}
                  namespace: ${var.namespace}
            allowedRoutes:
              namespaces:
                from: All
      YAML
    EOT
  }
}

# HTTPRoute for Kibana
resource "null_resource" "kibana_route" {
  triggers = {
    kibana_hostname = var.kibana_hostname
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'YAML' | kubectl apply --as=system:admin --as-group=system:masters -f -
      apiVersion: gateway.networking.k8s.io/v1
      kind: HTTPRoute
      metadata:
        name: kibana-route-stack-${var.stack_label}
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
                namespace: ${var.namespace}
                port: 5601
      YAML
    EOT
  }

  depends_on = [null_resource.gateway_https_listener]
}

# ReferenceGrant for cross-namespace service access
resource "kubectl_manifest" "kibana_reference_grant" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: ReferenceGrant
    metadata:
      name: allow-istio-ingress-stack-${var.stack_label}
      namespace: ${var.namespace}
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
}

# TLS Certificate — created in the stack namespace (not aks-istio-ingress) because
# AKS Automatic's ValidatingAdmissionPolicy blocks cert-manager from operating
# in managed system namespaces. The Gateway references the secret cross-namespace
# via a ReferenceGrant (below).
resource "null_resource" "kibana_certificate" {
  count = var.enable_cert_manager ? 1 : 0

  triggers = {
    kibana_hostname = var.kibana_hostname
    cluster_issuer  = var.active_cluster_issuer
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'YAML' | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: kibana-tls-stack-${var.stack_label}
        namespace: ${var.namespace}
      spec:
        secretName: kibana-tls-stack-${var.stack_label}
        duration: 2160h
        renewBefore: 360h
        commonName: "${var.kibana_hostname}"
        dnsNames:
          - "${var.kibana_hostname}"
        issuerRef:
          name: ${var.active_cluster_issuer}
          kind: ClusterIssuer
      YAML
    EOT
  }
}

# ReferenceGrant allowing the Gateway in aks-istio-ingress to read TLS secrets
# from the stack namespace (needed because the Certificate/Secret lives here,
# not in the managed aks-istio-ingress namespace).
resource "kubectl_manifest" "tls_reference_grant" {
  count = var.enable_cert_manager ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: ReferenceGrant
    metadata:
      name: allow-gateway-tls-stack-${var.stack_label}
      namespace: ${var.namespace}
    spec:
      from:
        - group: gateway.networking.k8s.io
          kind: Gateway
          namespace: aks-istio-ingress
      to:
        - group: ""
          kind: Secret
          name: kibana-tls-stack-${var.stack_label}
  YAML
}
