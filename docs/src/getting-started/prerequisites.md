# Prerequisites

Setup takes approximately 5 minutes. These instructions have been tested on macOS and Linux (zsh/bash).

## Required Tools

| Tool | Version | Purpose | Required For |
|------|---------|---------|--------------|
| [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) | v2.50+ | Azure resource management | `azd up` |
| [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | v1.5+ | Deployment orchestration | `azd up` |
| [Terraform](https://www.terraform.io/downloads) | v1.5+ | Infrastructure as Code | `azd up` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | latest | Kubernetes management | Verification & debugging |
| [kubelogin](https://github.com/Azure/kubelogin) | latest | Azure AD authentication for AKS | Verification & debugging |
| [Helm](https://helm.sh/docs/intro/install/) | v3.12+ | Kubernetes package management | Verification & debugging |
| [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) | latest | Postrender patches for AKS safeguards | `azd up` |
| [PowerShell Core](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) | v7+ | Deployment scripts | `azd up` |

## Azure Permissions

You need the following Azure permissions:

- **Subscription**: Contributor (to create resource groups and AKS clusters)
- **AKS**: Azure Kubernetes Service RBAC Cluster Admin
- **DNS Zone**: DNS Zone Contributor (if using ExternalDNS with a cross-subscription zone)

!!! warning "Common failure modes"
    - **Wrong subscription selected**: `az account show` returns a different subscription than intended. Fix with `az account set --subscription`.
    - **Missing AKS RBAC Cluster Admin**: `kubectl` commands fail with 403. Grant the role on the AKS resource.
    - **DNS Zone Contributor not granted**: ExternalDNS cannot create DNS records in a cross-subscription zone. Grant the role on the DNS zone resource.

## Verify Installation

```bash
# Check all tools
az version
azd version
terraform version
kubectl version --client
kubelogin --version
helm version
kustomize version
pwsh --version
```

**Next step:** [Quick Start](quickstart.md). Deploy your first environment in ~30 minutes.
