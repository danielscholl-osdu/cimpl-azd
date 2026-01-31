# Use Azure CLI default credentials and subscription
provider "azurerm" {
  features {}
  # Uses ARM_SUBSCRIPTION_ID and ARM_TENANT_ID environment variables
  # Or Azure CLI default subscription
}

# Helm provider - uses kubeconfig from az aks get-credentials
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Kubernetes provider - uses kubeconfig from az aks get-credentials
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Kubectl provider - uses kubeconfig from az aks get-credentials
provider "kubectl" {
  config_path      = "~/.kube/config"
  load_config_file = true
}
