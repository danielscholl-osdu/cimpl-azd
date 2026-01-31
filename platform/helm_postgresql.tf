# PostgreSQL for shared database services
resource "helm_release" "postgresql" {
  count            = var.enable_postgresql ? 1 : 0
  name             = "postgresql"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.4.6"
  namespace        = "postgresql"
  create_namespace = true
  timeout          = 600
  wait             = false

  values = [<<-YAML
    global:
      storageClass: "managed-csi"
      # Allow ECR images (required for non-DockerHub Bitnami images)
      security:
        allowInsecureImages: true

    # Specific version tag for AKS Automatic safeguards compliance
    # Using AWS ECR public registry for reliable image pulls
    image:
      registry: public.ecr.aws
      repository: bitnami/postgresql
      tag: "18"

    primary:
      persistence:
        enabled: true
        storageClass: "managed-csi"
        size: 8Gi

      # Resource limits for safeguards compliance
      resources:
        requests:
          cpu: 250m
          memory: 256Mi
        limits:
          cpu: 1
          memory: 1Gi

      # Pod security context
      podSecurityContext:
        enabled: true
        fsGroup: 1001

      containerSecurityContext:
        enabled: true
        runAsUser: 1001
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault

    auth:
      # DEMO ONLY - change for production
      # TODO: Use secrets management (e.g., Azure Key Vault) for production
      postgresPassword: "postgres"
      database: "osdu"

    # Metrics for observability
    metrics:
      enabled: false
  YAML
  ]

  # Ignore changes for imported resources to avoid safeguards conflicts
  lifecycle {
    ignore_changes = all
  }
}
