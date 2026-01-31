# MinIO for S3-compatible object storage
# Using official MinIO Helm chart from minio/minio repository
resource "helm_release" "minio" {
  name             = "minio"
  repository       = "https://charts.min.io/"
  chart            = "minio"
  version          = "5.4.0"
  namespace        = "minio"
  create_namespace = true
  timeout          = 600
  wait             = false

  values = [<<-YAML
    # Use standalone mode (single pod) for dev/test
    mode: standalone

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

    # Health probes required by AKS Automatic safeguards
    livenessProbe:
      enabled: true
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
      successThreshold: 1

    readinessProbe:
      enabled: true
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 5
      failureThreshold: 3
      successThreshold: 1

    # Root credentials
    rootUser: "admin"
    rootPassword: "adminpassword"

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
  YAML
  ]

  depends_on = [module.aks]
}
