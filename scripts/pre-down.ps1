#!/usr/bin/env pwsh
# Pre-down cleanup script
# Deletes the resource group (which destroys everything) and clears terraform state.
#
# Why not let terraform destroy handle it?
# AKS node pool deletion can take 30+ minutes, exceeding terraform's per-resource
# timeout. By deleting the resource group directly via ARM and clearing terraform
# state, azd's terraform destroy sees an empty state and completes instantly.
#
# ARM handles resource group deletion reliably in the background.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Pre-Down: Resource Cleanup"                                       -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

#region Delete Resource Group
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [1/2] Deleting Resource Group"
Write-Host "=================================================================="

$resourceGroup = $env:AZURE_RESOURCE_GROUP

if ([string]::IsNullOrEmpty($resourceGroup)) {
    # Try to get from infra terraform outputs
    Push-Location $PSScriptRoot/../infra
    $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null
    Pop-Location
}

if ([string]::IsNullOrEmpty($resourceGroup)) {
    Write-Host "  No resource group found, skipping" -ForegroundColor Gray
}
else {
    # Check if the resource group still exists
    $rgExists = az group exists -n $resourceGroup 2>$null
    if ($rgExists -eq "true") {
        Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Gray
        Write-Host "  Deleting (ARM will handle cleanup in background)..." -ForegroundColor Gray
        az group delete -n $resourceGroup --no-wait -y 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Delete initiated" -ForegroundColor Green
        }
        else {
            Write-Host "  WARNING: Delete command failed, azd will retry via terraform" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Resource group '$resourceGroup' not found (already deleted)" -ForegroundColor Gray
    }
}
#endregion

#region Clear Terraform State
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [2/2] Clearing Terraform State"
Write-Host "=================================================================="

# Clear platform layer state
$platformDir = "$PSScriptRoot/../platform"
$cleared = $false

foreach ($file in @("terraform.tfstate", "terraform.tfstate.backup")) {
    $path = Join-Path $platformDir $file
    if (Test-Path $path) {
        Remove-Item -Path $path -Force
        Write-Host "  Removed: platform/$file" -ForegroundColor Gray
        $cleared = $true
    }
}

# Clear infra layer state (managed by azd at .azure/<env>/infra/)
$envName = $env:AZURE_ENV_NAME
if (-not [string]::IsNullOrEmpty($envName)) {
    $infraDir = "$PSScriptRoot/../.azure/$envName/infra"
    foreach ($file in @("terraform.tfstate", "terraform.tfstate.backup")) {
        $path = Join-Path $infraDir $file
        if (Test-Path $path) {
            Remove-Item -Path $path -Force
            Write-Host "  Removed: .azure/$envName/infra/$file" -ForegroundColor Gray
            $cleared = $true
        }
    }
}

if (-not $cleared) {
    Write-Host "  No state files found (already clean)" -ForegroundColor Gray
}
#endregion

#region Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Pre-Down Complete"                                                -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Resource group deleting in background via ARM" -ForegroundColor Gray
Write-Host "  Terraform state cleared for clean next deployment" -ForegroundColor Gray
Write-Host ""
exit 0
#endregion
