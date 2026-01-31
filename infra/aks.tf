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

  # Default Node Pool (System) - AKS Automatic uses standard_d4lds_v5 for system pool
  default_agent_pool = {
    name                         = "system"
    vm_size                      = "standard_d4lds_v5"
    count_of                     = 2
    os_sku                       = "AzureLinux"
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
  }

  # Elasticsearch Node Pool (tainted for ES workloads)
  agent_pools = {
    elastic = {
      name               = "elastic"
      vm_size            = "Standard_D4as_v5"
      count_of           = 3
      os_sku             = "AzureLinux"
      availability_zones = ["1", "2", "3"]
      node_labels = {
        "app" = "elasticsearch"
      }
      node_taints = ["app=elasticsearch:NoSchedule"]
    }
  }

  tags = local.common_tags
}

# Assign deploying user as Cluster Admin to avoid RBAC propagation delays
# This ensures the user can immediately interact with the cluster after creation
resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = module.aks.resource_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
