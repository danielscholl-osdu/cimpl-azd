# Keycloak identity provider (per-stack instance)

resource "random_password" "keycloak_admin" {
  count            = var.enable_keycloak && var.keycloak_admin_password == "" ? 1 : 0
  length           = 32
  special          = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

locals {
  keycloak_admin_password = var.enable_keycloak ? (var.keycloak_admin_password != "" ? var.keycloak_admin_password : random_password.keycloak_admin[0].result) : ""
}

resource "kubernetes_secret" "keycloak_admin" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-admin-credentials"
    namespace = local.platform_namespace
  }

  data = {
    "admin-password" = local.keycloak_admin_password
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubernetes_secret" "keycloak_db_copy" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-db-credentials-copy"
    namespace = local.platform_namespace
  }

  data = {
    username = "keycloak"
    password = var.keycloak_db_password
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubernetes_config_map" "keycloak_realm" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-realm"
    namespace = local.platform_namespace
  }

  data = {
    "osdu-realm.json" = <<-JSON
      {
        "realm": "osdu",
        "enabled": true,
        "displayName": "OSDU",
        "clients": []
      }
    JSON
  }

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "keycloak_headless_service" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: keycloak-headless
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
    spec:
      type: ClusterIP
      clusterIP: None
      publishNotReadyAddresses: true
      ports:
        - name: http
          port: 8080
          targetPort: http
          protocol: TCP
      selector:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
  YAML

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "keycloak_service" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: keycloak
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
    spec:
      type: ClusterIP
      sessionAffinity: None
      ports:
        - name: http
          port: 8080
          targetPort: http
          protocol: TCP
      selector:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
        keycloak.service/variant: http
  YAML

  depends_on = [kubernetes_namespace.platform]
}

resource "kubectl_manifest" "keycloak_statefulset" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: keycloak
      namespace: ${local.platform_namespace}
      labels:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
    spec:
      replicas: 1
      serviceName: keycloak-headless
      podManagementPolicy: Parallel
      selector:
        matchLabels:
          app.kubernetes.io/name: keycloak
          app.kubernetes.io/instance: keycloak
      template:
        metadata:
          labels:
            app.kubernetes.io/name: keycloak
            app.kubernetes.io/instance: keycloak
            keycloak.service/variant: http
        spec:
          automountServiceAccountToken: false
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            runAsGroup: 0
            fsGroup: 0
            seccompProfile:
              type: RuntimeDefault
          tolerations:
            - key: stack
              operator: Equal
              value: "${var.stack_id}"
              effect: NoSchedule
          nodeSelector:
            agentpool: ${local.nodepool_name}
          containers:
            - name: keycloak
              image: "quay.io/keycloak/keycloak:26.5.4"
              imagePullPolicy: IfNotPresent
              args:
                - start
                - --import-realm
              env:
                - name: KC_BOOTSTRAP_ADMIN_USERNAME
                  value: "admin"
                - name: KC_BOOTSTRAP_ADMIN_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: keycloak-admin-credentials
                      key: admin-password
                - name: KC_DB
                  value: "postgres"
                - name: KC_DB_URL
                  value: "jdbc:postgresql://${local.postgresql_host}:5432/keycloak"
                - name: KC_DB_USERNAME
                  valueFrom:
                    secretKeyRef:
                      name: keycloak-db-credentials
                      key: username
                - name: KC_DB_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: keycloak-db-credentials
                      key: password
                - name: KC_HEALTH_ENABLED
                  value: "true"
                - name: KC_HTTP_ENABLED
                  value: "true"
                - name: KC_HTTP_PORT
                  value: "8080"
                - name: KC_HTTP_MANAGEMENT_PORT
                  value: "9000"
                - name: KC_HOSTNAME_STRICT
                  value: "false"
                - name: KC_PROXY_HEADERS
                  value: "xforwarded"
                - name: KC_CACHE
                  value: "local"
                - name: JAVA_OPTS_APPEND
                  value: "-Djgroups.dns.query=keycloak-headless.${local.platform_namespace}.svc.cluster.local"
              ports:
                - name: http
                  containerPort: 8080
                  protocol: TCP
                - name: management
                  containerPort: 9000
                  protocol: TCP
              startupProbe:
                httpGet:
                  path: /health/ready
                  port: management
                initialDelaySeconds: 30
                periodSeconds: 10
                timeoutSeconds: 5
                failureThreshold: 12
              livenessProbe:
                httpGet:
                  path: /health/live
                  port: management
                initialDelaySeconds: 0
                periodSeconds: 10
                timeoutSeconds: 5
                failureThreshold: 6
              readinessProbe:
                httpGet:
                  path: /health/ready
                  port: management
                initialDelaySeconds: 0
                periodSeconds: 10
                timeoutSeconds: 5
                failureThreshold: 6
              resources:
                requests:
                  cpu: 500m
                  memory: 1Gi
                limits:
                  cpu: "2"
                  memory: 2Gi
              securityContext:
                runAsUser: 1000
                runAsGroup: 0
                runAsNonRoot: true
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: false
                capabilities:
                  drop:
                    - ALL
                seccompProfile:
                  type: RuntimeDefault
              volumeMounts:
                - name: realm-import
                  mountPath: /opt/keycloak/data/import
                  readOnly: true
          volumes:
            - name: realm-import
              configMap:
                name: keycloak-realm
  YAML

  depends_on = [
    kubernetes_namespace.platform,
    kubernetes_secret.keycloak_admin,
    kubernetes_secret.keycloak_db_copy,
    kubernetes_config_map.keycloak_realm,
    kubectl_manifest.keycloak_headless_service,
    kubectl_manifest.cnpg_database_bootstrap,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_aksnodeclass
  ]
}

resource "null_resource" "keycloak_jwks_wait" {
  count = var.enable_keycloak ? 1 : 0

  triggers = {
    keycloak_statefulset = kubectl_manifest.keycloak_statefulset[0].uid
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      echo "Waiting for Keycloak pod to become ready..."
      kubectl wait --for=condition=Ready pod \
        -n ${local.platform_namespace} -l app.kubernetes.io/instance=keycloak \
        --timeout=600s
      echo "Keycloak is ready."
    EOT
  }

  depends_on = [kubectl_manifest.keycloak_statefulset]
}
