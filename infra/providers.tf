# Provider configuration for cluster layer
# Only Azure provider needed - no Kubernetes/Helm

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
