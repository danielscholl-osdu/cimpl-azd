---
applyTo: "scripts/**/*.ps1"
---
# PowerShell Script Guidance
- Keep scripts idempotent and safe; check $LASTEXITCODE and exit non-zero on failures.
- Avoid destructive actions unless explicitly requested.
- Use Write-Host for step output and keep messages actionable.
