# Stack outputs

output "platform_namespace" {
  description = "Platform namespace name for this stack"
  value       = local.platform_namespace
}

output "osdu_namespace" {
  description = "OSDU namespace name for this stack"
  value       = local.osdu_namespace
}

output "postgresql_host" {
  description = "PostgreSQL read-write service host"
  value       = var.enable_postgresql ? local.postgresql_host : ""
}

output "redis_host" {
  description = "Redis master service host"
  value       = var.enable_redis ? local.redis_host : ""
}

output "rabbitmq_host" {
  description = "RabbitMQ service host"
  value       = var.enable_rabbitmq ? local.rabbitmq_host : ""
}

output "keycloak_host" {
  description = "Keycloak service host"
  value       = var.enable_keycloak ? local.keycloak_host : ""
}

output "elasticsearch_url" {
  description = "Elasticsearch internal URL"
  value       = var.enable_elasticsearch ? "https://elasticsearch-es-http.${local.platform_namespace}.svc.cluster.local:9200" : ""
}

output "kibana_url" {
  description = "Kibana external URL"
  value       = var.enable_elasticsearch && var.enable_gateway && local.has_ingress_hostname ? "https://${local.kibana_hostname}" : ""
}

output "osdu_api_url" {
  description = "OSDU API external base URL"
  value       = var.enable_osdu_api_ingress && var.enable_gateway && local.osdu_domain != "" ? "https://${local.osdu_domain}" : ""
}

output "keycloak_url" {
  description = "Keycloak external URL"
  value       = var.enable_keycloak_ingress && var.enable_keycloak && var.enable_gateway && local.keycloak_hostname != "" ? "https://${local.keycloak_hostname}" : ""
}

output "airflow_url" {
  description = "Airflow external URL"
  value       = var.enable_airflow_ingress && var.enable_airflow && var.enable_gateway && local.airflow_hostname != "" ? "https://${local.airflow_hostname}" : ""
}

output "minio_endpoint" {
  description = "MinIO internal API endpoint"
  value       = var.enable_minio ? "minio.${local.platform_namespace}.svc.cluster.local:9000" : ""
}
