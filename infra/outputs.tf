output "AZURE_RESOURCE_GROUP" {
  value = azurerm_resource_group.main.name
}

output "AZURE_AKS_CLUSTER_NAME" {
  value = module.aks.name
}

output "OIDC_ISSUER_URL" {
  value = module.aks.oidc_issuer_profile_issuer_url
}

output "KIBANA_URL" {
  value = "https://${var.kibana_hostname}"
}

output "CLUSTER_FQDN" {
  description = "AKS cluster FQDN"
  value       = module.aks.fqdn
}

output "get_credentials_command" {
  description = "Command to get kubeconfig"
  value       = "az aks get-credentials -g ${azurerm_resource_group.main.name} -n ${module.aks.name} && kubelogin convert-kubeconfig -l azurecli"
}

output "get_ingress_ip_command" {
  description = "Command to get external ingress IP"
  value       = "kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "get_elasticsearch_password_command" {
  description = "Command to get Elasticsearch password"
  value       = "kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d"
}

output "POSTGRESQL_HOST" {
  description = "PostgreSQL internal service host"
  value       = "postgresql.postgresql.svc.cluster.local"
}

output "MINIO_ENDPOINT" {
  description = "MinIO internal API endpoint"
  value       = "minio.minio.svc.cluster.local:9000"
}

output "MINIO_CONSOLE_ENDPOINT" {
  description = "MinIO console endpoint (port-forward to access)"
  value       = "minio.minio.svc.cluster.local:9001"
}
