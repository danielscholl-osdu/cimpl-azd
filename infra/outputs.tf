# Cluster layer outputs
# These are consumed by the platform layer and azd

output "AZURE_RESOURCE_GROUP" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "AZURE_AKS_CLUSTER_NAME" {
  description = "AKS cluster name"
  value       = module.aks.name
}

output "OIDC_ISSUER_URL" {
  description = "OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_profile_issuer_url
}

output "CLUSTER_FQDN" {
  description = "AKS cluster FQDN"
  value       = module.aks.fqdn
}

output "get_credentials_command" {
  description = "Command to get kubeconfig"
  value       = "az aks get-credentials -g ${azurerm_resource_group.main.name} -n ${module.aks.name} && kubelogin convert-kubeconfig -l azurecli"
}

# These outputs are used by the platform layer
output "cluster_resource_group" {
  description = "Resource group for platform layer"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "Cluster name for platform layer"
  value       = module.aks.name
}

output "AZURE_SUBSCRIPTION_ID" {
  description = "Azure subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}

output "EXTERNAL_DNS_CLIENT_ID" {
  description = "Client ID of the ExternalDNS managed identity"
  value       = local.enable_external_dns ? azurerm_user_assigned_identity.external_dns[0].client_id : ""
}

output "AZURE_TENANT_ID" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "GRAFANA_ENDPOINT" {
  description = "Azure Managed Grafana dashboard URL"
  value       = azurerm_dashboard_grafana.main.endpoint
}
