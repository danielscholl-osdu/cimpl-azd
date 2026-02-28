variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "rabbitmq_username" {
  description = "RabbitMQ admin username"
  type        = string
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
