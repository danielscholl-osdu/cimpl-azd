# Prerequisites

## Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) | v2.50+ | Azure resource management |
| [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | v1.5+ | Deployment orchestration |
| [Terraform](https://www.terraform.io/downloads) | v1.5+ | Infrastructure as Code |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | latest | Kubernetes management |
| [kubelogin](https://github.com/Azure/kubelogin) | latest | Azure AD authentication for AKS |
| [Helm](https://helm.sh/docs/intro/install/) | v3.12+ | Kubernetes package management |
| [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) | latest | ECK operator probe injection |
| [PowerShell Core](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) | v7+ | Deployment scripts |

## Azure Permissions

You need the following Azure permissions:

- **Subscription**: Contributor (to create resource groups and AKS clusters)
- **AKS**: Azure Kubernetes Service RBAC Cluster Admin
- **DNS Zone**: DNS Zone Contributor (if using ExternalDNS with a cross-subscription zone)

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
