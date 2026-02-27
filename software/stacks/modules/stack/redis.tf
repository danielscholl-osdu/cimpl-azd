# Redis cache cluster (per-stack instance)

resource "kubernetes_secret" "redis_password" {
  count = var.enable_redis ? 1 : 0
  metadata {
    name      = "redis-credentials"
    namespace = local.platform_namespace
  }

  data = {
    "redis-password" = var.redis_password
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "helm_release" "redis" {
  count            = var.enable_redis ? 1 : 0
  name             = "redis"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "redis"
  version          = "24.1.3"
  namespace        = local.platform_namespace
  create_namespace = false
  timeout          = 600

  values = [<<-YAML
    architecture: replication

    global:
      security:
        allowInsecureImages: true
    image:
      registry: docker.io
      repository: bitnamilegacy/redis
      tag: 8.2.1-debian-12-r0

    auth:
      enabled: true
      existingSecret: redis-credentials
      existingSecretPasswordKey: redis-password

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
          key: stack
          value: "${var.stack_id}"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - ${local.nodepool_name}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/component: master

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
          key: stack
          value: "${var.stack_id}"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - ${local.nodepool_name}
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

    sentinel:
      enabled: false

    metrics:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.platform,
    kubernetes_secret.redis_password,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}
