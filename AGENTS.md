# Agent Instructions (cimpl-azd)

This repo provisions AKS with Terraform (infra/), deploys platform components with Terraform/Helm (platform/), and uses PowerShell scripts (scripts/).

General rules:
- Prefer ripgrep (rg) for search.
- Do NOT run real deployments (azd up, terraform apply, az aks, kubectl apply) unless explicitly requested.
- Safe checks: terraform fmt -check -recursive; terraform validate only after terraform init and only if providers are already available.
- Avoid introducing secrets or default passwords; use env vars and update .env.example/README when adding new configuration.
- For safeguards changes, keep the behavioral dry-run gate and 20-minute default timeout unless asked.

If you change behavior or workflow, update notes.md and docs/architecture.md.
