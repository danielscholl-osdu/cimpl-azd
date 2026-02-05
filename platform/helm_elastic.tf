# ECK Operator
resource "helm_release" "elastic_operator" {
  count            = var.enable_elasticsearch ? 1 : 0
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

  # Postrender with kustomize to inject health probes for AKS Automatic safeguards compliance
  # The ECK operator chart does not expose probe configuration, so we use kustomize to patch
  # the StatefulSet with tcpSocket probes on webhook port 9443
  postrender {
    binary_path = "${path.module}/kustomize/eck-operator-postrender.sh"
  }

  # Ignore changes for imported resources to avoid safeguards conflicts
  lifecycle {
    ignore_changes = all
  }
}

# Namespace for Elasticsearch
resource "kubernetes_namespace" "elastic_search" {
  count = var.enable_elasticsearch ? 1 : 0
  metadata {
    name = "elastic-search"
    labels = {
      "istio-injection" = "enabled"
    }
  }

}

# Istio STRICT mTLS for Elasticsearch namespace
resource "kubectl_manifest" "elasticsearch_peer_authentication" {
  count = var.enable_elasticsearch ? 1 : 0

  yaml_body = <<-EOF
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: elasticsearch-strict-mtls
      namespace: elastic-search
    spec:
      mtls:
        mode: STRICT
  EOF

  depends_on = [kubernetes_namespace.elastic_search]
}

# Custom StorageClass for Elasticsearch (Premium LRS with Retain policy)
# IMPORTANT: Uses Azure Managed Disks via disk.csi.azure.com - KEYLESS by design
# Managed Disks use the AKS cluster's managed identity, NOT storage account keys
# This is compliant with security standards requiring no shared keys
# NOTE: diskEncryptionType removed - causes provisioning failures when DiskEncryptionSetID not set
resource "kubectl_manifest" "elastic_storage_class" {
  count     = var.enable_elasticsearch ? 1 : 0
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

}

# Elasticsearch Cluster
resource "kubectl_manifest" "elasticsearch" {
  count     = var.enable_elasticsearch ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: elasticsearch.k8s.elastic.co/v1
    kind: Elasticsearch
    metadata:
      name: elasticsearch
      namespace: elastic-search
    spec:
      version: 8.15.2
      http:
        # Configure HTTP service selector to be unique from other services
        # Required for AKS Automatic UniqueServiceSelector safeguard compliance
        service:
          spec:
            selector:
              common.k8s.elastic.co/type: elasticsearch
              elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
              elasticsearch.service/http: "true"
        tls:
          selfSignedCertificate:
            disabled: true
      transport:
        # Configure transport service selector to be unique from other services
        # Required for AKS Automatic UniqueServiceSelector safeguard compliance
        service:
          spec:
            selector:
              common.k8s.elastic.co/type: elasticsearch
              elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
              elasticsearch.service/transport: "true"
      # ============================================================================
      # IMPORTANT: UniqueServiceSelector Compliance Labels
      # ============================================================================
      # Each nodeSet MUST include these labels in podTemplate.metadata.labels:
      #   - elasticsearch.service/http: "true"
      #   - elasticsearch.service/transport: "true"
      #
      # These labels are referenced in THREE places that must stay in sync:
      #   1. spec.http.service.spec.selector (above)
      #   2. spec.transport.service.spec.selector (above)
      #   3. nodeSets[*].podTemplate.metadata.labels (below, per nodeSet)
      #
      # If you add a new nodeSet without these labels, pods in that nodeSet will:
      #   - NOT be reachable via elasticsearch-es-http service
      #   - NOT be reachable via elasticsearch-es-transport service
      #   - Potentially fail to join the cluster properly
      #
      # Verify after changes: kubectl get svc -n elastic-search -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.selector}{"\n"}{end}'
      # ============================================================================
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
            metadata:
              labels:
                # Unique labels for service selector differentiation
                # Each service has its own label for UniqueServiceSelector compliance
                elasticsearch.service/http: "true"
                elasticsearch.service/transport: "true"
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
              # Topology spread for AKS Automatic safeguards compliance (3 replicas)
              topologySpreadConstraints:
                - maxSkew: 1
                  topologyKey: topology.kubernetes.io/zone
                  whenUnsatisfiable: ScheduleAnyway
                  labelSelector:
                    matchLabels:
                      elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
                - maxSkew: 1
                  topologyKey: kubernetes.io/hostname
                  whenUnsatisfiable: ScheduleAnyway
                  labelSelector:
                    matchLabels:
                      elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
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
                  # Health probes for AKS Automatic safeguards compliance
                  readinessProbe:
                    httpGet:
                      path: /
                      port: 9200
                      scheme: HTTP
                    initialDelaySeconds: 30
                    periodSeconds: 10
                    timeoutSeconds: 5
                    failureThreshold: 3
                  livenessProbe:
                    httpGet:
                      path: /
                      port: 9200
                      scheme: HTTP
                    initialDelaySeconds: 60
                    periodSeconds: 30
                    timeoutSeconds: 10
                    failureThreshold: 3
  YAML

  depends_on = [
    helm_release.elastic_operator,
    kubernetes_namespace.elastic_search,
    kubectl_manifest.elastic_storage_class
  ]
}

# Kibana
resource "kubectl_manifest" "kibana" {
  count     = var.enable_elasticsearch ? 1 : 0
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
          # Pod security context for AKS Automatic safeguards compliance
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
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
              # Health probes for AKS Automatic safeguards compliance
              readinessProbe:
                httpGet:
                  path: /api/status
                  port: 5601
                  scheme: HTTP
                initialDelaySeconds: 30
                periodSeconds: 10
                timeoutSeconds: 5
                failureThreshold: 3
              livenessProbe:
                httpGet:
                  path: /api/status
                  port: 5601
                  scheme: HTTP
                initialDelaySeconds: 60
                periodSeconds: 30
                timeoutSeconds: 10
                failureThreshold: 3
  YAML

  depends_on = [kubectl_manifest.elasticsearch]
}
