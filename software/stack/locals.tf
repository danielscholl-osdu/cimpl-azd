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
  keycloak_hostname    = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}-keycloak.${var.dns_zone_name}" : ""
  airflow_hostname     = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}-airflow.${var.dns_zone_name}" : ""
  has_ingress_hostname = local.kibana_hostname != ""
  osdu_domain          = var.ingress_prefix != "" && var.dns_zone_name != "" ? "${var.ingress_prefix}.${var.dns_zone_name}" : ""

  active_cluster_issuer = var.use_letsencrypt_production ? "letsencrypt-prod" : "letsencrypt-staging"

  # ── OSDU service deploy flags ─────────────────────────────────────────
  # Group cascade: reference and domain require core
  _osdu_core      = var.enable_osdu_core_services
  _osdu_reference = local._osdu_core && var.enable_osdu_reference_services
  _osdu_domain    = local._osdu_core && var.enable_osdu_domain_services

  # Core services (group + individual)
  deploy_common       = local._osdu_core && var.enable_common
  deploy_partition    = local._osdu_core && var.enable_partition
  deploy_entitlements = local._osdu_core && var.enable_entitlements
  deploy_legal        = local._osdu_core && var.enable_legal
  deploy_schema       = local._osdu_core && var.enable_schema
  deploy_storage      = local._osdu_core && var.enable_storage
  deploy_search       = local._osdu_core && var.enable_search
  deploy_indexer      = local._osdu_core && var.enable_indexer
  deploy_file         = local._osdu_core && var.enable_file
  deploy_notification = local._osdu_core && var.enable_notification
  deploy_dataset      = local._osdu_core && var.enable_dataset
  deploy_register     = local._osdu_core && var.enable_register
  deploy_policy       = local._osdu_core && var.enable_policy
  deploy_secret       = local._osdu_core && var.enable_secret
  deploy_workflow     = local._osdu_core && var.enable_workflow

  # Reference services (group + individual)
  deploy_unit           = local._osdu_reference && var.enable_unit
  deploy_crs_conversion = local._osdu_reference && var.enable_crs_conversion
  deploy_crs_catalog    = local._osdu_reference && var.enable_crs_catalog

  # Domain services (group + individual)
  deploy_wellbore        = local._osdu_domain && var.enable_wellbore
  deploy_wellbore_worker = local._osdu_domain && var.enable_wellbore_worker
  deploy_eds_dms         = local._osdu_domain && var.enable_eds_dms
}
