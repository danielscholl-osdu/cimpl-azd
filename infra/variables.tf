# No subscription_id variable - uses Azure CLI default subscription
# Set with: az account set -s <subscription-name-or-id>

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-cimpl-aks"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "cimpl-aks"
}

variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "kibana_hostname" {
  description = "Hostname for Kibana external access"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "dev"
    project     = "cimpl"
  }
}
