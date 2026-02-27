# Variables for the stack module

variable "stack_id" {
  description = "Unique identifier for this stack instance (e.g. '1', '2', 'staging')"
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

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
  default     = false
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
  default     = false
}

variable "enable_entitlements" {
  description = "Enable OSDU Entitlements service deployment"
  type        = bool
  default     = false
}

variable "enable_nodepool" {
  description = "Deploy Karpenter NodePool for this stack"
  type        = bool
  default     = true
}

# Ingress / DNS
variable "ingress_prefix" {
  description = "Unique prefix for ingress hostnames"
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Azure DNS zone name"
  type        = string
  default     = ""
}

variable "use_letsencrypt_production" {
  description = "Use Let's Encrypt production issuer (default: false = staging)"
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Enable cert-manager TLS certificates for this stack"
  type        = bool
  default     = true
}

# Credentials
variable "postgresql_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "postgresql_username" {
  description = "PostgreSQL application database owner username"
  type        = string
  default     = "osdu"
}

variable "keycloak_db_password" {
  description = "Keycloak database password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password (auto-generated if unset)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datafier_client_secret" {
  description = "Keycloak client secret for the datafier service account"
  type        = string
  sensitive   = true
}

variable "airflow_db_password" {
  description = "Airflow database password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ admin username"
  type        = string
  default     = "rabbitmq"
}

variable "rabbitmq_password" {
  description = "RabbitMQ admin password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_erlang_cookie" {
  description = "RabbitMQ Erlang cookie for clustering"
  type        = string
  sensitive   = true
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

# OSDU configuration
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

# Postrender path (set by calling module)
variable "kustomize_path" {
  description = "Absolute path to the stack instance directory for postrender scripts"
  type        = string
}

# OSDU version management
variable "osdu_chart_version" {
  description = "Default OSDU Helm chart version for all services"
  type        = string
  default     = "0.0.7-latest"
}

variable "osdu_service_versions" {
  description = "Per-service version overrides (service_name → chart_version)"
  type        = map(string)
  default     = {}
}
