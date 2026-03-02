# Cross-namespace service aliases and mTLS policy

# Cross-namespace aliases — ExternalName services in the OSDU namespace that
# point to middleware in the platform namespace.  AKS Gatekeeper's
# UniqueServiceSelector policy only allows one ExternalName service per
# namespace (empty selectors collide), so we use a single kubectl_manifest
# containing all aliases as separate documents.

resource "kubernetes_service" "rabbitmq_alias" {
  metadata {
    name      = "rabbitmq"
    namespace = var.namespace
  }

  spec {
    type          = "ExternalName"
    external_name = "rabbitmq.${var.platform_namespace}.svc.cluster.local"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubectl_manifest" "osdu_peer_authentication" {
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: osdu-strict-mtls
      namespace: ${var.namespace}
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.osdu]
}
