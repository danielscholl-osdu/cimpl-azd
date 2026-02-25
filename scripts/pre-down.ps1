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

#region Clean DNS Records
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [1/3] Cleaning DNS Records"
Write-Host "=================================================================="

$dnsZone = $env:TF_VAR_dns_zone_name
$dnsRg = $env:TF_VAR_dns_zone_resource_group
$dnsSub = $env:TF_VAR_dns_zone_subscription_id

if ([string]::IsNullOrEmpty($dnsZone) -or [string]::IsNullOrEmpty($dnsRg)) {
    Write-Host "  No DNS zone configured, skipping" -ForegroundColor Gray
}
else {
    Write-Host "  DNS Zone: $dnsZone ($dnsRg)" -ForegroundColor Gray

    # Determine the cluster name used as ExternalDNS owner ID
    $clusterName = $env:AZURE_AKS_CLUSTER_NAME
    if ([string]::IsNullOrEmpty($clusterName)) {
        # Try inferring from the environment name (matches platform naming convention)
        $envName = $env:AZURE_ENV_NAME
        if (-not [string]::IsNullOrEmpty($envName)) {
            $clusterName = "cimpl-$envName"
        }
    }

    if ([string]::IsNullOrEmpty($clusterName)) {
        Write-Host "  Could not determine cluster name, skipping DNS cleanup" -ForegroundColor Yellow
    }
    else {
        $subArgs = if (-not [string]::IsNullOrEmpty($dnsSub)) { @("--subscription", $dnsSub) } else { @() }
        $ownerPattern = "external-dns/owner=$([regex]::Escape($clusterName))(,|$)"

        # List TXT record sets and find those owned by this cluster
        $txtJson = az network dns record-set txt list -g $dnsRg -z $dnsZone @subArgs -o json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARNING: Failed to list DNS records in zone '$dnsZone'. Check permissions and zone existence." -ForegroundColor Yellow
            $txtRecords = @()
        }
        else {
            $txtRecords = if ($txtJson) { $txtJson | ConvertFrom-Json } else { @() }
        }

        $ownedNames = [System.Collections.ArrayList]::new()
        foreach ($rec in $txtRecords) {
            # Skip the SOA @ record
            if ($rec.name -eq "@") { continue }
            foreach ($entry in $rec.txtRecords) {
                $val = ($entry.value -join "")
                if ($val -match $ownerPattern) {
                    [void]$ownedNames.Add($rec.name)
                    break
                }
            }
        }

        if ($ownedNames.Count -eq 0) {
            Write-Host "  No DNS records owned by $clusterName" -ForegroundColor Gray
        }
        else {
            Write-Host "  Found $($ownedNames.Count) records owned by $clusterName" -ForegroundColor Gray

            foreach ($name in $ownedNames) {
                # Delete the A record if it exists
                $aExists = az network dns record-set a show -g $dnsRg -z $dnsZone -n $name @subArgs 2>$null
                if ($LASTEXITCODE -eq 0 -and $aExists) {
                    az network dns record-set a delete -g $dnsRg -z $dnsZone -n $name @subArgs -y 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  WARNING: Failed to delete A record $name.$dnsZone" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "  Removed: $name.$dnsZone (A)" -ForegroundColor Gray
                    }
                }

                # Delete the CNAME record if it exists
                $cnameExists = az network dns record-set cname show -g $dnsRg -z $dnsZone -n $name @subArgs 2>$null
                if ($LASTEXITCODE -eq 0 -and $cnameExists) {
                    az network dns record-set cname delete -g $dnsRg -z $dnsZone -n $name @subArgs -y 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  WARNING: Failed to delete CNAME record $name.$dnsZone" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "  Removed: $name.$dnsZone (CNAME)" -ForegroundColor Gray
                    }
                }

                # Delete the TXT record
                az network dns record-set txt delete -g $dnsRg -z $dnsZone -n $name @subArgs -y 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  WARNING: Failed to delete TXT record $name.$dnsZone" -ForegroundColor Yellow
                }
                else {
                    Write-Host "  Removed: $name.$dnsZone (TXT)" -ForegroundColor Gray
                }
            }
        }
    }
}
#endregion

#region Delete Resource Group
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [2/3] Deleting Resource Group"
Write-Host "=================================================================="

$resourceGroup = $env:AZURE_RESOURCE_GROUP

if ([string]::IsNullOrEmpty($resourceGroup)) {
    # Try to get from infra terraform outputs (prefer azd-managed state path)
    $envName = $env:AZURE_ENV_NAME
    $infraState = "$PSScriptRoot/../.azure/$envName/infra/terraform.tfstate"
    Push-Location $PSScriptRoot/../infra
    if (Test-Path $infraState) {
        $resourceGroup = terraform output -raw "-state=$infraState" AZURE_RESOURCE_GROUP 2>$null
    }
    else {
        $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null
    }
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
Write-Host "  [3/3] Clearing Terraform State"
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
