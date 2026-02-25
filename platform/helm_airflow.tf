# Apache Airflow workflow orchestration (official Apache Airflow chart)
resource "kubernetes_namespace" "airflow" {
  count = var.enable_airflow ? 1 : 0
  metadata {
    name = "airflow"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Istio STRICT mTLS for Airflow namespace
resource "kubectl_manifest" "airflow_peer_authentication" {
  count = var.enable_airflow ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: airflow-strict-mtls
      namespace: airflow
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.airflow]
}

# Fernet key — must be exactly 32 bytes, URL-safe base64-encoded
resource "random_bytes" "airflow_fernet_key" {
  count  = var.enable_airflow ? 1 : 0
  length = 32
}

# Webserver secret key
resource "random_password" "airflow_webserver_secret" {
  count   = var.enable_airflow ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "airflow_secrets" {
  count = var.enable_airflow ? 1 : 0
  metadata {
    name      = "airflow-secrets"
    namespace = "airflow"
  }

  data = {
    "fernet-key"           = random_bytes.airflow_fernet_key[0].base64
    "webserver-secret-key" = random_password.airflow_webserver_secret[0].result
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.airflow]
}

resource "helm_release" "airflow" {
  count            = var.enable_airflow ? 1 : 0
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.16.0"
  namespace        = "airflow"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  values = [<<-YAML
    defaultAirflowRepository: apache/airflow
    defaultAirflowTag: "2.10.5"

    executor: KubernetesExecutor

    fernetKeySecretName: airflow-secrets
    webserverSecretKeySecretName: airflow-secrets

    data:
      metadataConnection:
        user: airflow
        pass: "${var.airflow_db_password}"
        protocol: postgresql
        host: postgresql-rw.postgresql.svc.cluster.local
        port: 5432
        db: airflow

    # Disable Helm hooks for Terraform compatibility
    createUserJob:
      useHelmHooks: false
    migrateDatabaseJob:
      useHelmHooks: false

    # Disable internal PostgreSQL and Redis
    postgresql:
      enabled: false
    redis:
      enabled: false

    # Security contexts (official chart schema)
    securityContexts:
      pod:
        runAsUser: 50000
        runAsGroup: 0
        fsGroup: 0
      containers:
        runAsUser: 50000
        allowPrivilegeEscalation: false

    # Webserver
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
          value: stateful
          effect: NoSchedule
      nodeSelector:
        agentpool: stateful

    # Scheduler — exec-based liveness probe is chart default
    scheduler:
      replicas: 1
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
          value: stateful
          effect: NoSchedule
      nodeSelector:
        agentpool: stateful

    # Triggerer
    triggerer:
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
          value: stateful
          effect: NoSchedule
      nodeSelector:
        agentpool: stateful

    # Workers not needed with KubernetesExecutor
    workers:
      replicas: 0

    # StatsD not needed
    statsd:
      enabled: false
  YAML
  ]

  depends_on = [
    kubernetes_namespace.airflow,
    kubectl_manifest.airflow_peer_authentication,
    kubernetes_secret.airflow_secrets,
    kubectl_manifest.cnpg_database_bootstrap,
    kubectl_manifest.karpenter_nodepool_stateful,
    kubectl_manifest.karpenter_aksnodeclass_stateful
  ]
}
