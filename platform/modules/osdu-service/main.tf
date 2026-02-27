# Reusable OSDU service Helm release
#
# Encapsulates the 14 common Helm set values shared by all OSDU services,
# plus postrender for AKS safeguards compliance. Service-specific overrides
# are passed via extra_set. Dependency ordering is controlled by the caller
# via module-level depends_on.

locals {
  common_set = [
    {
      name  = "global.onPremEnabled"
      value = "true"
      type  = "string"
    },
    {
      name  = "global.domain"
      value = var.osdu_domain
    },
    {
      name  = "global.dataPartitionId"
      value = var.cimpl_tenant
    },
    {
      name  = "data.serviceAccountName"
      value = var.service_name
    },
    {
      name  = "data.bootstrapServiceAccountName"
      value = "bootstrap-sa"
    },
    {
      name  = "data.cronJobServiceAccountName"
      value = "bootstrap-sa"
    },
    {
      name  = "data.logLevel"
      value = "INFO"
    },
    {
      name  = "data.bucketPrefix"
      value = "refi"
    },
    {
      name  = "data.groupId"
      value = "group"
    },
    {
      name  = "data.imagePullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "data.sharedTenantName"
      value = var.cimpl_tenant
    },
    {
      name  = "data.googleCloudProject"
      value = var.cimpl_project
    },
    {
      name  = "data.bucketName"
      value = "refi-opa-policies"
    },
    {
      name  = "rosa"
      value = "false"
      type  = "string"
    },
  ]

  all_set = concat(local.common_set, var.extra_set)
}

resource "helm_release" "service" {
  count = var.enable && var.enable_common ? 1 : 0

  name             = var.service_name
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  namespace        = "osdu"
  create_namespace = false
  timeout          = 900

  postrender = {
    binary_path = "/usr/bin/env"
    args        = ["SERVICE_NAME=${var.service_name}", "${var.kustomize_path}/kustomize/postrender.sh"]
  }

  set = local.all_set

  set_sensitive = [
    {
      name  = "data.subscriberPrivateKeyId"
      value = var.subscriber_private_key_id
    }
  ]

  lifecycle {
    precondition {
      condition     = length(var.preconditions) == 0 || alltrue([for p in var.preconditions : p.condition])
      error_message = length(var.preconditions) == 0 ? "no preconditions" : join("; ", [for p in var.preconditions : p.error_message if !p.condition])
    }
  }
}
