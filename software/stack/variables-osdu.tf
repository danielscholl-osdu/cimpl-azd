# OSDU configuration variables

variable "cimpl_subscriber_private_key_id" {
  description = "Subscriber private key identifier for OSDU services"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cimpl_project" {
  description = "CIMPL project/group identifier"
  type        = string
  default     = ""
}

variable "cimpl_tenant" {
  description = "CIMPL data partition ID"
  type        = string
  default     = "osdu"
}

# OSDU version management
variable "osdu_chart_version" {
  description = "Default OSDU Helm chart version for all services"
  type        = string
  default     = "0.0.7-latest"
}

variable "osdu_service_versions" {
  description = "Per-service version overrides (service_name -> chart_version)"
  type        = map(string)
  default     = {}
}
