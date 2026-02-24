# Agent Instructions (cimpl-azd)

AKS Automatic platform deployed via Terraform (`infra/` + `platform/`) and PowerShell scripts (`scripts/`). Three-layer model: infra (cluster), platform (Helm/K8s workloads), services.

**Key references:**
- [`docs/src/architecture/overview.md`](docs/src/architecture/overview.md) — Component details, deployment flow, network/security architecture
- [`docs/src/decisions/`](docs/src/decisions/) — ADR index with rationale for all major design choices

---

## Critical Rules

**ALWAYS:**
- Check `$LASTEXITCODE` after every external command in PowerShell scripts (`az`, `terraform`, `kubectl`, `helm`)
- Use `count = var.enable_X ? 1 : 0` guards on all optional Terraform resources
- Add `readinessProbe`, `livenessProbe`, resource `requests`/`limits`, and `seccompProfile: RuntimeDefault` to every container
- Use `type = "string"` on Helm `set` blocks when the value is `"true"` or `"false"` (prevents Helm boolean coercion)
- Add differentiating labels when a namespace has multiple Services selecting the same pods ([ADR-0010](docs/src/decisions/0010-unique-service-selector-label-pattern.md))
- Quote PowerShell variable interpolation in command arguments: `"-state=$var"` not `-state=$var`
- Run `terraform fmt -check -recursive` before committing Terraform changes

**NEVER:**
- Run destructive commands (`terraform destroy`, `azd down`, `kubectl delete namespace`) unless explicitly requested
- Run real deployments (`azd up`, `terraform apply`, `kubectl apply`) unless explicitly requested
- Use `:latest` image tags — AKS Automatic blocks them
- Use `NET_ADMIN` or `NET_RAW` capabilities — AKS Automatic blocks them
- Use `useManagedIdentityExtension` for workload identity — use `useWorkloadIdentityExtension`
- Introduce secrets or default passwords in code — use env vars with `sensitive = true`
- Downgrade provider version constraints in `infra/versions.tf`

---

## Core Patterns

When **adding a new Helm chart**: use postrender + kustomize to inject missing probes/resources/seccomp. Follow `platform/kustomize/eck-operator-postrender.sh` as the reference pattern. See [ADR-0002](docs/src/decisions/0002-helm-postrender-kustomize-for-safeguards.md).

When **adding a new namespace with Istio**: only label with `istio-injection: enabled` if the workload does NOT need `NET_ADMIN`. See [ADR-0008](docs/src/decisions/0008-selective-istio-sidecar-injection.md).

When **passing values between infra/ and platform/**: use environment variables or `terraform output` in scripts. The two layers have separate state files. See [ADR-0006](docs/src/decisions/0006-two-layer-terraform-state.md).

When **replacing a Bitnami chart**: raw K8s manifests with official upstream images. See [ADR-0003](docs/src/decisions/0003-raw-manifests-for-rabbitmq.md) for the pattern.

---

## Quality Gates

```bash
# Terraform format (CI enforced)
terraform fmt -check -recursive ./infra
terraform fmt -check -recursive ./platform

# PowerShell syntax (CI enforced)
pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; foreach ($s in $scripts) { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$null) }'
```

---

## Architecture Decision Records

Create an ADR in [`docs/src/decisions/`](docs/src/decisions/) when:
- Adding new architectural patterns
- Choosing between design alternatives
- Making technology/library selections
- Changing core system behaviors

See [`docs/src/decisions/index.md`](docs/src/decisions/index.md) for templates and process.
