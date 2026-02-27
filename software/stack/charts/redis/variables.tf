variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  sensitive   = true
}
