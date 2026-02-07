# Platform layer outputs

output "elasticsearch_url" {
  description = "Elasticsearch internal URL"
  value       = var.enable_elasticsearch ? "http://elasticsearch-es-http.elastic-search.svc.cluster.local:9200" : ""
}

output "kibana_url" {
  description = "Kibana external URL"
  value       = var.enable_elasticsearch && var.enable_gateway ? "https://${var.kibana_hostname}" : ""
}

output "kibana_internal_url" {
  description = "Kibana internal URL"
  value       = var.enable_elasticsearch ? "http://kibana-kb-http.elastic-search.svc.cluster.local:5601" : ""
}

output "postgresql_host" {
  description = "PostgreSQL read-write service host (CNPG primary)"
  value       = var.enable_postgresql ? "postgresql-rw.postgresql.svc.cluster.local" : ""
}

output "postgresql_ro_host" {
  description = "PostgreSQL read-only service host (CNPG replicas)"
  value       = var.enable_postgresql ? "postgresql-ro.postgresql.svc.cluster.local" : ""
}

output "postgresql_port" {
  description = "PostgreSQL port"
  value       = var.enable_postgresql ? "5432" : ""
}

output "redis_host" {
  description = "Redis master service host"
  value       = var.enable_redis ? "redis-master.redis.svc.cluster.local" : ""
}

output "redis_port" {
  description = "Redis port"
  value       = var.enable_redis ? "6379" : ""
}

output "minio_endpoint" {
  description = "MinIO internal API endpoint"
  value       = var.enable_minio ? "minio.minio.svc.cluster.local:9000" : ""
}

output "minio_console_endpoint" {
  description = "MinIO console endpoint"
  value       = var.enable_minio ? "minio.minio.svc.cluster.local:9001" : ""
}

# Commands for debugging/access
output "get_elasticsearch_password_command" {
  description = "Command to get Elasticsearch password"
  value       = var.enable_elasticsearch ? "kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d" : ""
}

output "get_postgresql_password_command" {
  description = "Command to get PostgreSQL password"
  value       = var.enable_postgresql ? "kubectl get secret postgresql-superuser-credentials -n postgresql -o jsonpath='{.data.password}' | base64 -d" : ""
}

output "get_redis_password_command" {
  description = "Command to get Redis password"
  value       = var.enable_redis ? "kubectl get secret redis-credentials -n redis -o jsonpath='{.data.redis-password}' | base64 -d" : ""
}

output "get_ingress_ip_command" {
  description = "Command to get external ingress IP"
  value       = "kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
