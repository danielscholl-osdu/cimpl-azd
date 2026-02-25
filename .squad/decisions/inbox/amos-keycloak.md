# Decision: Keycloak realm import strategy

## Context
AKS Automatic safeguards can reject Jobs without probes, which makes the chart's keycloak-config-cli job risky for realm import. We still need a predictable, Terraform-managed way to create the `osdu` realm on first boot.

## Decision
Use Keycloak's built-in realm import by setting `KEYCLOAK_EXTRA_ARGS=--import-realm` and mounting a ConfigMap containing the realm JSON at `/opt/bitnami/keycloak/data/import`.

## Consequences
- Realm import happens inside the primary Keycloak pod (no separate Job).
- The realm payload lives in `platform/helm_keycloak.tf` as `keycloak-realm` ConfigMap and can be updated later.
- JWKS readiness can be gated by polling the realm endpoint after Keycloak is running.
