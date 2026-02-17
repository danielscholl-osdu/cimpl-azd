# Routing Rules

| Domain | Agent | Examples |
|--------|-------|----------|
| AKS cluster, node pools, networking, RBAC | Naomi ⚙️ | AKS config, Karpenter NodePools, ExternalDNS UAMI, CNI, Istio mesh config |
| Terraform infra layer | Naomi ⚙️ | infra/*.tf changes, provider versions, AKS SKU, outputs |
| Elasticsearch, PostgreSQL, MinIO, Redis | Amos 🔧 | platform/helm_*.tf, postrender patches, kustomize overlays, safeguards compliance for middleware |
| cert-manager, Airflow, RabbitMQ, Keycloak | Amos 🔧 | New platform components from ROSA reference, Helm chart porting |
| Istio Gateway, ingress, TLS | Amos 🔧 | platform/k8s_gateway.tf, HTTPRoute, cert-manager integration |
| OSDU service porting | Alex 🛠️ | Partition, entitlements, legal, indexer, search, schema, storage, dataset, notification, file, register, policy, secret, unit, workflow, wellbore, CRS, OETP |
| Service Helm modules | Alex 🛠️ | Creating service Terraform modules from reference-rosa/terraform/master-chart/services/* |
| Service dependency chains | Alex 🛠️ | Service ordering, depends_on, enable/disable flags |
| Architecture, cross-layer decisions | Holden 🏗️ | Layer boundaries, state management, deployment strategy, review gates |
| Code review, PR review | Holden 🏗️ | Terraform review, safeguards compliance review |
| Safeguards compliance testing | Drummer 🧪 | Terraform fmt/validate, PowerShell syntax, deployment verification |
| Deployment testing | Drummer 🧪 | Pre-provision checks, post-provision verification, smoke tests |
| PowerShell scripts | Drummer 🧪 | scripts/*.ps1 validation, $LASTEXITCODE checks |
