# Variables for foundation layer

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

# cert-manager configuration
variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "use_letsencrypt_production" {
  description = "Use Let's Encrypt production issuer (default: false = staging)"
  type        = bool
  default     = false
}

# Feature flags
variable "enable_cert_manager" {
  description = "Enable cert-manager deployment"
  type        = bool
  default     = true
}

variable "enable_elasticsearch" {
  description = "Enable ECK operator deployment"
  type        = bool
  default     = true
}

variable "enable_postgresql" {
  description = "Enable CNPG operator deployment"
  type        = bool
  default     = true
}

variable "enable_gateway" {
  description = "Enable Gateway API resources"
  type        = bool
  default     = true
}

variable "enable_public_ingress" {
  description = "Expose Istio ingress gateway via public LoadBalancer (false = internal-only)"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable ExternalDNS for automatic DNS record management"
  type        = bool
  default     = false
}

# Ingress configuration
variable "ingress_prefix" {
  description = "Unique prefix for ingress hostnames"
  type        = string
  default     = ""
}

# DNS configuration
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
  description = "Subscription ID containing the DNS zone"
  type        = string
  default     = ""
}

variable "external_dns_client_id" {
  description = "Client ID of the ExternalDNS managed identity"
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = ""
}
