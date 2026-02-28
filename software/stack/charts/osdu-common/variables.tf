variable "namespace" {
  description = "OSDU Kubernetes namespace"
  type        = string
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
