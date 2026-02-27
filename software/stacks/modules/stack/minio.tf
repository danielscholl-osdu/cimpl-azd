# MinIO for S3-compatible object storage (per-stack instance)

resource "helm_release" "minio" {
  count            = var.enable_minio ? 1 : 0
  name             = "minio"
  repository       = "https://charts.min.io/"
  chart            = "minio"
  version          = "5.4.0"
  namespace        = local.platform_namespace
  create_namespace = false

  depends_on = [kubernetes_namespace.platform]
  timeout    = 600
  wait       = false

  postrender = {
    binary_path = "${var.kustomize_path}/postrender-minio.sh"
  }

  values = [<<-YAML
    mode: standalone
    commonLabels:
      app.kubernetes.io/component: minio-server
    image:
      repository: quay.io/minio/minio
      tag: "RELEASE.2024-12-18T13-15-44Z"
      pullPolicy: IfNotPresent
    replicas: 1
    persistence:
      enabled: true
      storageClass: "managed-csi"
      size: 10Gi
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: 1
        memory: 1Gi
    rootUser: "${var.minio_root_user}"
    rootPassword: "${var.minio_root_password}"
    consoleService:
      type: ClusterIP
      port: 9001
    service:
      type: ClusterIP
      port: 9000
    securityContext:
      enabled: true
      runAsUser: 1000
      runAsGroup: 1000
      fsGroup: 1000
      fsGroupChangePolicy: OnRootMismatch
    containerSecurityContext:
      enabled: true
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
    users: []
    buckets: []
    policies: []
    svcaccts: []
    customCommands: []
  YAML
  ]

  lifecycle {
    ignore_changes = all
  }
}
