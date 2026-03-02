# Feature flags

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
  default     = false
}

variable "enable_gateway" {
  description = "Enable Gateway API resources for this stack"
  type        = bool
  default     = true
}

variable "enable_common" {
  description = "Enable OSDU common namespace resources"
  type        = bool
  default     = true
}

variable "enable_partition" {
  description = "Enable OSDU Partition service deployment"
  type        = bool
  default     = true
}

variable "enable_entitlements" {
  description = "Enable OSDU Entitlements service deployment"
  type        = bool
  default     = true
}

variable "enable_legal" {
  description = "Enable OSDU Legal service deployment"
  type        = bool
  default     = true
}

variable "enable_schema" {
  description = "Enable OSDU Schema service deployment"
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable OSDU Storage service deployment"
  type        = bool
  default     = true
}

variable "enable_search" {
  description = "Enable OSDU Search service deployment"
  type        = bool
  default     = true
}

variable "enable_indexer" {
  description = "Enable OSDU Indexer service deployment"
  type        = bool
  default     = true
}

variable "enable_file" {
  description = "Enable OSDU File service deployment"
  type        = bool
  default     = true
}

variable "enable_notification" {
  description = "Enable OSDU Notification service deployment"
  type        = bool
  default     = true
}

variable "enable_dataset" {
  description = "Enable OSDU Dataset service deployment"
  type        = bool
  default     = true
}

variable "enable_register" {
  description = "Enable OSDU Register service deployment"
  type        = bool
  default     = true
}

variable "enable_policy" {
  description = "Enable OSDU Policy service deployment"
  type        = bool
  default     = true
}

variable "enable_secret" {
  description = "Enable OSDU Secret service deployment"
  type        = bool
  default     = true
}

variable "enable_unit" {
  description = "Enable OSDU Unit service deployment"
  type        = bool
  default     = false
}

variable "enable_workflow" {
  description = "Enable OSDU Workflow service deployment"
  type        = bool
  default     = false
}

variable "enable_wellbore" {
  description = "Enable OSDU Wellbore service deployment"
  type        = bool
  default     = false
}

variable "enable_wellbore_worker" {
  description = "Enable OSDU Wellbore Worker service deployment"
  type        = bool
  default     = false
}

variable "enable_crs_conversion" {
  description = "Enable OSDU CRS Conversion service deployment"
  type        = bool
  default     = false
}

variable "enable_crs_catalog" {
  description = "Enable OSDU CRS Catalog service deployment"
  type        = bool
  default     = false
}

variable "enable_eds_dms" {
  description = "Enable OSDU EDS-DMS service deployment"
  type        = bool
  default     = false
}

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
