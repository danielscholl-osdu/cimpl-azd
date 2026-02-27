# Config-driven stack — middleware + OSDU services
#
# A single source directory serves all stack instances via STACK_NAME:
# - (unset)  → namespaces: platform, osdu
# - "blue"   → namespaces: platform-blue, osdu-blue
# All stacks share one Karpenter NodePool named "platform".

locals {
  platform_namespace = var.stack_id != "" ? "platform-${var.stack_id}" : "platform"
  osdu_namespace     = var.stack_id != "" ? "osdu-${var.stack_id}" : "osdu"
  nodepool_name      = "platform"
  stack_label        = var.stack_id != "" ? var.stack_id : "default"

  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "cimpl-stack-${local.stack_label}"
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

# Shared Karpenter NodePool for all stacks (idempotent via server_side_apply)
resource "kubectl_manifest" "karpenter_nodepool" {
  count = var.enable_nodepool ? 1 : 0

  server_side_apply = true

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: platform
    spec:
      template:
        metadata:
          labels:
            agentpool: platform
        spec:
          taints:
            - key: workload
              value: "platform"
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
            name: platform
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

  server_side_apply = true

  yaml_body = <<-YAML
    apiVersion: karpenter.azure.com/v1alpha2
    kind: AKSNodeClass
    metadata:
      name: platform
    spec:
      imageFamily: AzureLinux
      osDiskSizeGB: 128
  YAML

  wait = true
}

# ─── Chart modules ───────────────────────────────────────────────────────────

module "elastic" {
  source = "./charts/elastic"
  count  = var.enable_elasticsearch ? 1 : 0

  namespace            = kubernetes_namespace.platform.metadata[0].name
  enable_bootstrap     = var.enable_elastic_bootstrap
  kibana_hostname      = local.kibana_hostname
  has_ingress_hostname = local.has_ingress_hostname
}

module "postgresql" {
  source = "./charts/postgresql"
  count  = var.enable_postgresql ? 1 : 0

  namespace            = kubernetes_namespace.platform.metadata[0].name
  postgresql_password  = var.postgresql_password
  postgresql_username  = var.postgresql_username
  keycloak_db_password = var.keycloak_db_password
  airflow_db_password  = var.airflow_db_password
  cimpl_tenant         = var.cimpl_tenant
}

module "redis" {
  source = "./charts/redis"
  count  = var.enable_redis ? 1 : 0

  namespace      = kubernetes_namespace.platform.metadata[0].name
  redis_password = var.redis_password
}

module "rabbitmq" {
  source = "./charts/rabbitmq"
  count  = var.enable_rabbitmq ? 1 : 0

  namespace              = kubernetes_namespace.platform.metadata[0].name
  rabbitmq_username      = var.rabbitmq_username
  rabbitmq_password      = var.rabbitmq_password
  rabbitmq_erlang_cookie = var.rabbitmq_erlang_cookie
}

module "minio" {
  source = "./charts/minio"
  count  = var.enable_minio ? 1 : 0

  namespace           = kubernetes_namespace.platform.metadata[0].name
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
}

module "keycloak" {
  source = "./charts/keycloak"
  count  = var.enable_keycloak ? 1 : 0

  namespace               = kubernetes_namespace.platform.metadata[0].name
  postgresql_host         = local.postgresql_host
  keycloak_db_password    = var.keycloak_db_password
  keycloak_admin_password = var.keycloak_admin_password
  datafier_client_secret  = var.datafier_client_secret
  osdu_namespace          = local.osdu_namespace

  depends_on = [module.postgresql]
}

module "airflow" {
  source = "./charts/airflow"
  count  = var.enable_airflow ? 1 : 0

  namespace           = kubernetes_namespace.platform.metadata[0].name
  postgresql_host     = local.postgresql_host
  airflow_db_password = var.airflow_db_password

  depends_on = [module.postgresql]
}

module "gateway" {
  source = "./charts/gateway"
  count  = var.enable_gateway && var.enable_elasticsearch && local.has_ingress_hostname ? 1 : 0

  namespace             = kubernetes_namespace.platform.metadata[0].name
  stack_label           = local.stack_label
  kibana_hostname       = local.kibana_hostname
  active_cluster_issuer = local.active_cluster_issuer
  enable_cert_manager   = var.enable_cert_manager

  depends_on = [module.elastic]
}

module "osdu_common" {
  source = "./charts/osdu-common"
  count  = var.enable_common ? 1 : 0

  namespace                       = local.osdu_namespace
  osdu_domain                     = local.osdu_domain
  cimpl_project                   = var.cimpl_project
  cimpl_tenant                    = var.cimpl_tenant
  cimpl_subscriber_private_key_id = var.cimpl_subscriber_private_key_id
  postgresql_host                 = local.postgresql_host
  postgresql_username             = var.postgresql_username
  postgresql_password             = var.postgresql_password
  keycloak_host                   = local.keycloak_host
  redis_password                  = var.redis_password
  datafier_client_secret          = var.datafier_client_secret
  enable_partition                = var.enable_partition
  enable_entitlements             = var.enable_entitlements
}
