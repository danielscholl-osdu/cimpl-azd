# Redis, MinIO, RabbitMQ, and Elasticsearch secrets

# ─── Redis secrets ───────────────────────────────────────────────────────────

resource "kubernetes_secret" "entitlements_redis" {
  count = var.enable_entitlements ? 1 : 0

  metadata {
    name      = "entitlements-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "storage_redis" {
  count = var.enable_storage ? 1 : 0

  metadata {
    name      = "storage-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "notification_redis" {
  count = var.enable_notification ? 1 : 0

  metadata {
    name      = "notification-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "search_redis" {
  count = var.enable_search ? 1 : 0

  metadata {
    name      = "search-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "indexer_redis" {
  count = var.enable_indexer ? 1 : 0

  metadata {
    name      = "indexer-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "dataset_redis" {
  count = var.enable_dataset ? 1 : 0

  metadata {
    name      = "dataset-redis-secret"
    namespace = var.namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

# ─── MinIO secrets ───────────────────────────────────────────────────────────

resource "kubernetes_secret" "legal_minio" {
  count = var.enable_legal ? 1 : 0

  metadata {
    name      = "legal-minio-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "schema_minio" {
  count = var.enable_schema ? 1 : 0

  metadata {
    name      = "schema-minio-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "policy_minio" {
  count = var.enable_policy ? 1 : 0

  metadata {
    name      = "policy-minio-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "minio_bootstrap" {
  count = var.enable_policy ? 1 : 0

  metadata {
    name      = "minio-bootstrap-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    MINIO_HOST       = "http://minio.${var.platform_namespace}.svc.cluster.local"
    MINIO_PORT       = "9000"
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "storage_minio" {
  count = var.enable_storage ? 1 : 0

  metadata {
    name      = "storage-minio-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "file_minio" {
  count = var.enable_file ? 1 : 0

  metadata {
    name      = "file-minio-secret"
    namespace = var.namespace
  }

  data = {
    MINIO_ACCESS_KEY = var.minio_root_user
    MINIO_SECRET_KEY = var.minio_root_password
    AWS_REGION       = "us-east-1"
  }

  depends_on = [kubernetes_namespace.osdu]
}

# ─── RabbitMQ secret (shared by legal, schema, register, notification) ───────

resource "kubernetes_secret" "rabbitmq" {
  count = (var.enable_legal || var.enable_schema || var.enable_register || var.enable_notification) ? 1 : 0

  metadata {
    name      = "rabbitmq-secret"
    namespace = var.namespace
  }

  data = {
    RABBITMQ_ADMIN_USERNAME = var.rabbitmq_username
    RABBITMQ_ADMIN_PASSWORD = var.rabbitmq_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

# ─── Elasticsearch secrets ───────────────────────────────────────────────────

resource "kubernetes_secret" "indexer_elastic" {
  count = var.enable_indexer ? 1 : 0

  metadata {
    name      = "indexer-elastic-secret"
    namespace = var.namespace
  }

  data = {
    ELASTIC_HOST_SYSTEM = var.elastic_host
    ELASTIC_PORT_SYSTEM = "9200"
    ELASTIC_USER_SYSTEM = "elastic"
    ELASTIC_PASS_SYSTEM = var.elastic_password
  }

  depends_on = [kubernetes_namespace.osdu]
}

resource "kubernetes_secret" "search_elastic" {
  count = var.enable_search ? 1 : 0

  metadata {
    name      = "search-elastic-secret"
    namespace = var.namespace
  }

  data = {
    ELASTIC_HOST_SYSTEM = var.elastic_host
    ELASTIC_PORT_SYSTEM = "9200"
    ELASTIC_USER_SYSTEM = "elastic"
    ELASTIC_PASS_SYSTEM = var.elastic_password
  }

  depends_on = [kubernetes_namespace.osdu]
}
