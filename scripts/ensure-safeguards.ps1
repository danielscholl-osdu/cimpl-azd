#!/usr/bin/env pwsh
# Phase 1: Ensure AKS safeguards are ready
#
# This script runs after cluster provisioning and:
# 1. Configures kubeconfig
# 2. Configures AKS safeguards to Warning mode with namespace exclusions
# 3. Waits for Gatekeeper to fully reconcile
# 4. Exits with success only when safeguards are ready
#
# Platform deployment (Phase 2) should only run after this succeeds.

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 1: Ensuring Safeguards Readiness ===" -ForegroundColor Cyan

# Get resource group and cluster name from terraform outputs or environment
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$clusterName = $env:AZURE_AKS_CLUSTER_NAME

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "Getting values from terraform outputs..." -ForegroundColor Gray
    Push-Location $PSScriptRoot/../infra
    $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null
    $clusterName = terraform output -raw AZURE_AKS_CLUSTER_NAME 2>$null
    Pop-Location
}

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "Could not determine resource group or cluster name" -ForegroundColor Red
    exit 1
}

Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Cluster Name: $clusterName" -ForegroundColor Gray

# Step 1: Get kubeconfig
Write-Host "`n[1/3] Configuring kubeconfig..." -ForegroundColor Cyan
az aks get-credentials -g $resourceGroup -n $clusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get kubeconfig" -ForegroundColor Red
    exit 1
}
kubelogin convert-kubeconfig -l azurecli
Write-Host "  Kubeconfig configured" -ForegroundColor Green

# Step 2: Configure AKS safeguards
Write-Host "`n[2/3] Configuring AKS safeguards..." -ForegroundColor Cyan

# Aligned with docs/architecture.md
$excludedNs = "kube-system,gatekeeper-system,elastic-system,elastic-search,cert-manager,aks-istio-ingress,postgresql,minio"

$maxRetries = 3
$retryCount = 0
$safeguardsConfigured = $false

while (-not $safeguardsConfigured -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "  Attempt $retryCount of $maxRetries..." -ForegroundColor Gray

    $safeguardsResult = az aks update -g $resourceGroup -n $clusterName `
        --safeguards-level Warning `
        --safeguards-excluded-ns $excludedNs `
        --only-show-errors 2>&1

    if ($LASTEXITCODE -eq 0) {
        $safeguardsConfigured = $true
        Write-Host "  Safeguards: Warning mode" -ForegroundColor Green
        Write-Host "  Excluded: $excludedNs" -ForegroundColor Gray
    }
    else {
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Safeguards configuration failed, retrying in 30 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        }
    }
}

if (-not $safeguardsConfigured) {
    Write-Host "  ERROR: Safeguards configuration failed after $maxRetries attempts" -ForegroundColor Red
    Write-Host "  Platform deployment will likely fail" -ForegroundColor Red
    exit 1
}

# Step 3: Wait for Gatekeeper to reconcile (readiness gate)
Write-Host "`n[3/3] Waiting for Gatekeeper to reconcile..." -ForegroundColor Cyan

# Allow bypass via environment variable (for debugging or known-good clusters)
if ($env:SKIP_SAFEGUARDS_WAIT -eq "true") {
    Write-Host "  SKIP_SAFEGUARDS_WAIT=true - Bypassing Gatekeeper wait" -ForegroundColor Yellow
    Write-Host "`n=== Phase 1 Complete: Safeguards Ready (bypassed) ===" -ForegroundColor Green
    Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
    exit 0
}

# Check if Azure Policy add-on is enabled on the cluster
Write-Host "  Checking Azure Policy add-on status..." -ForegroundColor Gray
$clusterInfo = az aks show -g $resourceGroup -n $clusterName --query "addonProfiles.azurepolicy.enabled" -o tsv 2>$null

if ($clusterInfo -ne "true") {
    Write-Host "  Azure Policy add-on not enabled on cluster" -ForegroundColor Yellow
    Write-Host "  Skipping Gatekeeper readiness check" -ForegroundColor Yellow
    Write-Host "`n=== Phase 1 Complete: Safeguards Ready (no Azure Policy) ===" -ForegroundColor Green
    Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
    exit 0
}

Write-Host "  Azure Policy add-on: Enabled" -ForegroundColor Green

$maxWaitSeconds = 300  # 5 minutes max
$waitInterval = 15
$elapsedSeconds = 0

# Wait for gatekeeper-system namespace to exist (Azure Policy creates it asynchronously)
Write-Host "  Checking for Gatekeeper namespace..." -ForegroundColor Gray
$gatekeeperNsExists = $false
while (-not $gatekeeperNsExists -and $elapsedSeconds -lt $maxWaitSeconds) {
    $gatekeeperNs = kubectl get namespace gatekeeper-system --no-headers 2>$null
    if (-not [string]::IsNullOrEmpty($gatekeeperNs)) {
        $gatekeeperNsExists = $true
        Write-Host "  Gatekeeper namespace: Found" -ForegroundColor Green
    }
    else {
        Write-Host "  Waiting for gatekeeper-system namespace... ($elapsedSeconds`s)" -ForegroundColor Gray
        Start-Sleep -Seconds $waitInterval
        $elapsedSeconds += $waitInterval
    }
}

if (-not $gatekeeperNsExists) {
    Write-Host "  Warning: Gatekeeper namespace not found after ${maxWaitSeconds}s" -ForegroundColor Yellow
    Write-Host "  Continuing without Gatekeeper readiness check" -ForegroundColor Yellow
}
else {
    # Wait for Gatekeeper controller to be ready
    # Try both deployment names: gatekeeper-controller (AKS Automatic) and gatekeeper-controller-manager (standard)
    Write-Host "  Checking Gatekeeper controller status..." -ForegroundColor Gray
    $gatekeeperReady = $false

    while (-not $gatekeeperReady -and $elapsedSeconds -lt $maxWaitSeconds) {
        # Try gatekeeper-controller first (AKS Automatic)
        $rolloutStatus = kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller --timeout=10s 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gatekeeperReady = $true
            Write-Host "  Gatekeeper controller: Ready" -ForegroundColor Green
        }
        else {
            # Try gatekeeper-controller-manager (standard Azure Policy)
            $rolloutStatus = kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=10s 2>&1
            if ($LASTEXITCODE -eq 0) {
                $gatekeeperReady = $true
                Write-Host "  Gatekeeper controller-manager: Ready" -ForegroundColor Green
            }
            else {
                Write-Host "  Waiting for Gatekeeper controller... ($elapsedSeconds`s)" -ForegroundColor Gray
                Start-Sleep -Seconds $waitInterval
                $elapsedSeconds += $waitInterval
            }
        }
    }

    if (-not $gatekeeperReady) {
        Write-Host "  ERROR: Gatekeeper controller not ready after ${maxWaitSeconds}s" -ForegroundColor Red
        exit 1
    }
}

# Check Azure Policy constraints for enforcement action
# Only check constraints with names starting with "azurepolicy-" (Azure Policy managed)
# This avoids blocking on custom deny constraints that may be intentionally configured
Write-Host "  Checking Azure Policy constraint enforcement..." -ForegroundColor Gray
$constraintsReady = $false
$elapsedSeconds = 0

while (-not $constraintsReady -and $elapsedSeconds -lt $maxWaitSeconds) {
    $constraintsJson = kubectl get constraints -o json 2>$null

    if ([string]::IsNullOrEmpty($constraintsJson)) {
        Write-Host "  Waiting for constraints to be created... ($elapsedSeconds`s)" -ForegroundColor Gray
        Start-Sleep -Seconds $waitInterval
        $elapsedSeconds += $waitInterval
    }
    else {
        $constraints = $constraintsJson | ConvertFrom-Json
        $denyCount = 0
        $totalCount = 0

        foreach ($item in $constraints.items) {
            # Only check Azure Policy constraints (name starts with "azurepolicy-")
            if ($item.metadata.name -like "azurepolicy-*") {
                $totalCount++
                if ($item.spec.enforcementAction -eq "deny") {
                    $denyCount++
                }
            }
        }

        if ($totalCount -eq 0) {
            Write-Host "  Waiting for Azure Policy constraints... ($elapsedSeconds`s)" -ForegroundColor Gray
            Start-Sleep -Seconds $waitInterval
            $elapsedSeconds += $waitInterval
        }
        elseif ($denyCount -eq 0) {
            $constraintsReady = $true
            Write-Host "  All $totalCount Azure Policy constraints in warn/dryrun mode" -ForegroundColor Green
        }
        else {
            Write-Host "  $denyCount of $totalCount Azure Policy constraints still in deny mode, waiting... ($elapsedSeconds`s)" -ForegroundColor Gray
            Start-Sleep -Seconds $waitInterval
            $elapsedSeconds += $waitInterval
        }
    }
}

if (-not $constraintsReady) {
    Write-Host "  ERROR: Azure Policy constraints still in deny mode after ${maxWaitSeconds}s" -ForegroundColor Red
    Write-Host "  Platform deployment will likely fail" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Phase 1 Complete: Safeguards Ready ===" -ForegroundColor Green
Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
