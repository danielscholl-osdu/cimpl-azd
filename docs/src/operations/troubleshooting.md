# Troubleshooting

## Common Issues

### Safeguards Blocking Deployments

The two-phase behavioral gate in post-provision handles Gatekeeper reconciliation automatically. If it times out, re-run `azd provision` to retry the gate and platform deployment.

### OverconstrainedZonalAllocationRequest

AKS Automatic mandates ephemeral OS disks on system pool VMs. Combined with 3-zone pinning and a specific VM SKU, this can cause `OverconstrainedZonalAllocationRequest` failures when any zone lacks capacity.

**Workaround:** Reduce the system pool to zones with available capacity:

```bash
# Skip zone 2 (example for centralus capacity issues)
azd env set TF_VAR_system_pool_availability_zones '["1", "3"]'

# Or try a different VM size
azd env set TF_VAR_system_pool_vm_size 'Standard_D4as_v5'

# Then redeploy
azd up
```

The stateful workload pool uses Karpenter (NAP) with dynamic SKU selection, so it is not affected by this issue.

### RBAC Permission Denied

Grant the required role to your user:

```bash
az role assignment create \
  --assignee "<your-user-object-id>" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<cluster>"
```

### Helm Timeout

Increase timeout or verify node pool capacity. Check for pending pods:

```bash
kubectl get pods -A | grep -v Running
kubectl describe pod <pod-name> -n <namespace>
```

### CNPG initdb Blocked by Safeguards

CNPG creates short-lived initdb/join Jobs that cannot have health probes. An Azure Policy Exemption is configured in `infra/aks.tf` to waive the probe requirement. If you still see issues, verify the exemption exists:

```bash
az policy exemption list --resource-group <rg-name> --query "[?contains(name, 'cnpg')]"
```

## Useful Commands

```bash
# Verify cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check component status
kubectl get elasticsearch -n elasticsearch
kubectl get cluster -n postgresql
kubectl get pods -n rabbitmq
kubectl get pods -n platform -l 'minio.service/variant=api'

# View safeguards violations
kubectl get constraints -o wide

# Check Istio ingress
kubectl get svc -n aks-istio-ingress
kubectl get gateway -A
kubectl get httproute -A

# Get Elasticsearch password
kubectl get secret elasticsearch-es-elastic-user -n elasticsearch \
  -o jsonpath='{.data.elastic}' | base64 -d

# Manual platform deployment
cd platform && terraform apply
```
