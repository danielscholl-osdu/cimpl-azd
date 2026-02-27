# Variables for stack-1 instance
# Most variables pass through to the stack module

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the cluster"
  type        = string
}

# cert-manager
variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "use_letsencrypt_production" {
  description = "Use Let's Encrypt production issuer"
  type        = bool
  default     = false
}

# Ingress
variable "ingress_prefix" {
  description = "Unique prefix for ingress hostnames"
  type        = string
  default     = ""
}

# Feature flags
variable "enable_elasticsearch" {
  type    = bool
  default = true
}

variable "enable_elastic_bootstrap" {
  type    = bool
  default = true
}

variable "enable_postgresql" {
  type    = bool
  default = true
}

variable "enable_minio" {
  type    = bool
  default = true
}

variable "enable_redis" {
  type    = bool
  default = true
}

variable "enable_rabbitmq" {
  type    = bool
  default = true
}

variable "enable_keycloak" {
  type    = bool
  default = false
}

variable "enable_airflow" {
  type    = bool
  default = false
}

variable "enable_gateway" {
  type    = bool
  default = true
}

variable "enable_cert_manager" {
  type    = bool
  default = true
}

variable "enable_common" {
  type    = bool
  default = true
}

variable "enable_partition" {
  type    = bool
  default = false
}

variable "enable_entitlements" {
  type    = bool
  default = false
}

variable "enable_public_ingress" {
  type    = bool
  default = true
}

variable "enable_external_dns" {
  type    = bool
  default = false
}

variable "enable_stateful_nodepool" {
  type    = bool
  default = true
}

# DNS
variable "dns_zone_name" {
  type    = string
  default = ""
}

variable "dns_zone_resource_group" {
  type    = string
  default = ""
}

variable "dns_zone_subscription_id" {
  type    = string
  default = ""
}

variable "external_dns_client_id" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

# Credentials
variable "postgresql_password" {
  type      = string
  sensitive = true
}

variable "postgresql_username" {
  type    = string
  default = "osdu"
}

variable "keycloak_db_password" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "datafier_client_secret" {
  type      = string
  sensitive = true
}

variable "airflow_db_password" {
  type      = string
  sensitive = true
}

variable "redis_password" {
  type      = string
  sensitive = true
}

variable "rabbitmq_username" {
  type    = string
  default = "rabbitmq"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}

variable "rabbitmq_erlang_cookie" {
  type      = string
  sensitive = true
}

variable "minio_root_user" {
  type = string
}

variable "minio_root_password" {
  type      = string
  sensitive = true
}

# OSDU config
variable "cimpl_subscriber_private_key_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cimpl_project" {
  type    = string
  default = ""
}

variable "cimpl_tenant" {
  type    = string
  default = "osdu"
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    layer = "stack"
  }
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
