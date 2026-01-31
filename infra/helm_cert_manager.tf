# cert-manager for TLS certificate management
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.0"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  # Controller resources (AKS Automatic safeguards compliance)
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  # Webhook resources
  set {
    name  = "webhook.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "webhook.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "webhook.resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "webhook.resources.limits.memory"
    value = "128Mi"
  }

  # CAInjector resources
  set {
    name  = "cainjector.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "cainjector.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "cainjector.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "cainjector.resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [module.aks]
}

# ClusterIssuer for Let's Encrypt
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
              ingress:
                class: istio
  YAML

  depends_on = [helm_release.cert_manager]
}
