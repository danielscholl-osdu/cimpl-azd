# CNPG database credential secrets
#
# Keycloak and Airflow get dedicated PostgreSQL roles with their own passwords.
# These secrets are referenced by the CNPG bootstrap Job.

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
