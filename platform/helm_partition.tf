# Partition service (OSDU)
resource "helm_release" "partition" {
  count = var.enable_partition && var.enable_common ? 1 : 0

  name             = "partition"
  repository       = "oci://community.opengroup.org:5555/osdu/platform/system/partition/cimpl-helm"
  chart            = "core-plus-partition-deploy"
  version          = "0.0.7-latest"
  namespace        = "osdu"
  create_namespace = false
  timeout          = 600

  postrender = {
    binary_path = "/usr/bin/env"
    args        = ["SERVICE_NAME=partition", "${path.module}/kustomize/postrender.sh"]
  }

  set = [
    {
      name  = "global.onPremEnabled"
      value = "true"
      type  = "string"
    },
    {
      name  = "global.domain"
      value = local.osdu_domain
    },
    {
      name  = "global.dataPartitionId"
      value = var.cimpl_tenant
    },
    {
      name  = "data.serviceAccountName"
      value = "partition"
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
      name  = "data.image"
      value = "community.opengroup.org:5555/osdu/platform/system/partition/core-plus-partition-release:67dedce7"
    },
    {
      name  = "data.bootstrapImage"
      value = "community.opengroup.org:5555/osdu/platform/system/partition/core-plus-bootstrap-partition-master:67dedce7"
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

  set_sensitive = [
    {
      name  = "data.subscriberPrivateKeyId"
      value = var.cimpl_subscriber_private_key_id
    }
  ]

  depends_on = [
    kubernetes_namespace.osdu,
    kubernetes_config_map.osdu_config,
    kubernetes_secret.osdu_credentials
  ]
}
