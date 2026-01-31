# ECK Operator
resource "helm_release" "elastic_operator" {
  name             = "elastic-operator"
  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  version          = "2.16.0"
  namespace        = "elastic-system"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Resources for AKS Automatic safeguards compliance
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "150Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [module.aks]
}

# Namespace for Elasticsearch
resource "kubernetes_namespace" "elastic_search" {
  metadata {
    name = "elastic-search"
    labels = {
      "istio-injection" = "enabled"
    }
  }

  depends_on = [module.aks]
}

# Custom StorageClass for Elasticsearch (Premium LRS with Retain policy)
# IMPORTANT: Uses Azure Managed Disks via disk.csi.azure.com - KEYLESS by design
# Managed Disks use the AKS cluster's managed identity, NOT storage account keys
# This is compliant with security standards requiring no shared keys
# NOTE: diskEncryptionType removed - causes provisioning failures when DiskEncryptionSetID not set
resource "kubectl_manifest" "elastic_storage_class" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: es-storageclass
      labels:
        app: elasticsearch
    parameters:
      skuName: Premium_LRS
      kind: Managed
      cachingMode: ReadOnly
      tags: costcenter=dev,app=elasticsearch
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML

  depends_on = [module.aks]
}

# Elasticsearch Cluster
resource "kubectl_manifest" "elasticsearch" {
  yaml_body = <<-YAML
    apiVersion: elasticsearch.k8s.elastic.co/v1
    kind: Elasticsearch
    metadata:
      name: elasticsearch
      namespace: elastic-search
    spec:
      version: 8.15.2
      http:
        tls:
          selfSignedCertificate:
            disabled: true
      nodeSets:
        - name: default
          count: 3
          volumeClaimTemplates:
            - metadata:
                name: elasticsearch-data
              spec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 128Gi
                storageClassName: es-storageclass
          config:
            node.roles: ["master", "data", "ingest"]
            node.store.allow_mmap: false
          podTemplate:
            spec:
              # fsGroup ensures the mounted PVC is writable by elasticsearch user (UID 1000)
              securityContext:
                fsGroup: 1000
                runAsNonRoot: true
                seccompProfile:
                  type: RuntimeDefault
              tolerations:
                - effect: NoSchedule
                  key: app
                  value: elasticsearch
              affinity:
                nodeAffinity:
                  requiredDuringSchedulingIgnoredDuringExecution:
                    nodeSelectorTerms:
                      - matchExpressions:
                          - key: agentpool
                            operator: In
                            values:
                              - elastic
              # NOTE: sysctl init container removed - blocked by AKS Automatic safeguards
              # and not needed when node.store.allow_mmap: false is set
              containers:
                - name: elasticsearch
                  env:
                    - name: ES_JAVA_OPTS
                      value: "-Xms2g -Xmx2g"
                  resources:
                    requests:
                      memory: 4Gi
                      cpu: 1
                    limits:
                      memory: 4Gi
                      cpu: 2
  YAML

  depends_on = [
    helm_release.elastic_operator,
    kubernetes_namespace.elastic_search,
    kubectl_manifest.elastic_storage_class
  ]
}

# Kibana
resource "kubectl_manifest" "kibana" {
  yaml_body = <<-YAML
    apiVersion: kibana.k8s.elastic.co/v1
    kind: Kibana
    metadata:
      name: kibana
      namespace: elastic-search
    spec:
      version: 8.15.2
      count: 1
      elasticsearchRef:
        name: elasticsearch
      http:
        tls:
          selfSignedCertificate:
            disabled: true
      podTemplate:
        spec:
          tolerations:
            - effect: NoSchedule
              key: app
              value: elasticsearch
          containers:
            - name: kibana
              resources:
                requests:
                  memory: 1Gi
                  cpu: 0.5
                limits:
                  memory: 2Gi
                  cpu: 1
  YAML

  depends_on = [kubectl_manifest.elasticsearch]
}
