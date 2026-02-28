#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-down cleanup: remove Terraform working directories and stale artifacts.
.DESCRIPTION
    Runs after azd down to clean up .terraform/ directories (provider/module cache)
    and any remaining state backup files across all Terraform layers.
    These are reproducible artifacts that will be re-created by terraform init.
.EXAMPLE
    azd hooks run postdown
.EXAMPLE
    ./scripts/post-down.ps1
#>

#Requires -Version 7.4

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Post-Down: Cleaning Terraform Artifacts"                          -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$cleaned = $false

# Terraform layers to clean
$layers = @(
    @{ Path = "infra";                Label = "infra" },
    @{ Path = "software/foundation";  Label = "foundation" },
    @{ Path = "software/stack";       Label = "stack" }
)

# Add azd-managed infra state directory if env is known
$envName = $env:AZURE_ENV_NAME
if (-not [string]::IsNullOrEmpty($envName)) {
    $layers += @{ Path = ".azure/$envName/infra"; Label = ".azure/$envName/infra" }
}

foreach ($layer in $layers) {
    $dir = Join-Path $repoRoot $layer.Path
    if (-not (Test-Path $dir)) { continue }

    # Remove .terraform/ directory
    $tfDir = Join-Path $dir ".terraform"
    if (Test-Path $tfDir) {
        Remove-Item -Path $tfDir -Recurse -Force
        Write-Host "  Removed: $($layer.Label)/.terraform/" -ForegroundColor Gray
        $cleaned = $true
    }

    # Remove .terraform.lock.hcl
    $lockFile = Join-Path $dir ".terraform.lock.hcl"
    if (Test-Path $lockFile) {
        Remove-Item -Path $lockFile -Force
        Write-Host "  Removed: $($layer.Label)/.terraform.lock.hcl" -ForegroundColor Gray
        $cleaned = $true
    }

    # Remove stale .tfstate backup files (e.g., terraform.tfstate.1234567890.backup)
    $backups = Get-ChildItem -Path $dir -Filter "*.tfstate.*.backup" -ErrorAction SilentlyContinue
    foreach ($backup in $backups) {
        Remove-Item -Path $backup.FullName -Force
        Write-Host "  Removed: $($layer.Label)/$($backup.Name)" -ForegroundColor Gray
        $cleaned = $true
    }

    # Remove stale .tfstate files at root of layer (not in .tfstate/ subdirs)
    $stateFiles = Get-ChildItem -Path $dir -Filter "terraform.tfstate*" -ErrorAction SilentlyContinue
    foreach ($sf in $stateFiles) {
        Remove-Item -Path $sf.FullName -Force
        Write-Host "  Removed: $($layer.Label)/$($sf.Name)" -ForegroundColor Gray
        $cleaned = $true
    }
}

# Clean stack .tfstate/ subdirectory
$stackStateDir = Join-Path $repoRoot "software/stack/.tfstate"
if (Test-Path $stackStateDir) {
    Remove-Item -Path $stackStateDir -Recurse -Force
    Write-Host "  Removed: stack/.tfstate/" -ForegroundColor Gray
    $cleaned = $true
}

# Clean generated osdu-versions.auto.tfvars (created by prerestore hook)
$osduVersionsFile = Join-Path $repoRoot "software/stack/osdu-versions.auto.tfvars"
if (Test-Path $osduVersionsFile) {
    Remove-Item -Path $osduVersionsFile -Force
    Write-Host "  Removed: stack/osdu-versions.auto.tfvars" -ForegroundColor Gray
    $cleaned = $true
}

if (-not $cleaned) {
    Write-Host "  Already clean — no artifacts found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Post-Down Complete"                                               -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

exit 0
