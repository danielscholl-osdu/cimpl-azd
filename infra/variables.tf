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

# DNS zone configuration for ExternalDNS
variable "dns_zone_name" {
  description = "Azure DNS zone name for ExternalDNS"
  type        = string
  default     = ""
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the DNS zone"
  type        = string
  default     = ""
}

variable "dns_zone_subscription_id" {
  description = "Subscription ID containing the DNS zone (cross-subscription support)"
  type        = string
  default     = ""
}

# System node pool configuration
variable "system_pool_vm_size" {
  description = "VM size for the AKS system node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "system_pool_availability_zones" {
  description = "Availability zones for the AKS system node pool (reduce to avoid capacity issues)"
  type        = list(string)
  default     = ["1", "2", "3"]

  validation {
    condition     = length(var.system_pool_availability_zones) > 0
    error_message = "system_pool_availability_zones must specify at least one availability zone."
  }
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
