# cert-manager for TLS certificate management
resource "helm_release" "cert_manager" {
  count            = var.enable_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.0"
  namespace        = "cert-manager"
  create_namespace = true

  # Use postrender to inject health probes for cainjector
  # The upstream chart doesn't support probe configuration for cainjector
  postrender {
    binary_path = "${path.module}/postrender-cert-manager.sh"
  }

  set {
    name  = "crds.enabled"
    value = "true"
  }

  # Disable startupapicheck - the post-install Job fails AKS Automatic safeguards
  # which require probes on all containers (Jobs shouldn't have probes as they run to completion)
  set {
    name  = "startupapicheck.enabled"
    value = "false"
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
}

# ============================================================================
# Let's Encrypt ClusterIssuers - Certificate Authorities for TLS Certificates
# ============================================================================
#
# This configuration provides TWO ClusterIssuers for different use cases:
#
# 1. letsencrypt-staging (DEVELOPMENT & TESTING)
#    - Use during development and testing phases
#    - Use when experimenting with certificate configuration
#    - Use to avoid Let's Encrypt production rate limits (50 certs/week)
#    - WARNING: Issues certificates NOT TRUSTED by browsers
#    - WARNING: Will show security warnings in browsers
#    - Certificates will have "Fake LE Intermediate" in the chain
#
# 2. letsencrypt-prod (PRODUCTION ONLY)
#    - Use ONLY in production environments with real domain names
#    - Issues browser-trusted certificates from Let's Encrypt
#    - Subject to rate limits: 50 certificates per registered domain per week
#    - Rate limit failures require 7-day wait period
#    - See: https://letsencrypt.org/docs/rate-limits/
#
# SWITCHING BETWEEN ISSUERS:
#   In Certificate resources, set spec.issuerRef.name to either:
#   - "letsencrypt-staging" for development/testing
#   - "letsencrypt-prod" for production
#
#   Example:
#     spec:
#       issuerRef:
#         name: letsencrypt-staging  # or letsencrypt-prod
#         kind: ClusterIssuer
#
# RECOMMENDED WORKFLOW:
#   1. Test with letsencrypt-staging first
#   2. Verify certificate issuance works correctly
#   3. Switch to letsencrypt-prod for production deployment
#   4. Monitor rate limit usage if deploying frequently
# ============================================================================

# ClusterIssuer for Let's Encrypt Staging (for testing - has relaxed rate limits)
resource "kubectl_manifest" "cluster_issuer_staging" {
  count     = var.enable_cert_manager ? 1 : 0
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
              ingress:
                class: istio
  YAML

  depends_on = [helm_release.cert_manager]
}

# ClusterIssuer for Let's Encrypt Production
resource "kubectl_manifest" "cluster_issuer" {
  count     = var.enable_cert_manager ? 1 : 0
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

# Output the ClusterIssuer names for other resources
output "cluster_issuer_name" {
  value = var.enable_cert_manager ? "letsencrypt-prod" : ""
}

output "cluster_issuer_staging_name" {
  value = var.enable_cert_manager ? "letsencrypt-staging" : ""
}
