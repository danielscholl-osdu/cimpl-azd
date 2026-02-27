# Stack 1 outputs

output "platform_namespace" {
  description = "Platform namespace for stack-1"
  value       = module.stack.platform_namespace
}

output "osdu_namespace" {
  description = "OSDU namespace for stack-1"
  value       = module.stack.osdu_namespace
}

output "elasticsearch_url" {
  description = "Elasticsearch internal URL"
  value       = module.stack.elasticsearch_url
}

output "kibana_url" {
  description = "Kibana external URL"
  value       = module.stack.kibana_url
}

output "postgresql_host" {
  description = "PostgreSQL read-write service host"
  value       = module.stack.postgresql_host
}

output "redis_host" {
  description = "Redis master service host"
  value       = module.stack.redis_host
}

output "minio_endpoint" {
  description = "MinIO internal API endpoint"
  value       = module.stack.minio_endpoint
}
