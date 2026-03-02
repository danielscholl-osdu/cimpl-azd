# Infrastructure variables

variable "stack_id" {
  description = "Stack name suffix. Empty string = default stack (clean namespaces). Set via STACK_NAME."
  type        = string
  default     = ""
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the cluster"
  type        = string
}

# cert-manager
variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "use_letsencrypt_production" {
  description = "Use Let's Encrypt production issuer (default: false = staging)"
  type        = bool
  default     = false
}

# Ingress / DNS
variable "ingress_prefix" {
  description = "Unique prefix for ingress hostnames"
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Azure DNS zone name"
  type        = string
  default     = ""
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the DNS zone"
  type        = string
  default     = ""
}

variable "dns_zone_subscription_id" {
  description = "Subscription ID for the DNS zone"
  type        = string
  default     = ""
}

variable "external_dns_client_id" {
  description = "Client ID for ExternalDNS managed identity"
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    layer = "stack"
  }
}
