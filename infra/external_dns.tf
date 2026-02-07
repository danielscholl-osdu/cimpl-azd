# ExternalDNS identity resources for cross-subscription DNS management
# Only created when all DNS zone variables are configured

locals {
  enable_external_dns = var.dns_zone_name != "" && var.dns_zone_subscription_id != "" && var.dns_zone_resource_group != ""
}

resource "azurerm_user_assigned_identity" "external_dns" {
  count               = local.enable_external_dns ? 1 : 0
  name                = "${local.cluster_name}-external-dns"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

resource "azurerm_federated_identity_credential" "external_dns" {
  count               = local.enable_external_dns ? 1 : 0
  name                = "external-dns"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.external_dns[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_profile_issuer_url
  subject             = "system:serviceaccount:external-dns:external-dns"
}

resource "azurerm_role_assignment" "external_dns_dns_contributor" {
  count                = local.enable_external_dns ? 1 : 0
  scope                = "/subscriptions/${var.dns_zone_subscription_id}/resourceGroups/${var.dns_zone_resource_group}/providers/Microsoft.Network/dnszones/${var.dns_zone_name}"
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns[0].principal_id
}
