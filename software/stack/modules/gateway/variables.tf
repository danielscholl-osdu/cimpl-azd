variable "namespace" {
  description = "Kubernetes namespace (platform namespace for certs and middleware services)"
  type        = string
}

variable "osdu_namespace" {
  description = "Kubernetes namespace for OSDU services"
  type        = string
  default     = "osdu"
}

variable "stack_label" {
  description = "Stack label for resource naming"
  type        = string
}

variable "kibana_hostname" {
  description = "External hostname for Kibana"
  type        = string
}

variable "osdu_hostname" {
  description = "External hostname for OSDU API"
  type        = string
  default     = ""
}

variable "keycloak_hostname" {
  description = "External hostname for Keycloak UI"
  type        = string
  default     = ""
}

variable "airflow_hostname" {
  description = "External hostname for Airflow UI"
  type        = string
  default     = ""
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

variable "enable_osdu_api" {
  description = "Enable OSDU API external routing"
  type        = bool
  default     = false
}

variable "enable_keycloak" {
  description = "Enable Keycloak external routing"
  type        = bool
  default     = false
}

variable "enable_airflow" {
  description = "Enable Airflow external routing"
  type        = bool
  default     = false
}

variable "osdu_api_routes" {
  description = "List of OSDU API routes to create"
  type = list(object({
    path_prefix  = string
    service_name = string
  }))
  default = []
}
