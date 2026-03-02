variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "postgresql_host" {
  description = "PostgreSQL read-write service host"
  type        = string
}

variable "airflow_db_password" {
  description = "Airflow database password"
  type        = string
  sensitive   = true
}
