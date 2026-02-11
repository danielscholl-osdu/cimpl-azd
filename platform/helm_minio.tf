# MinIO for S3-compatible object storage
# Using official MinIO Helm chart from minio/minio repository
resource "helm_release" "minio" {
  count            = var.enable_minio ? 1 : 0
  name             = "minio"
  repository       = "https://charts.min.io/"
  chart            = "minio"
  version          = "5.4.0"
  namespace        = "platform"
  create_namespace = false

  depends_on = [kubernetes_namespace.platform]
  timeout    = 600
  wait       = false

  # Use postrender to inject health probes for AKS Automatic safeguards compliance
  # The upstream chart doesn't support probe configuration via values
  postrender = {
    binary_path = "${path.module}/postrender-minio.sh"
  }

  values = [<<-YAML
    # Use standalone mode (single pod) for dev/test
    mode: standalone

    # Add common labels to make service selectors unique for AKS policy compliance
    # This resolves K8sAzureV1UniqueServiceSelector violations
    commonLabels:
      app.kubernetes.io/component: minio-server

    # Official MinIO image with specific version (required by AKS safeguards)
    image:
      repository: quay.io/minio/minio
      tag: "RELEASE.2024-12-18T13-15-44Z"
      pullPolicy: IfNotPresent

    # Disable multi-node replicas for standalone mode
    replicas: 1

    # Persistence configuration
    persistence:
      enabled: true
      storageClass: "managed-csi"
      size: 10Gi

    # Resource limits for AKS Automatic safeguards compliance
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: 1
        memory: 1Gi

    # Note: Health probes are injected via postrender script
    # The upstream MinIO chart doesn't support probe configuration via values

    # Root credentials (DEMO ONLY - change for production)
    # TODO: Use secrets management (e.g., Azure Key Vault) for production
    rootUser: "${var.minio_root_user}"
    rootPassword: "${var.minio_root_password}"

    # Console service (MinIO web UI)
    consoleService:
      type: ClusterIP
      port: 9001

    # API service
    service:
      type: ClusterIP
      port: 9000

    # Pod security context for AKS Automatic safeguards
    securityContext:
      enabled: true
      runAsUser: 1000
      runAsGroup: 1000
      fsGroup: 1000
      fsGroupChangePolicy: OnRootMismatch

    # Container security context
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

    # Disable post-install jobs that create users/buckets/policies
    # These jobs require probes which AKS Automatic enforces but Helm hooks don't support
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
