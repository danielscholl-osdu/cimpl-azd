locals {
  active_cluster_issuer = var.use_letsencrypt_production ? "letsencrypt-prod" : "letsencrypt-staging"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.19.3"
  namespace        = var.namespace
  create_namespace = false

  postrender = {
    binary_path = "${path.module}/postrender.sh"
  }

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "startupapicheck.enabled"
      value = "false"
    },
    {
      name  = "config.enableGatewayAPI"
      value = "true"
    },
    {
      name  = "global.leaderElection.namespace"
      value = var.namespace
    },
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "resources.limits.memory"
      value = "256Mi"
    },
    {
      name  = "webhook.resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "webhook.resources.requests.memory"
      value = "64Mi"
    },
    {
      name  = "webhook.resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "webhook.resources.limits.memory"
      value = "128Mi"
    },
    {
      name  = "cainjector.resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "cainjector.resources.requests.memory"
      value = "64Mi"
    },
    {
      name  = "cainjector.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "cainjector.resources.limits.memory"
      value = "256Mi"
    },
  ]
}

resource "kubectl_manifest" "cluster_issuer_staging" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-staging
    spec:
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-staging
        solvers:
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - name: istio
                    namespace: aks-istio-ingress
                    kind: Gateway
  YAML

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
          - http01:
              gatewayHTTPRoute:
                parentRefs:
                  - name: istio
                    namespace: aks-istio-ingress
                    kind: Gateway
  YAML

  depends_on = [helm_release.cert_manager]
}
