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
