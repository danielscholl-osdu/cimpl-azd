# Platform Layer - Infrastructure components deployed on AKS
#
# This layer deploys platform infrastructure on top of the AKS cluster:
# - cert-manager for TLS certificate management
# - Elasticsearch + Kibana via ECK operator
# - PostgreSQL for shared database services
# - MinIO for S3-compatible object storage
# - Gateway API resources for external access
#
# Prerequisites:
# - AKS cluster must be provisioned (Layer 1: infra/)
# - kubeconfig must be configured: az aks get-credentials -g <rg> -n <cluster>
#
# Usage:
# This layer is deployed via post-provision hook or manually:
#   cd platform && terraform init && terraform apply

locals {
  # Common labels for all platform resources
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "cimpl-platform"
  }
}

# Note: Individual components are in separate files:
# - helm_cert_manager.tf
# - helm_elastic.tf
# - helm_cnpg.tf
# - helm_minio.tf
# - k8s_gateway.tf
#
# Each component uses count = var.enable_<component> ? 1 : 0
# for conditional deployment following the ROSA pattern.
