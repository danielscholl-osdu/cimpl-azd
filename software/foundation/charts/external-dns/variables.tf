variable "namespace" {
  description = "Kubernetes namespace for ExternalDNS"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster (used as txtOwnerId)"
  type        = string
}

variable "dns_zone_name" {
  description = "Azure DNS zone name"
  type        = string
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the DNS zone"
  type        = string
}

variable "dns_zone_subscription_id" {
  description = "Subscription ID containing the DNS zone"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "external_dns_client_id" {
  description = "Client ID of the ExternalDNS managed identity"
  type        = string
}
