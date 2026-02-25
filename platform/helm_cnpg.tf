# CloudNativePG Operator for HA PostgreSQL
resource "helm_release" "cnpg_operator" {
  count            = var.enable_postgresql ? 1 : 0
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.27.1"
  namespace        = "platform"
  create_namespace = false

  depends_on = [kubernetes_namespace.platform]

  # Resources for AKS Automatic safeguards compliance
  set = [
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "1"
    },
    {
      name  = "resources.limits.memory"
      value = "512Mi"
    },
  ]
}

# Namespace for PostgreSQL cluster
resource "kubernetes_namespace" "postgresql" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name = "postgresql"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Istio STRICT mTLS for PostgreSQL namespace
resource "kubectl_manifest" "postgresql_peer_authentication" {
  count = var.enable_postgresql ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: postgresql-strict-mtls
      namespace: postgresql
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.postgresql]
}

# Custom StorageClass for PostgreSQL (Premium LRS with Retain policy)
resource "kubectl_manifest" "pg_storage_class" {
  count     = var.enable_postgresql ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: pg-storageclass
      labels:
        app: postgresql
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}

# Superuser credentials secret for CNPG
resource "kubernetes_secret" "postgresql_superuser" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "postgresql-superuser-credentials"
    namespace = "postgresql"
  }

  data = {
    username = "postgres"
    password = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.postgresql]
}

# Application user credentials secret for CNPG
resource "kubernetes_secret" "postgresql_user" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "postgresql-user-credentials"
    namespace = "postgresql"
  }

  data = {
    username = var.postgresql_username
    password = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.postgresql]
}

# CNPG PostgreSQL Cluster (3-instance HA with sync replication)
resource "kubectl_manifest" "postgresql_cluster" {
  count     = var.enable_postgresql ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: postgresql
      namespace: postgresql
    spec:
      instances: 3

      # Enable superuser access for database bootstrap operations
      enableSuperuserAccess: true

      # Synchronous replication for HA
      minSyncReplicas: 1
      maxSyncReplicas: 1

      # Replication slots for HA
      replicationSlots:
        highAvailability:
          enabled: true

      # Superuser credentials
      superuserSecret:
        name: postgresql-superuser-credentials

      # Bootstrap with initdb
      bootstrap:
        initdb:
          database: osdu
          owner: ${var.postgresql_username}
          secret:
            name: postgresql-user-credentials
          dataChecksums: true

      # Storage configuration
      storage:
        size: 8Gi
        storageClass: pg-storageclass

      walStorage:
        size: 4Gi
        storageClass: pg-storageclass

      # Resource limits
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: "2"
          memory: 2Gi

      # Topology spread for zone distribution
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

      # Node affinity for stateful node pool
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful
        tolerations:
          - effect: NoSchedule
            key: workload
            value: stateful
  YAML

  depends_on = [
    helm_release.cnpg_operator,
    kubernetes_namespace.postgresql,
    kubectl_manifest.pg_storage_class,
    kubernetes_secret.postgresql_superuser,
    kubernetes_secret.postgresql_user,
    kubectl_manifest.karpenter_nodepool_stateful,
    kubectl_manifest.karpenter_aksnodeclass_stateful
  ]
}
