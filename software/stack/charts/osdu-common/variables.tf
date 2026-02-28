variable "namespace" {
  description = "OSDU Kubernetes namespace"
  type        = string
}

variable "platform_namespace" {
  description = "Platform Kubernetes namespace (for cross-namespace service references)"
  type        = string
  default     = "platform"
}

variable "osdu_domain" {
  description = "OSDU domain (e.g. prefix.dnszone)"
  type        = string
}

variable "cimpl_project" {
  description = "CIMPL project/group identifier"
  type        = string
}

variable "cimpl_tenant" {
  description = "CIMPL data partition ID"
  type        = string
}

variable "cimpl_subscriber_private_key_id" {
  description = "Subscriber private key identifier for OSDU services"
  type        = string
  sensitive   = true
}

variable "postgresql_host" {
  description = "PostgreSQL read-write service host"
  type        = string
}

variable "postgresql_username" {
  description = "PostgreSQL application database owner username"
  type        = string
}

variable "postgresql_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_host" {
  description = "Keycloak service host"
  type        = string
}

variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  sensitive   = true
}

variable "datafier_client_secret" {
  description = "Keycloak client secret for the datafier service account"
  type        = string
  sensitive   = true
}

variable "enable_partition" {
  description = "Enable OSDU Partition service secrets"
  type        = bool
  default     = true
}

variable "enable_entitlements" {
  description = "Enable OSDU Entitlements service secrets"
  type        = bool
  default     = true
}

variable "enable_legal" {
  description = "Enable OSDU Legal service secrets"
  type        = bool
  default     = true
}

variable "enable_schema" {
  description = "Enable OSDU Schema service secrets"
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable OSDU Storage service secrets"
  type        = bool
  default     = true
}

variable "enable_file" {
  description = "Enable OSDU File service secrets"
  type        = bool
  default     = true
}

variable "enable_dataset" {
  description = "Enable OSDU Dataset service secrets"
  type        = bool
  default     = true
}

variable "enable_register" {
  description = "Enable OSDU Register service secrets"
  type        = bool
  default     = true
}

variable "enable_workflow" {
  description = "Enable OSDU Workflow service secrets"
  type        = bool
  default     = false
}

variable "enable_notification" {
  description = "Enable OSDU Notification service secrets"
  type        = bool
  default     = true
}

variable "enable_policy" {
  description = "Enable OSDU Policy service secrets"
  type        = bool
  default     = true
}

variable "enable_wellbore" {
  description = "Enable OSDU Wellbore service secrets"
  type        = bool
  default     = true
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ username"
  type        = string
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}
