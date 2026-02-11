---
applyTo: "platform/**/*.tf"
---
# Platform Terraform/Helm Guidance
- Ensure AKS safeguards compliance (resource requests/limits, probes, securityContext; avoid :latest tags).
- Avoid hard-coded credentials; use variables and update .env.example/README.
- Prefer managed Kubernetes resources over local-exec with remote downloads.
