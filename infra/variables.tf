# Variables for cluster layer (Layer 1)
# This layer only provisions the AKS cluster

variable "environment_name" {
  description = "The name of the azd environment (used for resource uniqueness)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "contact_email" {
  description = "Contact email for resource tagging (owner identification)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Derived names using environment_name for uniqueness
locals {
  # Resource naming: cimpl-<env_name> allows multiple deployments
  resource_group_name = "rg-cimpl-${var.environment_name}"
  cluster_name        = "cimpl-${var.environment_name}"

  # Standard tags applied to all resources
  common_tags = merge(var.tags, {
    "azd-env-name" = var.environment_name
    "project"      = "cimpl"
    "Contact"      = var.contact_email
  })
}
