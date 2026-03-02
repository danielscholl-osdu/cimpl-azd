variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "postgresql_host" {
  description = "PostgreSQL read-write service host"
  type        = string
}

variable "keycloak_db_password" {
  description = "Keycloak database password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datafier_client_secret" {
  description = "Keycloak client secret for the datafier service account"
  type        = string
  sensitive   = true
}

variable "osdu_namespace" {
  description = "OSDU namespace name for datafier secret"
  type        = string
}
