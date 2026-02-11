# Get current user for RBAC assignment
data "azurerm_client_config" "current" {}

# AKS Automatic Cluster using Azure Verified Module
module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.4.2"

  name      = local.cluster_name
  location  = var.location
  parent_id = azurerm_resource_group.main.id

  # Kubernetes Version (1.32 - KubernetesOfficial support, works with Standard tier)
  kubernetes_version = "1.32"

  # AKS Automatic SKU
  sku = {
    name = "Automatic"
    tier = "Standard"
  }

  # Node Auto-Provisioning (AKS Automatic feature)
  node_provisioning_profile = {
    mode = "Auto"
  }

  # Auto-upgrade
  auto_upgrade_profile = {
    upgrade_channel         = "stable"
    node_os_upgrade_channel = "NodeImage"
  }

  # Network Configuration (Required for modern AKS)
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_dataplane   = "cilium"
    outbound_type       = "managedNATGateway"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  # AAD Integration & RBAC
  aad_profile = {
    managed           = true
    enable_azure_rbac = true
  }

  # Disable local accounts (require Azure AD)
  disable_local_accounts = true

  # OIDC Issuer for Workload Identity
  oidc_issuer_profile = {
    enabled = true
  }

  # Azure Policy
  addon_profile_azure_policy = {
    enabled = true
  }

  # Key Vault Secrets Provider
  addon_profile_key_vault_secrets_provider = {
    enabled = true
    config = {
      enable_secret_rotation = true
    }
  }

  # Storage CSI Drivers (for Elasticsearch persistence)
  storage_profile = {
    disk_driver_enabled         = true
    file_driver_enabled         = true
    blob_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  # Istio Service Mesh (AKS Managed)
  service_mesh_profile = {
    mode = "Istio"
    istio = {
      revisions = ["asm-1-28"]
      components = {
        ingress_gateways = [
          {
            enabled = true
            mode    = "External"
          }
        ]
      }
    }
  }

  # Monitoring
  azure_monitor_profile = {
    metrics = {
      enabled = true
    }
  }

  # Managed Identities
  managed_identities = {
    system_assigned = true
  }

  # Default Node Pool (System)
  # NOTE:
  # - We use Standard_D4s_v5 instead of Standard_D4lds_v5 because AKS Automatic
  #   imposes constraints on ephemeral/local disks for system pools (ephemeral OS
  #   disk configuration on local SSD is not supported for Automatic clusters).
  # - This means the node's temporary/ephemeral storage is backed by remote Premium
  #   SSD instead of local NVMe, trading lower latency (~1ms) for higher latency
  #   (~5–10ms) and potential additional managed disk costs.
  # - This trade‑off is accepted here to keep the system pool compliant with AKS
  #   Automatic requirements; stateful workloads rely on dedicated Karpenter pools.
  default_agent_pool = {
    name                         = "system"
    vm_size                      = var.system_pool_vm_size
    count_of                     = 2
    os_sku                       = "AzureLinux"
    availability_zones           = var.system_pool_availability_zones
    only_critical_addons_enabled = true
  }

  # Stateful workloads use Karpenter NodePool (NAP) instead of traditional VMSS pool.
  # See platform/k8s_karpenter.tf for the NodePool + AKSNodeClass CRDs.

  tags = local.common_tags
}

# Assign deploying user as Cluster Admin to avoid RBAC propagation delays
# This ensures the user can immediately interact with the cluster after creation
resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = module.aks.resource_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Azure Policy Exemption: Probe enforcement for CNPG operator Jobs
# CNPG creates short-lived initdb/join Jobs that cannot have health probes.
# AKS Automatic enforces probes on all pods via deployment safeguards.
# This exemption removes the probe constraint so CNPG Jobs can run.
resource "azurerm_resource_policy_exemption" "cnpg_probe_exemption" {
  name                            = "cnpg-probe-exemption"
  resource_id                     = module.aks.resource_id
  policy_assignment_id            = "${module.aks.resource_id}/providers/Microsoft.Authorization/policyAssignments/aks-deployment-safeguards-policy-assignment"
  exemption_category              = "Waiver"
  display_name                    = "CNPG operator Job probe exemption"
  description                     = "CNPG operator creates short-lived initdb/join Jobs without probes. Jobs are one-shot tasks where probes are not meaningful."
  policy_definition_reference_ids = ["ensureProbesConfiguredInKubernetesCluster"]
}
