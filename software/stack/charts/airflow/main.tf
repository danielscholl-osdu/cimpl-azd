# Apache Airflow workflow orchestration

resource "random_bytes" "airflow_fernet_key" {
  length = 32
}

resource "random_password" "airflow_webserver_secret" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "airflow_secrets" {
  metadata {
    name      = "airflow-secrets"
    namespace = var.namespace
  }

  data = {
    "fernet-key"           = random_bytes.airflow_fernet_key.base64
    "webserver-secret-key" = random_password.airflow_webserver_secret.result
  }

  type = "Opaque"
}

resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.19.0"
  namespace        = var.namespace
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
        host: ${var.postgresql_host}
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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform
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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform

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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform
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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform

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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform

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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform

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
        - key: workload
          operator: Equal
          value: "platform"
          effect: NoSchedule
      nodeSelector:
        agentpool: platform

    workers:
      replicas: 0

    statsd:
      enabled: false
  YAML
  ]

  depends_on = [kubernetes_secret.airflow_secrets]
}
