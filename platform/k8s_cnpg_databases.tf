# CNPG databases for Keycloak and Airflow
resource "kubernetes_secret" "keycloak_db" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "keycloak-db-credentials"
    namespace = "postgresql"
  }

  data = {
    username = "keycloak"
    password = var.keycloak_db_password
  }

  depends_on = [kubernetes_namespace.postgresql]
}

resource "kubernetes_secret" "airflow_db" {
  count = var.enable_postgresql ? 1 : 0
  metadata {
    name      = "airflow-db-credentials"
    namespace = "postgresql"
  }

  data = {
    username = "airflow"
    password = var.airflow_db_password
  }

  depends_on = [kubernetes_namespace.postgresql]
}

resource "kubectl_manifest" "cnpg_database_bootstrap" {
  count = var.enable_postgresql ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cnpg-database-bootstrap
      namespace: postgresql
    spec:
      backoffLimit: 3
      ttlSecondsAfterFinished: 300
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          automountServiceAccountToken: false
          restartPolicy: OnFailure
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
            runAsGroup: 999
            seccompProfile:
              type: RuntimeDefault
          containers:
            - name: cnpg-database-bootstrap
              image: "ghcr.io/cloudnative-pg/postgresql:16.4"
              imagePullPolicy: IfNotPresent
              env:
                - name: PGHOST
                  value: "postgresql-rw.postgresql.svc.cluster.local"
                - name: PGDATABASE
                  value: "postgres"
                - name: PGUSER
                  valueFrom:
                    secretKeyRef:
                      name: postgresql-superuser-credentials
                      key: username
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgresql-superuser-credentials
                      key: password
                - name: KEYCLOAK_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: keycloak-db-credentials
                      key: password
                - name: AIRFLOW_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: airflow-db-credentials
                      key: password
              command:
                - /bin/sh
                - -ec
              args:
                - |
                  psql -v ON_ERROR_STOP=1 \
                    -v keycloak_password="$KEYCLOAK_PASSWORD" \
                    -v airflow_password="$AIRFLOW_PASSWORD" \
                    <<'SQL'
                  DO $$
                  BEGIN
                    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'keycloak') THEN
                      EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', 'keycloak', :'keycloak_password');
                    ELSE
                      EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', 'keycloak', :'keycloak_password');
                    END IF;
                    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak') THEN
                      EXECUTE 'CREATE DATABASE keycloak OWNER keycloak';
                    END IF;
                    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'airflow') THEN
                      EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', 'airflow', :'airflow_password');
                    ELSE
                      EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', 'airflow', :'airflow_password');
                    END IF;
                    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow') THEN
                      EXECUTE 'CREATE DATABASE airflow OWNER airflow';
                    END IF;
                  END
                  $$;
                  SQL
              resources:
                requests:
                  cpu: 50m
                  memory: 128Mi
                limits:
                  cpu: 250m
                  memory: 256Mi
  YAML

  depends_on = [
    kubectl_manifest.postgresql_cluster,
    kubernetes_secret.postgresql_superuser,
    kubernetes_secret.keycloak_db,
    kubernetes_secret.airflow_db
  ]
}
