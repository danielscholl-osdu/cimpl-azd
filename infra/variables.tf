# Variables for cluster layer (Layer 1)
# This layer only provisions the AKS cluster

variable "environment_name" {
  description = "The name of the azd environment"
  type        = string
  default     = "dev"
}

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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "dev"
    project     = "cimpl"
  }
}
