# Keycloak identity provider using Bitnami Helm chart

resource "random_password" "keycloak_admin" {
  count            = var.enable_keycloak && var.keycloak_admin_password == "" ? 1 : 0
  length           = 32
  special          = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

locals {
  keycloak_admin_password = var.enable_keycloak ? (var.keycloak_admin_password != "" ? var.keycloak_admin_password : random_password.keycloak_admin[0].result) : ""
}

resource "kubernetes_namespace" "keycloak" {
  count = var.enable_keycloak ? 1 : 0
  metadata {
    name = "keycloak"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Istio STRICT mTLS for Keycloak namespace
resource "kubectl_manifest" "keycloak_peer_authentication" {
  count = var.enable_keycloak ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata:
      name: keycloak-strict-mtls
      namespace: keycloak
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [kubernetes_namespace.keycloak]
}

data "kubernetes_secret" "keycloak_db_source" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-db-credentials"
    namespace = "postgresql"
  }

  depends_on = [kubernetes_secret.keycloak_db]
}

resource "kubernetes_secret" "keycloak_db_copy" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-db-credentials"
    namespace = "keycloak"
  }

  data = {
    username = data.kubernetes_secret.keycloak_db_source[0].data["username"]
    password = data.kubernetes_secret.keycloak_db_source[0].data["password"]
  }

  depends_on = [
    kubernetes_namespace.keycloak,
    data.kubernetes_secret.keycloak_db_source
  ]
}

resource "kubernetes_secret" "keycloak_admin" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-admin-credentials"
    namespace = "keycloak"
  }

  data = {
    "admin-password" = local.keycloak_admin_password
  }

  depends_on = [kubernetes_namespace.keycloak]
}

resource "kubernetes_config_map" "keycloak_realm" {
  count = var.enable_keycloak ? 1 : 0

  metadata {
    name      = "keycloak-realm"
    namespace = "keycloak"
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

  depends_on = [kubernetes_namespace.keycloak]
}

resource "helm_release" "keycloak" {
  count            = var.enable_keycloak ? 1 : 0
  name             = "keycloak"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "keycloak"
  version          = "25.3.2"
  namespace        = "keycloak"
  create_namespace = false
  timeout          = 600

  values = [<<-YAML
    global:
      security:
        allowInsecureImages: true

    image:
      registry: docker.io
      repository: bitnamilegacy/keycloak
      tag: 26.3.3-debian-12-r0

    auth:
      adminUser: admin
      existingSecret: keycloak-admin-credentials
      passwordSecretKey: admin-password

    postgresql:
      enabled: false

    externalDatabase:
      host: postgresql-rw.postgresql.svc.cluster.local
      port: 5432
      user: keycloak
      database: keycloak
      existingSecret: keycloak-db-credentials
      existingSecretUserKey: username
      existingSecretPasswordKey: password

    extraEnvVars:
      - name: KEYCLOAK_EXTRA_ARGS
        value: "--import-realm"

    extraVolumes:
      - name: realm-import
        configMap:
          name: keycloak-realm

    extraVolumeMounts:
      - name: realm-import
        mountPath: /opt/bitnami/keycloak/data/import
        readOnly: true

    replicaCount: 1

    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: "2"
        memory: 2Gi

    podSecurityContext:
      enabled: true
      fsGroup: 1001
      fsGroupChangePolicy: Always
      seccompProfile:
        type: RuntimeDefault

    containerSecurityContext:
      enabled: true
      runAsUser: 1001
      runAsGroup: 1001
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault

    livenessProbe:
      enabled: true
      initialDelaySeconds: 120
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 6

    readinessProbe:
      enabled: true
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 6

    startupProbe:
      enabled: true
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 12

    tolerations:
      - effect: NoSchedule
        key: workload
        value: stateful

    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: agentpool
                  operator: In
                  values:
                    - stateful

    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app.kubernetes.io/instance: keycloak
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app.kubernetes.io/instance: keycloak
  YAML
  ]

  depends_on = [
    kubernetes_namespace.keycloak,
    kubernetes_secret.keycloak_admin,
    kubernetes_secret.keycloak_db_copy,
    kubernetes_config_map.keycloak_realm,
    kubectl_manifest.karpenter_nodepool_stateful,
    kubectl_manifest.karpenter_aksnodeclass_stateful
  ]
}

resource "null_resource" "keycloak_jwks_wait" {
  count = var.enable_keycloak ? 1 : 0

  triggers = {
    keycloak_release = helm_release.keycloak[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      namespace="keycloak"
      selector="app.kubernetes.io/instance=keycloak"
      for _ in {1..60}; do
        pod=$(kubectl -n "$${namespace}" get pods -l "$${selector}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [ -n "$${pod}" ]; then
          if kubectl -n "$${namespace}" exec "$${pod}" -- /bin/sh -c 'if command -v curl >/dev/null 2>&1; then curl -sf http://localhost:8080/realms/osdu/protocol/openid-connect/certs >/dev/null; elif command -v wget >/dev/null 2>&1; then wget -qO- http://localhost:8080/realms/osdu/protocol/openid-connect/certs >/dev/null; else exit 1; fi'; then
            exit 0
          fi
        fi
        sleep 10
      done
      echo "Keycloak JWKS endpoint not ready" >&2
      exit 1
    EOT
  }

  depends_on = [helm_release.keycloak]
}
