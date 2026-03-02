variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "stack_label" {
  description = "Stack label for resource naming"
  type        = string
}

variable "kibana_hostname" {
  description = "External hostname for Kibana"
  type        = string
}

variable "active_cluster_issuer" {
  description = "ClusterIssuer name for TLS certificates"
  type        = string
}

variable "enable_cert_manager" {
  description = "Enable cert-manager TLS certificates"
  type        = bool
  default     = true
}
