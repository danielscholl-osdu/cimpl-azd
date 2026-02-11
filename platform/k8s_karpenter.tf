# Karpenter NodePool + AKSNodeClass for stateful workloads
#
# Replaces the traditional VMSS-based stateful node pool from infra/.
# NAP (Node Auto-Provisioning, powered by Karpenter) dynamically selects
# from multiple D-series VM SKUs per zone, eliminating
# OverconstrainedZonalAllocationRequest failures caused by pinning a single SKU.

resource "kubectl_manifest" "karpenter_nodepool_stateful" {
  count = var.enable_stateful_nodepool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: stateful
    spec:
      template:
        metadata:
          labels:
            agentpool: stateful
        spec:
          taints:
            - key: workload
              value: stateful
              effect: NoSchedule
          requirements:
            - key: karpenter.azure.com/sku-family
              operator: In
              values: ["D"]
            - key: karpenter.azure.com/sku-cpu
              operator: In
              values: ["4", "8"]
            - key: karpenter.azure.com/sku-storage-premium-capable
              operator: In
              values: ["true"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
          nodeClassRef:
            group: karpenter.azure.com
            kind: AKSNodeClass
            name: stateful
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 5m
      limits:
        cpu: "64"
        memory: 256Gi
  YAML

  wait = true
}

resource "kubectl_manifest" "karpenter_aksnodeclass_stateful" {
  count = var.enable_stateful_nodepool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.azure.com/v1alpha2
    kind: AKSNodeClass
    metadata:
      name: stateful
    spec:
      imageFamily: AzureLinux
      osDiskSizeGB: 128
  YAML

  wait = true
}
