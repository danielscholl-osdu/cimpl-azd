# CNPG database bootstrap — aligned to ROSA cimpl-postgres-infra-bootstrap model
#
# Creates 14 databases matching the ROSA reference implementation:
# - 12 OSDU service databases (owned by shared 'osdu' user)
# - keycloak and airflow (with dedicated users)
#
# DDL sourced from: community.opengroup.org/.../cimpl-postgres-infra-bootstrap
# AKS adaptations: Job (not Deployment), CNPG HA cluster, shared osdu user, AKS safeguards
#
# SQL templates in sql/ extracted from the original inline DDL for readability.

locals {
  bootstrap_sql = join("\n", [
    for db in ["partition", "entitlements", "legal", "schema", "storage",
      "file", "dataset", "register", "workflow", "seismic",
    "reservoir", "well_delivery"] :
    templatefile("${path.module}/sql/${db}.sql.tftpl", {
      data_partition_id = var.cimpl_tenant
    })
  ])
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
                  echo "=== CNPG Database Bootstrap (ROSA-aligned) ==="

                  echo "Waiting for PostgreSQL to accept connections..."
                  for i in $(seq 1 60); do
                    if pg_isready -h "$PGHOST" -U "$PGUSER" 2>/dev/null; then
                      echo "PostgreSQL is ready."
                      break
                    fi
                    echo "  attempt $i/60 - not ready, waiting 10s..."
                    sleep 10
                  done

                  # Helper: create role and database for non-OSDU services
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

                  # --- Phase 1: Non-OSDU databases with dedicated roles ---
                  create_role_and_db keycloak "$KEYCLOAK_PASSWORD" keycloak
                  create_role_and_db airflow "$AIRFLOW_PASSWORD" airflow

                  # --- Phase 2: OSDU service databases (shared osdu user) ---
                  echo "Creating OSDU service databases..."
                  for db in partition entitlements legal schema storage file dataset register workflow seismic reservoir well_delivery; do
                    if psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
                      echo "  Database $db already exists."
                    else
                      echo "  Creating database $db..."
                      psql -c "CREATE DATABASE $db OWNER osdu"
                    fi
                  done

                  # --- Phase 3: Write ROSA-aligned DDL to temp file ---
                  cat > /tmp/bootstrap.sql <<'BOOTSTRAP_SQL'
                  ${indent(18, local.bootstrap_sql)}
                  BOOTSTRAP_SQL

                  # --- Phase 4: Execute the DDL ---
                  echo "Executing ROSA-aligned DDL across all databases..."
                  psql -f /tmp/bootstrap.sql

                  echo "=== Database bootstrap complete (14 databases) ==="
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
