variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "enable_bootstrap" {
  description = "Enable Elastic Bootstrap job deployment"
  type        = bool
  default     = true
}

variable "kibana_hostname" {
  description = "External hostname for Kibana"
  type        = string
  default     = ""
}

variable "has_ingress_hostname" {
  description = "Whether an ingress hostname is configured"
  type        = bool
  default     = false
}
