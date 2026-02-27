# Foundation layer outputs — values consumed by stacks

output "cluster_issuer_name" {
  description = "Active ClusterIssuer name (staging or production)"
  value       = var.enable_cert_manager ? module.cert_manager[0].active_cluster_issuer : ""
}

output "cluster_issuer_staging_name" {
  description = "Staging ClusterIssuer name"
  value       = var.enable_cert_manager ? "letsencrypt-staging" : ""
}

output "platform_namespace" {
  description = "Foundation namespace name"
  value       = kubernetes_namespace.platform.metadata[0].name
}
