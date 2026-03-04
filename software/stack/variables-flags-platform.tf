# Feature flags — Platform namespace (infrastructure + middleware)

variable "enable_nodepool" {
  description = "Deploy shared Karpenter NodePool for stateful workloads"
  type        = bool
  default     = true
}

variable "enable_public_ingress" {
  description = "Enable public ingress"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable ExternalDNS"
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Enable cert-manager TLS certificates"
  type        = bool
  default     = true
}

variable "enable_gateway" {
  description = "Enable Gateway API resources for this stack"
  type        = bool
  default     = true
}

variable "enable_elasticsearch" {
  description = "Enable Elasticsearch + Kibana deployment"
  type        = bool
  default     = true
}

variable "enable_elastic_bootstrap" {
  description = "Enable Elastic Bootstrap job deployment"
  type        = bool
  default     = true
}

variable "enable_postgresql" {
  description = "Enable PostgreSQL deployment"
  type        = bool
  default     = true
}

variable "enable_minio" {
  description = "Enable MinIO deployment"
  type        = bool
  default     = true
}

variable "enable_redis" {
  description = "Enable Redis cache deployment"
  type        = bool
  default     = true
}

variable "enable_rabbitmq" {
  description = "Enable RabbitMQ deployment"
  type        = bool
  default     = true
}

variable "enable_keycloak" {
  description = "Enable Keycloak deployment"
  type        = bool
  default     = true
}

variable "enable_airflow" {
  description = "Enable Airflow deployment"
  type        = bool
  default     = true
}

# ── Ingress flags ──────────────────────────────────────────────────────────────

variable "enable_osdu_api_ingress" {
  description = "Expose OSDU APIs externally via Gateway API HTTPRoute"
  type        = bool
  default     = true
}

variable "enable_keycloak_ingress" {
  description = "Expose Keycloak UI externally via Gateway API HTTPRoute"
  type        = bool
  default     = true
}

variable "enable_airflow_ingress" {
  description = "Expose Airflow UI externally via Gateway API HTTPRoute"
  type        = bool
  default     = true
}
