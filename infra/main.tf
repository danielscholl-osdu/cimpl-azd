# Layer 1: Cluster Infrastructure
#
# This layer provisions the AKS Automatic cluster with:
# - AKS Automatic cluster with Istio service mesh (built-in)
# - Azure RBAC for Kubernetes authorization
# - Workload Identity support
# - Dedicated node pool for Elasticsearch
#
# Platform components (Elasticsearch, PostgreSQL, MinIO, etc.) are deployed
# in the platform layer (Layer 2) after the cluster is provisioned.
#
# Usage:
#   azd provision  # Provisions this layer
#
# After provisioning, get kubeconfig:
#   az aks get-credentials -g <resource-group> -n <cluster-name>
#   kubelogin convert-kubeconfig -l azurecli

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags = merge(var.tags, {
    "azd-env-name" = var.environment_name
  })
}
