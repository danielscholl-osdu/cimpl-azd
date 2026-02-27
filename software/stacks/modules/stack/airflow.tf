# Apache Airflow workflow orchestration (per-stack instance)

resource "random_bytes" "airflow_fernet_key" {
  count  = var.enable_airflow ? 1 : 0
  length = 32
}

resource "random_password" "airflow_webserver_secret" {
  count   = var.enable_airflow ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "airflow_secrets" {
  count = var.enable_airflow ? 1 : 0
  metadata {
    name      = "airflow-secrets"
    namespace = local.platform_namespace
  }

  data = {
    "fernet-key"           = random_bytes.airflow_fernet_key[0].base64
    "webserver-secret-key" = random_password.airflow_webserver_secret[0].result
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.platform]
}

resource "helm_release" "airflow" {
  count            = var.enable_airflow ? 1 : 0
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.19.0"
  namespace        = local.platform_namespace
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  values = [<<-YAML
    defaultAirflowRepository: apache/airflow
    defaultAirflowTag: "3.1.7"

    executor: KubernetesExecutor

    fernetKeySecretName: airflow-secrets
    webserverSecretKeySecretName: airflow-secrets

    data:
      metadataConnection:
        user: airflow
        pass: "${var.airflow_db_password}"
        protocol: postgresql
        host: ${local.postgresql_host}
        port: 5432
        db: airflow

    createUserJob:
      useHelmHooks: false
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}
    migrateDatabaseJob:
      useHelmHooks: false
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}

    logGroomerSidecar:
      resources:
        requests:
          cpu: 25m
          memory: 128Mi
        limits:
          cpu: 100m
          memory: 256Mi

    waitForMigrations:
      resources:
        requests:
          cpu: 25m
          memory: 128Mi
        limits:
          cpu: 100m
          memory: 256Mi

    dagProcessor:
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}
      logGroomerSidecar:
        resources:
          requests:
            cpu: 25m
            memory: 128Mi
          limits:
            cpu: 100m
            memory: 256Mi

    postgresql:
      enabled: false
    redis:
      enabled: false

    securityContexts:
      pod:
        runAsUser: 50000
        runAsGroup: 0
        fsGroup: 0
      containers:
        runAsUser: 50000
        allowPrivilegeEscalation: false

    apiServer:
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}

    webserver:
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}

    scheduler:
      replicas: 1
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      logGroomerSidecar:
        resources:
          requests:
            cpu: 25m
            memory: 128Mi
          limits:
            cpu: 100m
            memory: 256Mi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}

    triggerer:
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      logGroomerSidecar:
        resources:
          requests:
            cpu: 25m
            memory: 128Mi
          limits:
            cpu: 100m
            memory: 256Mi
      tolerations:
        - key: stack
          operator: Equal
          value: "${var.stack_id}"
          effect: NoSchedule
      nodeSelector:
        agentpool: ${local.nodepool_name}

    workers:
      replicas: 0

    statsd:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.platform,
    kubernetes_secret.airflow_secrets,
    kubectl_manifest.cnpg_database_bootstrap,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}
