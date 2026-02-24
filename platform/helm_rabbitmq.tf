# RabbitMQ messaging broker using Bitnami Helm chart
resource "kubernetes_namespace" "rabbitmq" {
  count = var.enable_rabbitmq ? 1 : 0
  metadata {
    name = "rabbitmq"
    labels = {
      "istio.io/rev" = "asm-1-28"
    }
  }
}

# Istio STRICT mTLS for RabbitMQ namespace
resource "kubectl_manifest" "rabbitmq_peer_authentication" {
  count = var.enable_rabbitmq ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: rabbitmq-strict-mtls
      namespace: rabbitmq
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.rabbitmq]
}

# Premium storage class with Retain policy for RabbitMQ
resource "kubectl_manifest" "rabbitmq_storage_class" {
  count     = var.enable_rabbitmq ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: rabbitmq-storageclass
      labels:
        app: rabbitmq
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

resource "helm_release" "rabbitmq" {
  count            = var.enable_rabbitmq ? 1 : 0
  name             = "rabbitmq"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "rabbitmq"
  version          = "15.5.1"
  namespace        = "rabbitmq"
  create_namespace = false
  timeout          = 600

  values = [<<-YAML
    # Image override: use the official RabbitMQ image to avoid Bitnami supply-chain
    # constraints; consider mirroring and pinning by digest for production use.
    global:
      security:
        allowInsecureImages: true
    image:
      registry: docker.io
      repository: rabbitmq
      tag: 4.1.0-management-alpine

    auth:
      # Credentials (DEMO ONLY - change for production)
      # TODO: Use secrets management (e.g., Azure Key Vault) for production
      username: "${var.rabbitmq_username}"
      password: "${var.rabbitmq_password}"
      erlangCookie: "${var.rabbitmq_erlang_cookie}"

    replicaCount: 3

    persistence:
      enabled: true
      storageClass: rabbitmq-storageclass
      size: 8Gi
      accessModes:
        - ReadWriteOnce

    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: "1"
        memory: 1Gi

    livenessProbe:
      enabled: true
      initialDelaySeconds: 120
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 6

    readinessProbe:
      enabled: true
      initialDelaySeconds: 20
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 6

    podSecurityContext:
      enabled: true
      fsGroup: 1001
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault

    containerSecurityContext:
      enabled: true
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
            app.kubernetes.io/instance: rabbitmq
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app.kubernetes.io/instance: rabbitmq
  YAML
  ]

  depends_on = [
    kubernetes_namespace.rabbitmq,
    kubectl_manifest.rabbitmq_storage_class,
    kubectl_manifest.karpenter_nodepool_stateful,
    kubectl_manifest.karpenter_aksnodeclass_stateful
  ]
}
