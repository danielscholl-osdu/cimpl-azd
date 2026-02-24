# Common OSDU namespace resources (replaces ROSA common-infra-bootstrap chart)
locals {
  osdu_domain = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}.${var.dns_zone_name}" : ""
}

resource "kubernetes_namespace" "osdu" {
  count = var.enable_common ? 1 : 0

  metadata {
    name = "osdu"
    labels = {
      "istio.io/rev" = "asm-1-28"
    }
  }
}

resource "kubernetes_config_map" "osdu_config" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "osdu-config"
    namespace = "osdu"
  }

  data = {
    domain        = local.osdu_domain
    cimpl_project = var.cimpl_project
    cimpl_tenant  = var.cimpl_tenant
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "osdu_credentials" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "osdu-credentials"
    namespace = "osdu"
  }

  data = {
    cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_service_account" "bootstrap" {
  count = var.enable_common ? 1 : 0

  metadata {
    name      = "bootstrap-sa"
    namespace = "osdu"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubectl_manifest" "osdu_peer_authentication" {
  count = var.enable_common ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: osdu-strict-mtls
      namespace: osdu
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.osdu]
}
