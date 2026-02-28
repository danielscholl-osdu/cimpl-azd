# Azure Managed Grafana with Prometheus integration
# Provides dashboards for AKS metrics (Managed Prometheus) and logs (Container Insights)

resource "azurerm_monitor_workspace" "prometheus" {
  name                = "${local.cluster_name}-prometheus"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

resource "azurerm_dashboard_grafana" "main" {
  name                  = "${local.cluster_name}-grafana"
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  grafana_major_version = "11"
  sku                   = "Standard"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  tags = local.common_tags
}

# Grafana needs Monitoring Reader on the subscription to discover data sources
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# Grafana needs Monitoring Data Reader on the monitor workspace for Prometheus queries
resource "azurerm_role_assignment" "grafana_monitoring_data_reader" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# Grafana needs Log Analytics Reader for Container Insights queries
resource "azurerm_role_assignment" "grafana_log_analytics_reader" {
  scope                = azurerm_log_analytics_workspace.aks.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# Grant deploying user Grafana Admin so they can access dashboards immediately
resource "azurerm_role_assignment" "grafana_admin" {
  scope                = azurerm_dashboard_grafana.main.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
