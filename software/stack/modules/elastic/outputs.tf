output "elastic_password" {
  description = "Elasticsearch elastic user password"
  value       = var.enable_bootstrap ? data.kubernetes_secret.elasticsearch_password[0].data["elastic"] : ""
  sensitive   = true
}
