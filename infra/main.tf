# Main orchestration file for AKS Automatic with Elasticsearch
#
# Architecture Overview:
# - AKS Automatic cluster with Istio service mesh
# - Elasticsearch + Kibana deployed via ECK operator
# - PostgreSQL for shared database services
# - MinIO for S3-compatible object storage
# - External HTTPS access via Istio Gateway API + cert-manager
#
# Resource files:
# - aks.tf: AKS Automatic cluster using Azure Verified Module
# - helm_cert_manager.tf: cert-manager for TLS certificates
# - helm_elastic.tf: ECK operator + Elasticsearch + Kibana
# - helm_postgresql.tf: PostgreSQL database
# - helm_minio.tf: MinIO object storage
# - k8s_gateway.tf: Gateway API resources for external access
#
# Storage Strategy (KEYLESS):
# This deployment uses Azure Managed Disks for Elasticsearch storage.
# Managed Disks authenticate via the AKS cluster's managed identity,
# NOT storage account keys. This is compliant with security standards
# that prohibit shared key access.
#
# If you need Azure Blob/Files storage:
# - Azure Files: Requires storage account keys (not keyless compatible)
# - Azure Blob (keyless): Requires OSS Blob CSI driver + static provisioning
# See: https://github.com/danielscholl/aks-storage-poc for details

# Resource Group (required, minimal)
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
