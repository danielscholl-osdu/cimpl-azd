# CNPG PostgreSQL Cluster (per-stack instance)

resource "kubernetes_secret" "postgresql_superuser" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "postgresql-superuser-credentials"
    namespace = local.platform_namespace
  }

  data = {
    username = "postgres"
    password = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubernetes_secret" "postgresql_user" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "postgresql-user-credentials"
    namespace = local.platform_namespace
  }

  data = {
    username = var.postgresql_username
    password = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "postgresql_cluster" {
  count     = var.enable_postgresql ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: postgresql
      namespace: ${local.platform_namespace}
    spec:
      instances: 3
      enableSuperuserAccess: true
      minSyncReplicas: 1
      maxSyncReplicas: 1
      replicationSlots:
        highAvailability:
          enabled: true
      superuserSecret:
        name: postgresql-superuser-credentials
      bootstrap:
        initdb:
          database: osdu
          owner: ${var.postgresql_username}
          secret:
            name: postgresql-user-credentials
          dataChecksums: true
      storage:
        size: 8Gi
        storageClass: pg-storageclass
      walStorage:
        size: 4Gi
        storageClass: pg-storageclass
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: "2"
          memory: 2Gi
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              cnpg.io/cluster: postgresql
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              cnpg.io/cluster: postgresql
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - ${local.nodepool_name}
        tolerations:
          - effect: NoSchedule
            key: stack
            value: "${var.stack_id}"
  YAML

  depends_on = [
    kubernetes_namespace.platform,
    kubernetes_secret.postgresql_superuser,
    kubernetes_secret.postgresql_user,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}
