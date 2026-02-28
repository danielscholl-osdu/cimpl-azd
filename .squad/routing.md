# Routing Rules

| Domain | Agent | Examples |
|--------|-------|----------|
| AKS cluster, networking, RBAC | Holden 🏗️ | infra/*.tf changes, AKS config, Karpenter, Istio mesh config |
| Middleware charts | Amos 🔧 | `software/stack/charts/{elastic,postgresql,redis,rabbitmq,minio,keycloak,airflow}/`, safeguards compliance for middleware |
| Gateway, ingress, TLS | Amos 🔧 | `software/stack/charts/gateway/main.tf`, HTTPRoute, cert-manager integration |
| OSDU common resources | Amos 🔧 | `software/stack/charts/osdu-common/main.tf` (namespace, shared secrets, ConfigMaps) |
| Postrender framework | Amos 🔧 | `software/stack/kustomize/postrender.sh`, `software/stack/kustomize/components/` |
| OSDU service porting | Alex 🛠️ | `software/stack/osdu.tf` module blocks, `software/stack/kustomize/services/<service>/` overlays |
| Service Helm module | Alex 🛠️ | `software/stack/modules/osdu-service/` — reusable wrapper for all OSDU services |
| Service dependency chains | Alex 🛠️ | Service ordering, depends_on, enable/disable flags in `software/stack/variables.tf` |
| Feature flags + variables | Alex 🛠️ | `software/stack/variables.tf` (enable_<service>, credentials, config) |
| Architecture, cross-layer decisions | Holden 🏗️ | Layer boundaries, state management, deployment strategy, review gates |
| Code review, PR review | Holden 🏗️ | Terraform review, safeguards compliance review |
| Safeguards compliance testing | Drummer 🧪 | Terraform fmt/validate, AKS safeguards verification, deployment verification |
| Deployment testing | Drummer 🧪 | Pre-provision checks, post-provision verification, smoke tests |
| PowerShell scripts | Drummer 🧪 | scripts/*.ps1 validation, $LASTEXITCODE checks |
