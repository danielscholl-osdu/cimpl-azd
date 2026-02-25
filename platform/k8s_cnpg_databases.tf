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
      backoffLimit: 20
      ttlSecondsAfterFinished: 600
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
                  echo "Waiting for PostgreSQL to accept connections..."
                  for i in $(seq 1 60); do
                    if pg_isready -h "$PGHOST" -U "$PGUSER" 2>/dev/null; then
                      echo "PostgreSQL is ready."
                      break
                    fi
                    echo "  attempt $i/60 - not ready, waiting 10s..."
                    sleep 10
                  done

                  create_role_and_db() {
                    local role="$1" password="$2" dbname="$3"
                    if psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$role'" | grep -q 1; then
                      echo "Role $role exists, updating password..."
                      psql -c "ALTER ROLE $role WITH LOGIN PASSWORD '$password'"
                    else
                      echo "Creating role $role..."
                      psql -c "CREATE ROLE $role WITH LOGIN PASSWORD '$password'"
                    fi
                    if psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$dbname'" | grep -q 1; then
                      echo "Database $dbname already exists."
                    else
                      echo "Creating database $dbname..."
                      psql -c "CREATE DATABASE $dbname OWNER $role"
                    fi
                  }

                  create_role_and_db keycloak "$KEYCLOAK_PASSWORD" keycloak
                  create_role_and_db airflow "$AIRFLOW_PASSWORD" airflow
                  echo "Database bootstrap complete."
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
