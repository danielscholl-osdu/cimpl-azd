# Elasticsearch + Kibana CRs (per-stack instance)

resource "kubectl_manifest" "elasticsearch" {
  count     = var.enable_elasticsearch ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: elasticsearch.k8s.elastic.co/v1
    kind: Elasticsearch
    metadata:
      name: elasticsearch
      namespace: ${local.platform_namespace}
    spec:
      version: 8.15.2
      http:
        service:
          spec:
            selector:
              common.k8s.elastic.co/type: elasticsearch
              elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
              elasticsearch.service/http: "true"
        tls:
          selfSignedCertificate: {}
      transport:
        service:
          spec:
            selector:
              common.k8s.elastic.co/type: elasticsearch
              elasticsearch.k8s.elastic.co/cluster-name: elasticsearch
              elasticsearch.service/transport: "true"
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
                elasticsearch.service/http: "true"
                elasticsearch.service/transport: "true"
            spec:
              securityContext:
                fsGroup: 1000
                runAsNonRoot: true
                seccompProfile:
                  type: RuntimeDefault
              tolerations:
                - effect: NoSchedule
                  key: stack
                  value: "${var.stack_id}"
              affinity:
                nodeAffinity:
                  requiredDuringSchedulingIgnoredDuringExecution:
                    nodeSelectorTerms:
                      - matchExpressions:
                          - key: agentpool
                            operator: In
                            values:
                              - ${local.nodepool_name}
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
                  livenessProbe:
                    tcpSocket:
                      port: 9200
                    initialDelaySeconds: 90
                    periodSeconds: 30
                    timeoutSeconds: 10
                    failureThreshold: 3
  YAML

  depends_on = [
    kubernetes_namespace.platform,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}

resource "kubectl_manifest" "kibana" {
  count     = var.enable_elasticsearch ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: kibana.k8s.elastic.co/v1
    kind: Kibana
    metadata:
      name: kibana
      namespace: ${local.platform_namespace}
    spec:
      version: 8.15.2
      count: 1
      elasticsearchRef:
        name: elasticsearch
%{if local.has_ingress_hostname~}
      config:
        server.publicBaseUrl: "https://${local.kibana_hostname}"
%{endif~}
      http:
        tls:
          selfSignedCertificate:
            disabled: true
      podTemplate:
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          tolerations:
            - effect: NoSchedule
              key: stack
              value: "${var.stack_id}"
          containers:
            - name: kibana
              resources:
                requests:
                  memory: 1Gi
                  cpu: 0.5
                limits:
                  memory: 2Gi
                  cpu: 1
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
