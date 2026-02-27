# Stack module — per-instance middleware + OSDU services
#
# Each stack gets:
# - platform-<id> namespace for middleware (ES, PG, Redis, RabbitMQ, MinIO, Keycloak, Airflow)
# - osdu-<id> namespace for OSDU services
# - Karpenter NodePool with stack-specific taint for node isolation

locals {
  platform_namespace = "platform-${var.stack_id}"
  osdu_namespace     = "osdu-${var.stack_id}"
  nodepool_name      = "stack-${var.stack_id}"

  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "cimpl-stack-${var.stack_id}"
  }

  # Cross-namespace service FQDNs
  postgresql_host = "postgresql-rw.${local.platform_namespace}.svc.cluster.local"
  redis_host      = "redis-master.${local.platform_namespace}.svc.cluster.local"
  rabbitmq_host   = "rabbitmq.${local.platform_namespace}.svc.cluster.local"
  keycloak_host   = "keycloak.${local.platform_namespace}.svc.cluster.local"

  # Ingress hostname derivation
  kibana_hostname      = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}-kibana.${var.dns_zone_name}" : ""
  has_ingress_hostname = local.kibana_hostname != ""
  osdu_domain          = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}.${var.dns_zone_name}" : ""

  active_cluster_issuer = var.use_letsencrypt_production ? "letsencrypt-prod" : "letsencrypt-staging"
}

# Platform namespace for middleware
resource "kubernetes_namespace" "platform" {
  metadata {
    name = local.platform_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Istio STRICT mTLS for platform namespace
resource "kubectl_manifest" "platform_peer_authentication" {
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: platform-strict-mtls
      namespace: ${local.platform_namespace}
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.platform]
}

# Karpenter NodePool for this stack
resource "kubectl_manifest" "karpenter_nodepool" {
  count = var.enable_nodepool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: ${local.nodepool_name}
    spec:
      template:
        metadata:
          labels:
            agentpool: ${local.nodepool_name}
        spec:
          taints:
            - key: stack
              value: "${var.stack_id}"
              effect: NoSchedule
          requirements:
            - key: karpenter.azure.com/sku-family
              operator: In
              values: ["D"]
            - key: karpenter.azure.com/sku-cpu
              operator: In
              values: ["4", "8"]
            - key: karpenter.azure.com/sku-storage-premium-capable
              operator: In
              values: ["true"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
          nodeClassRef:
            group: karpenter.azure.com
            kind: AKSNodeClass
            name: ${local.nodepool_name}
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 5m
      limits:
        cpu: "64"
        memory: 256Gi
  YAML

  wait = true
}

resource "kubectl_manifest" "karpenter_aksnodeclass" {
  count = var.enable_nodepool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.azure.com/v1alpha2
    kind: AKSNodeClass
    metadata:
      name: ${local.nodepool_name}
    spec:
      imageFamily: AzureLinux
      osDiskSizeGB: 128
  YAML

  wait = true
}
