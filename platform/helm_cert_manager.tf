locals {
  active_cluster_issuer = var.use_letsencrypt_production ? "letsencrypt-prod" : "letsencrypt-staging"
}

# cert-manager for TLS certificate management
resource "helm_release" "cert_manager" {
  count            = var.enable_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.19.3"
  namespace        = "platform"
  create_namespace = false

  depends_on = [kubernetes_namespace.platform]

  # Use postrender to inject health probes for cainjector
  # The upstream chart doesn't support probe configuration for cainjector
  postrender = {
    binary_path = "${path.module}/postrender-cert-manager.sh"
  }

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    # Disable startupapicheck - the post-install Job fails AKS Automatic safeguards
    # which require probes on all containers (Jobs shouldn't have probes as they run to completion)
    {
      name  = "startupapicheck.enabled"
      value = "false"
    },
    # Enable Gateway API support for ACME HTTP-01 solver (v1.15+ config flag)
    {
      name  = "config.enableGatewayAPI"
      value = "true"
    },
    # Controller resources (AKS Automatic safeguards compliance)
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
    # Webhook resources
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
    # CAInjector resources
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
              gatewayHTTPRoute:
                parentRefs:
                  - name: istio
                    namespace: aks-istio-ingress
                    kind: Gateway
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
              gatewayHTTPRoute:
                parentRefs:
                  - name: istio
                    namespace: aks-istio-ingress
                    kind: Gateway
  YAML

  depends_on = [helm_release.cert_manager]
}

# Output the active ClusterIssuer name
output "cluster_issuer_name" {
  value = var.enable_cert_manager ? local.active_cluster_issuer : ""
}

output "cluster_issuer_staging_name" {
  value = var.enable_cert_manager ? "letsencrypt-staging" : ""
}
