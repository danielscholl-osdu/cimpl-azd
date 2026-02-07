# Redis cache cluster using Bitnami Helm chart (replication architecture)
# 1 master + 2 replicas on stateful node pool, zone-spread, premium storage

resource "kubernetes_namespace" "redis" {
  count = var.enable_redis ? 1 : 0
  metadata {
    name = "redis"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Istio STRICT mTLS for Redis namespace
resource "kubectl_manifest" "redis_peer_authentication" {
  count = var.enable_redis ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: redis-strict-mtls
      namespace: redis
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.redis]
}

# Custom StorageClass for Redis (Premium LRS with Retain policy)
resource "kubectl_manifest" "redis_storage_class" {
  count     = var.enable_redis ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: redis-storageclass
      labels:
        app: redis
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

# Redis password secret (managed by Terraform like CNPG credentials)
resource "kubernetes_secret" "redis_password" {
  count = var.enable_redis ? 1 : 0
  metadata {
    name      = "redis-credentials"
    namespace = "redis"
  }

  data = {
    redis-password = var.redis_password
  }

  depends_on = [kubernetes_namespace.redis]
}

# Bitnami Redis Helm release (replication: 1 master + 2 replicas)
resource "helm_release" "redis" {
  count            = var.enable_redis ? 1 : 0
  name             = "redis"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "redis"
  version          = "20.6.3"
  namespace        = "redis"
  create_namespace = false
  timeout          = 600

  values = [<<-YAML
    # Replication architecture: master + replicas (no sentinel)
    architecture: replication

    # Authentication
    auth:
      enabled: true
      existingSecret: redis-credentials
      existingSecretPasswordKey: redis-password

    # --- Master configuration ---
    master:
      replicaCount: 1

      persistence:
        enabled: true
        storageClass: redis-storageclass
        size: 8Gi
        accessModes:
          - ReadWriteOnce

      resources:
        requests:
          cpu: 250m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 1Gi

      podSecurityContext:
        fsGroup: 1001
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault

      containerSecurityContext:
        runAsUser: 1001
        runAsGroup: 1001
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault

      tolerations:
        - effect: NoSchedule
          key: workload
          value: stateful

      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/component: master

    # --- Replica configuration ---
    replica:
      replicaCount: 2

      persistence:
        enabled: true
        storageClass: redis-storageclass
        size: 8Gi
        accessModes:
          - ReadWriteOnce

      resources:
        requests:
          cpu: 250m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 1Gi

      podSecurityContext:
        fsGroup: 1001
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault

      containerSecurityContext:
        runAsUser: 1001
        runAsGroup: 1001
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault

      tolerations:
        - effect: NoSchedule
          key: workload
          value: stateful

      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/component: replica
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/component: replica

    # Sentinel disabled (Kubernetes handles pod restarts; add later for auto-failover)
    sentinel:
      enabled: false

    # Metrics (disabled for now)
    metrics:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.redis,
    kubectl_manifest.redis_storage_class,
    kubernetes_secret.redis_password
  ]
}
