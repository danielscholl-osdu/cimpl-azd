# PostgreSQL for shared database services
resource "helm_release" "postgresql" {
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

    # Using latest tag - will work once policy exclusions propagate
    image:
      tag: "latest"

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
      postgresPassword: "postgres"
      database: "osdu"

    # Metrics for observability
    metrics:
      enabled: false
  YAML
  ]

  depends_on = [module.aks]
}
