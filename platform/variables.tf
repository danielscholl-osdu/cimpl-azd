# Variables for platform layer
# These are passed from the cluster layer or azd environment

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cluster_name" {
  description = "Name of the AKS cluster (for dependencies)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the cluster"
  type        = string
}

# cert-manager configuration
variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

# Ingress configuration
variable "ingress_prefix" {
  description = "Unique prefix for ingress hostnames (auto-generated or user-override)"
  type        = string
  default     = ""
}

# Feature flags (following ROSA pattern)
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

variable "enable_cert_manager" {
  description = "Enable cert-manager deployment"
  type        = bool
  default     = true
}

variable "enable_gateway" {
  description = "Enable Gateway API resources"
  type        = bool
  default     = true
}

variable "enable_public_ingress" {
  description = "Expose Istio ingress gateway via public LoadBalancer (false = internal-only)"
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

variable "enable_external_dns" {
  description = "Enable ExternalDNS for automatic DNS record management"
  type        = bool
  default     = false
}

variable "enable_stateful_nodepool" {
  description = "Deploy Karpenter NodePool for stateful workloads"
  type        = bool
  default     = true
}

variable "use_letsencrypt_production" {
  description = "Use Let's Encrypt production issuer (default: false = staging)"
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Azure DNS zone name for ExternalDNS"
  type        = string
  default     = ""
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the DNS zone"
  type        = string
  default     = ""
}

variable "dns_zone_subscription_id" {
  description = "Subscription ID containing the DNS zone"
  type        = string
  default     = ""
}

variable "external_dns_client_id" {
  description = "Client ID of the ExternalDNS managed identity"
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = ""
}

# OSDU common configuration
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

# Platform credentials
variable "postgresql_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_db_password" {
  description = "Keycloak database password"
  type        = string
  sensitive   = true
}

variable "airflow_db_password" {
  description = "Airflow database password"
  type        = string
  sensitive   = true
}

variable "postgresql_username" {
  description = "PostgreSQL application database owner username"
  type        = string
  default     = "osdu"
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

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    layer = "platform"
  }
}
