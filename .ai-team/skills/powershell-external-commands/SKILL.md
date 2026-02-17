---
name: "powershell-external-commands"
description: "PowerShell error handling for external commands (az, terraform, kubectl)"
domain: "scripting"
confidence: "high"
source: "earned"
---

## Context
PowerShell does NOT throw on non-zero exit codes from external programs. Failures are silently ignored without explicit checks. All scripts in this project use `$ErrorActionPreference = "Stop"`.

## Patterns

### Always check $LASTEXITCODE
```powershell
terraform apply -auto-approve
if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform apply failed"
    exit 1
}
```

### Variable interpolation in command arguments
```powershell
# BAD — $var not interpolated
terraform output -raw -state=$infraStateFile AZURE_TENANT_ID

# GOOD — quoted string
terraform output -raw "-state=$infraStateFile" AZURE_TENANT_ID
```

### Terraform CLI flag ordering
Flags (-state=X, -raw) must come BEFORE positional arguments.

### Stderr suppression
Use `2>$null` only intentionally — verify it's not hiding real errors.

## Anti-Patterns
- Assuming external command failures will throw exceptions
- Using `-state=$var` without quotes (variable not interpolated)
- Putting positional args before flags in terraform commands
- Missing $LASTEXITCODE checks after az, terraform, kubectl, helm
