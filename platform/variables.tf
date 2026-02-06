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

# Kibana/Ingress configuration
variable "kibana_hostname" {
  description = "Hostname for Kibana external access"
  type        = string
}

# Feature flags (following ROSA pattern)
variable "enable_elasticsearch" {
  description = "Enable Elasticsearch + Kibana deployment"
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

# Platform credentials
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
