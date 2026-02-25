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

# Auto-generated Fernet + webserver secret keys
resource "random_password" "airflow_fernet_key" {
  count   = var.enable_airflow ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "airflow_webserver_secret_key" {
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
    "db-password"          = var.airflow_db_password
    "redis-password"       = var.redis_password
    "fernet-key"           = base64encode(random_password.airflow_fernet_key[0].result)
    "webserver-secret-key" = random_password.airflow_webserver_secret_key[0].result
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.airflow]
}

resource "helm_release" "airflow" {
  count            = var.enable_airflow ? 1 : 0
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.15.0"
  namespace        = "airflow"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  values = [<<-YAML
    airflow:
      image:
        repository: apache/airflow
        tag: 2.10.1-python3.12
      executor: CeleryExecutor
      podSecurityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault

    fernetKey:
      enabled: true
      existingSecret: airflow-secrets
      existingSecretKey: fernet-key

    webserverSecretKey:
      enabled: true
      existingSecret: airflow-secrets
      existingSecretKey: webserver-secret-key

    redis:
      enabled: false
    externalRedis:
      host: redis-master.redis.svc.cluster.local
      port: 6379
      passwordSecret: airflow-secrets
      passwordSecretKey: redis-password

    postgresql:
      enabled: false
    pgbouncer:
      enabled: false
    externalDatabase:
      type: postgres
      host: postgresql-rw.postgresql.svc.cluster.local
      port: 5432
      user: airflow
      passwordSecret: airflow-secrets
      passwordSecretKey: db-password
      database: airflow

    statsd:
      enabled: false
    flower:
      enabled: false

    web:
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      livenessProbe:
        httpGet:
          path: /health
          port: 8080
        initialDelaySeconds: 60
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 6
      readinessProbe:
        httpGet:
          path: /health
          port: 8080
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 6
      tolerations:
        - key: workload
          operator: Equal
          value: stateful
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful

    scheduler:
      replicas: 1
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      livenessProbe:
        httpGet:
          path: /health
          port: 8793
        initialDelaySeconds: 60
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 6
      readinessProbe:
        httpGet:
          path: /health
          port: 8793
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 6
      tolerations:
        - key: workload
          operator: Equal
          value: stateful
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful

    triggerer:
      enabled: true
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
      livenessProbe:
        exec:
          command:
            - /bin/sh
            - -ec
            - airflow jobs check --job-type TriggererJob --hostname "$(hostname)"
        initialDelaySeconds: 60
        periodSeconds: 20
        timeoutSeconds: 10
        failureThreshold: 6
      readinessProbe:
        exec:
          command:
            - /bin/sh
            - -ec
            - airflow jobs check --job-type TriggererJob --hostname "$(hostname)"
        initialDelaySeconds: 30
        periodSeconds: 20
        timeoutSeconds: 10
        failureThreshold: 6
      tolerations:
        - key: workload
          operator: Equal
          value: stateful
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful

    workers:
      enabled: true
      replicas: 2
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: "2"
          memory: 2Gi
      livenessProbe:
        exec:
          command:
            - /bin/sh
            - -ec
            - celery -A airflow.executors.celery_executor.app inspect ping -d "celery@$(hostname)"
        initialDelaySeconds: 60
        periodSeconds: 20
        timeoutSeconds: 10
        failureThreshold: 6
      readinessProbe:
        exec:
          command:
            - /bin/sh
            - -ec
            - celery -A airflow.executors.celery_executor.app inspect ping -d "celery@$(hostname)"
        initialDelaySeconds: 30
        periodSeconds: 20
        timeoutSeconds: 10
        failureThreshold: 6
      tolerations:
        - key: workload
          operator: Equal
          value: stateful
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: agentpool
                    operator: In
                    values:
                      - stateful
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: airflow
  YAML
  ]

  depends_on = [
    kubernetes_namespace.airflow,
    kubectl_manifest.airflow_peer_authentication,
    kubernetes_secret.airflow_secrets,
    kubectl_manifest.cnpg_database_bootstrap,
    helm_release.redis
  ]
}
