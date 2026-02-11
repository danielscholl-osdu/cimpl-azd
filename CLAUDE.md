# CLAUDE.md — Project Intelligence for cimpl-azd

## Repository Overview

This repository deploys a complete platform stack on **Azure Kubernetes Service (AKS) Automatic** using Azure Developer CLI (azd) and Terraform. Three-layer architecture: infra (AKS cluster), platform (K8s workloads via Helm/Terraform), and future application layer.

- **Languages:** Terraform (HCL), PowerShell
- **Target:** AKS Automatic (strict deployment safeguards, always enforced)
- **Deployment:** `azd up` orchestrates everything via hooks

## Project Structure

```
infra/          → Layer 1: AKS cluster (Terraform, azd-managed state at .azure/<env>/infra/terraform.tfstate)
platform/       → Layer 2: Helm releases + K8s resources (Terraform, local state)
scripts/        → PowerShell deployment scripts (pre-provision, post-provision, deploy-platform, pre-down)
```

## Code Review Checklist

When reviewing PRs, check for these project-specific issues:

### PowerShell Scripts (`scripts/*.ps1`)

1. **Always check `$LASTEXITCODE` after external commands** (`az`, `terraform`, `kubectl`, `helm`). PowerShell does NOT throw on non-zero exit codes from external programs — failures are silently ignored without explicit checks.
   ```powershell
   # BAD — silent failure
   az network dns record-set a delete -g $rg -z $zone -n $name

   # GOOD — explicit error handling
   az network dns record-set a delete -g $rg -z $zone -n $name
   if ($LASTEXITCODE -ne 0) {
       Write-Host "  WARNING: Failed to delete $name" -ForegroundColor Yellow
   }
   ```

2. **Quote PowerShell variable interpolation in command arguments.** `-state=$var` does NOT interpolate; use `"-state=$var"`.
   ```powershell
   # BAD — $var not interpolated
   terraform output -raw -state=$infraStateFile AZURE_TENANT_ID

   # GOOD
   terraform output -raw "-state=$infraStateFile" AZURE_TENANT_ID
   ```

3. **Terraform CLI flag ordering:** Flags (like `-state=X`, `-raw`) must come before positional arguments.

4. **All scripts use `$ErrorActionPreference = "Stop"`** — match this pattern in new scripts.

5. **`2>$null` stderr suppression** — Verify it's intentional and not hiding real errors.

### Terraform — Infra Layer (`infra/*.tf`)

1. **Provider version constraints** are in `infra/versions.tf` (`~> 1.12` for Terraform). Don't downgrade.
2. **Sensitive outputs** must use `sensitive = true`.
3. **State is managed by azd** at `.azure/<env>/infra/terraform.tfstate`, NOT in the `infra/` source directory.

### Terraform — Platform Layer (`platform/*.tf`)

1. **Helm provider v3 syntax:** `set` blocks use list-of-objects format: `set = [{ name = "...", value = "..." }]`
2. **Count guards required:** All optional resources must use `count = var.enable_X ? 1 : 0`.
3. **AKS Automatic safeguards compliance (CRITICAL):**
   - All containers MUST have `readinessProbe` and `livenessProbe`
   - All containers MUST have resource `requests` and `limits`
   - NO `:latest` image tags
   - `seccompProfile: RuntimeDefault` required
   - Replicas > 1 need `topologySpreadConstraints` or `podAntiAffinity`
   - `NET_ADMIN`/`NET_RAW` capabilities are blocked (affects Istio sidecar injection)
4. **Helm boolean values:** When setting Kubernetes labels/annotations to `"true"` via Helm `set`, add `type = "string"` to prevent Helm from interpreting it as a boolean.
   ```hcl
   # BAD — Helm converts to boolean, K8s label becomes invalid
   { name = "podLabels.azure\\.workload\\.identity/use", value = "true" }

   # GOOD
   { name = "podLabels.azure\\.workload\\.identity/use", value = "true", type = "string" }
   ```
5. **Bitnami charts:** Free-tier Bitnami images require paid subscription since Aug 2025. Use official upstream images with `global.security.allowInsecureImages = true`.
6. **Istio sidecar injection:** Namespaces labeled `istio.io/rev: asm-1-28` get sidecar injection. ExternalDNS and other non-mesh workloads should NOT have this label (istio-init needs NET_ADMIN which AKS blocks).
7. **Workload Identity:** Use `useWorkloadIdentityExtension`, NOT `useManagedIdentityExtension` (IMDS-based, fails with multiple identities).

### Cross-Layer Concerns

1. **Two separate Terraform states** — infra outputs must be explicitly passed to platform via environment variables or terraform output commands.
2. **azd env variables** stored in `.azure/<env>/.env` — credential values use `sensitive = true`.
3. **DNS zone configuration** is optional — code must gracefully handle empty DNS variables (ExternalDNS disabled path).

## Validation Commands

```bash
# Terraform formatting (CI enforced)
terraform fmt -check -recursive ./infra
terraform fmt -check -recursive ./platform

# PowerShell syntax (CI enforced)
pwsh -Command '$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1"; foreach ($s in $scripts) { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $s.FullName -Raw), [ref]$null) }'
```
