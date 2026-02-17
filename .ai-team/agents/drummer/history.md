# Drummer — History

## Project Learnings (from import)
- Project converts OSDU platform from ROSA to AKS Automatic using azd + Terraform
- User: Daniel Scholl (daniel.scholl@microsoft.com)
- CI checks: terraform fmt, PowerShell syntax, secrets scan (.github/workflows/pr-checks.yml)
- AKS safeguards are non-negotiable on Automatic clusters
- Validation: terraform fmt -check -recursive, PSParser tokenization
- PowerShell scripts must check $LASTEXITCODE after external commands

## Learnings
