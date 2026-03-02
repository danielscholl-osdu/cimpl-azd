# Per-service PostgreSQL connection secrets

resource "kubernetes_secret" "partition_postgres" {
  count = var.enable_partition ? 1 : 0

  metadata {
    name      = "partition-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL           = "jdbc:postgresql://${var.postgresql_host}:5432/partition"
    OSM_POSTGRES_USERNAME      = var.postgresql_username
    OSM_POSTGRES_PASSWORD      = var.postgresql_password
    PARTITION_POSTGRES_DB_NAME = "partition"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "entitlements_postgres" {
  count = var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-multi-tenant-postgres-secret"
    namespace = var.namespace
  }

  data = {
    ENT_PG_URL_SYSTEM          = "jdbc:postgresql://${var.postgresql_host}:5432/entitlements"
    ENT_PG_USER_SYSTEM         = var.postgresql_username
    ENT_PG_PASS_SYSTEM         = var.postgresql_password
    ENT_PG_SCHEMA_OSDU         = "entitlements"
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${var.postgresql_host}:5432/entitlements"
    SPRING_DATASOURCE_USERNAME = var.postgresql_username
    SPRING_DATASOURCE_PASSWORD = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "legal_postgres" {
  count = var.enable_legal ? 1 : 0

  metadata {
    name      = "legal-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/legal"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/legal"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "schema_postgres" {
  count = var.enable_schema ? 1 : 0

  metadata {
    name      = "schema-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/schema"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/schema"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "storage_postgres" {
  count = var.enable_storage ? 1 : 0

  metadata {
    name      = "storage-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/storage"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/storage"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "file_postgres" {
  count = var.enable_file ? 1 : 0

  metadata {
    name      = "file-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/file"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/file"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "dataset_postgres" {
  count = var.enable_dataset ? 1 : 0

  metadata {
    name      = "dataset-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/dataset"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/dataset"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "register_postgres" {
  count = var.enable_register ? 1 : 0

  metadata {
    name      = "register-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/register"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/register"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "workflow_postgres" {
  count = var.enable_workflow ? 1 : 0

  metadata {
    name      = "workflow-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL               = "jdbc:postgresql://${var.postgresql_host}:5432/workflow"
    OSM_POSTGRES_USERNAME          = var.postgresql_username
    OSM_POSTGRES_PASSWORD          = var.postgresql_password
    POSTGRES_DATASOURCE_URL_SYSTEM = "jdbc:postgresql://${var.postgresql_host}:5432/workflow"
    POSTGRES_DB_USERNAME_SYSTEM    = var.postgresql_username
    POSTGRES_DB_PASSWORD_SYSTEM    = var.postgresql_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "wellbore_postgres" {
  count = var.enable_wellbore ? 1 : 0

  metadata {
    name      = "wellbore-postgres-secret"
    namespace = var.namespace
  }

  data = {
    OSM_POSTGRES_URL          = "jdbc:postgresql://${var.postgresql_host}:5432/well_delivery"
    OSM_POSTGRES_USERNAME     = var.postgresql_username
    OSM_POSTGRES_PASSWORD     = var.postgresql_password
    WELLBORE_POSTGRES_DB_NAME = "well_delivery"
  }

  depends_on = [kubernetes_namespace.osdu]
}
