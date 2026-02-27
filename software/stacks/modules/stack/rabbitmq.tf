# RabbitMQ messaging broker (per-stack instance)
# Note: Istio sidecar disabled for RabbitMQ (requires NET_ADMIN/NET_RAW, blocked by AKS Automatic)

resource "kubernetes_secret" "rabbitmq_credentials" {
  count = var.enable_rabbitmq ? 1 : 0

  metadata {
    name      = "rabbitmq-credentials"
    namespace = local.platform_namespace
  }

  data = {
    username      = var.rabbitmq_username
    password      = var.rabbitmq_password
    erlang-cookie = var.rabbitmq_erlang_cookie
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "rabbitmq_config" {
  count = var.enable_rabbitmq ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: rabbitmq-config
      namespace: ${local.platform_namespace}
    data:
      rabbitmq-env.conf: |
        USE_LONGNAME=true
      rabbitmq.conf: |
        cluster_formation.peer_discovery_backend = dns
        cluster_formation.dns.hostname = rabbitmq-headless.${local.platform_namespace}.svc.cluster.local
        cluster_partition_handling = autoheal
        listeners.tcp.default = 5672
        management.tcp.port = 15672
        log.console = true
        log.console.level = info
      enabled_plugins: |
        [rabbitmq_peer_discovery_common,rabbitmq_management,rabbitmq_prometheus].
  YAML

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "rabbitmq_headless_service" {
  count = var.enable_rabbitmq ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: rabbitmq-headless
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: rabbitmq
    spec:
      type: ClusterIP
      clusterIP: None
      publishNotReadyAddresses: true
      selector:
        app.kubernetes.io/name: rabbitmq
      ports:
        - name: amqp
          port: 5672
          targetPort: amqp
        - name: epmd
          port: 4369
          targetPort: epmd
        - name: dist
          port: 25672
          targetPort: dist
        - name: http-stats
          port: 15672
          targetPort: stats
  YAML

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "rabbitmq_client_service" {
  count = var.enable_rabbitmq ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: rabbitmq
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: rabbitmq
    spec:
      type: ClusterIP
      selector:
        app.kubernetes.io/name: rabbitmq
        rabbitmq.service/variant: client
      ports:
        - name: amqp
          port: 5672
          targetPort: amqp
        - name: http-stats
          port: 15672
          targetPort: stats
  YAML

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "rabbitmq_statefulset" {
  count = var.enable_rabbitmq ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: rabbitmq
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: rabbitmq
    spec:
      serviceName: rabbitmq-headless
      replicas: 3
      podManagementPolicy: OrderedReady
      selector:
        matchLabels:
          app.kubernetes.io/name: rabbitmq
      template:
        metadata:
          labels:
            app.kubernetes.io/name: rabbitmq
            rabbitmq.service/variant: client
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          enableServiceLinks: false
          securityContext:
            runAsUser: 999
            runAsGroup: 999
            fsGroup: 999
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
                  app.kubernetes.io/name: rabbitmq
            - maxSkew: 1
              topologyKey: kubernetes.io/hostname
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: rabbitmq
          containers:
            - name: rabbitmq
              image: rabbitmq:4.1.0-management-alpine
              command: ["sh", "-c"]
              args:
                - |
                  echo "$RABBITMQ_ERLANG_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
                  chmod 600 /var/lib/rabbitmq/.erlang.cookie
                  exec docker-entrypoint.sh rabbitmq-server
              ports:
                - containerPort: 5672
                  name: amqp
                - containerPort: 15672
                  name: stats
                - containerPort: 4369
                  name: epmd
                - containerPort: 25672
                  name: dist
              env:
                - name: RABBITMQ_DEFAULT_USER
                  valueFrom:
                    secretKeyRef:
                      name: rabbitmq-credentials
                      key: username
                - name: RABBITMQ_DEFAULT_PASS
                  valueFrom:
                    secretKeyRef:
                      name: rabbitmq-credentials
                      key: password
                - name: RABBITMQ_ERLANG_COOKIE
                  valueFrom:
                    secretKeyRef:
                      name: rabbitmq-credentials
                      key: erlang-cookie
                - name: RABBITMQ_USE_LONGNAME
                  value: "true"
                - name: MY_POD_NAME
                  valueFrom:
                    fieldRef:
                      fieldPath: metadata.name
                - name: RABBITMQ_NODENAME
                  value: "rabbit@$(MY_POD_NAME).rabbitmq-headless.${local.platform_namespace}.svc.cluster.local"
              volumeMounts:
                - name: data
                  mountPath: /var/lib/rabbitmq
                - name: env-config
                  mountPath: /etc/rabbitmq/rabbitmq-env.conf
                  subPath: rabbitmq-env.conf
                - name: config
                  mountPath: /etc/rabbitmq/conf.d/10-custom.conf
                  subPath: rabbitmq.conf
                - name: plugins
                  mountPath: /etc/rabbitmq/enabled_plugins
                  subPath: enabled_plugins
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
              livenessProbe:
                exec:
                  command: ["rabbitmq-diagnostics", "status"]
                initialDelaySeconds: 120
                periodSeconds: 30
                timeoutSeconds: 10
                failureThreshold: 6
              readinessProbe:
                exec:
                  command: ["rabbitmq-diagnostics", "check_port_connectivity"]
                initialDelaySeconds: 20
                periodSeconds: 10
                timeoutSeconds: 10
                failureThreshold: 6
              securityContext:
                allowPrivilegeEscalation: false
                capabilities:
                  drop: ["ALL"]
                runAsNonRoot: true
                seccompProfile:
                  type: RuntimeDefault
          volumes:
            - name: env-config
              configMap:
                name: rabbitmq-config
            - name: config
              configMap:
                name: rabbitmq-config
            - name: plugins
              configMap:
                name: rabbitmq-config
    volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: rabbitmq-storageclass
          resources:
            requests:
              storage: 8Gi
  YAML

  depends_on = [
    kubernetes_namespace.platform,
    kubernetes_secret.rabbitmq_credentials,
    kubectl_manifest.rabbitmq_config,
    kubectl_manifest.rabbitmq_headless_service,
    kubectl_manifest.rabbitmq_client_service,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}
