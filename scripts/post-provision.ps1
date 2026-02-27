#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-provision: ensure AKS safeguards are ready.
.DESCRIPTION
    Runs after cluster provisioning (azd provision) to configure safeguards,
    wait for Gatekeeper readiness, and verify namespace exclusions before
    any software deployment (azd deploy).
.EXAMPLE
    azd hooks run postprovision
.EXAMPLE
    ./scripts/post-provision.ps1
#>

#Requires -Version 7.4

$ErrorActionPreference = "Stop"

#region Utility Functions

function Get-ClusterContext {
    $resourceGroup = $env:AZURE_RESOURCE_GROUP
    $clusterName = $env:AZURE_AKS_CLUSTER_NAME
    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID

    if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
        Write-Host "  Getting values from terraform outputs..." -ForegroundColor Gray
        Push-Location $PSScriptRoot/../infra
        if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null }
        if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = terraform output -raw AZURE_AKS_CLUSTER_NAME 2>$null }
        if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = terraform output -raw AZURE_SUBSCRIPTION_ID 2>$null }
        Pop-Location
    }

    if ([string]::IsNullOrEmpty($subscriptionId)) {
        Write-Host "  Subscription ID not provided; falling back to current az account..." -ForegroundColor Gray
        $subscriptionId = az account show --query id -o tsv 2>$null
    }

    if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
        Write-Host "  Could not determine resource group or cluster name" -ForegroundColor Red
        exit 1
    }

    return @{
        ResourceGroup  = $resourceGroup
        ClusterName    = $clusterName
        SubscriptionId = $subscriptionId
        SubArgs        = if (-not [string]::IsNullOrEmpty($subscriptionId)) { @("--subscription", $subscriptionId) } else { @() }
    }
}

function Connect-Cluster {
    param($Ctx)

    Write-Host "`n[1/4] Configuring kubeconfig..." -ForegroundColor Cyan

    az aks get-credentials -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) --overwrite-existing
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed to get kubeconfig" -ForegroundColor Red
        exit 1
    }
    kubelogin convert-kubeconfig -l azurecli
    Write-Host "  Kubeconfig configured" -ForegroundColor Green

    # Verify RBAC permissions (can take minutes to propagate on fresh clusters)
    Write-Host "`n[1.5/4] Verifying RBAC permissions..." -ForegroundColor Cyan
    $maxWait = 300  # 5 minutes
    $interval = 15
    $elapsed = 0

    while ($elapsed -lt $maxWait) {
        $canCreate = kubectl auth can-i create namespaces 2>&1
        if ($canCreate -eq "yes") {
            Write-Host "  RBAC permissions: OK" -ForegroundColor Green
            return
        }
        # Detect authentication errors that won't resolve with time
        $output = "$canCreate"
        if ($output -match "\bAADSTS\b|\bauthentication failed\b|\bunauthorized\b|\blogin\s+failed\b|token expired|invalid token|token not found|credential expired|invalid credential|credentials? not found") {
            Write-Host "  ERROR: Authentication failed (not an RBAC propagation issue)" -ForegroundColor Red
            Write-Host "  Detail: $($output.Substring(0, [Math]::Min(200, $output.Length)))" -ForegroundColor Gray
            Write-Host "  Please re-authenticate:" -ForegroundColor Yellow
            Write-Host "    az logout" -ForegroundColor Gray
            Write-Host "    az login" -ForegroundColor Gray
            exit 1
        }
        Write-Host "  Waiting for RBAC propagation... ($elapsed`s)" -ForegroundColor Gray
        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }

    # Final check after timeout
    $canCreate = kubectl auth can-i create namespaces 2>&1
    if ($canCreate -ne "yes") {
        Write-Host "  ERROR: RBAC permissions not available after ${maxWait}s" -ForegroundColor Red
        Write-Host "  User cannot create namespaces. Check role assignments." -ForegroundColor Red
        exit 1
    }
    Write-Host "  RBAC permissions: OK (detected on final check)" -ForegroundColor Green
}

function Set-Safeguards {
    param($Ctx)

    Write-Host "`n[2/4] Checking cluster configuration..." -ForegroundColor Cyan

    $clusterSkuOutput = az aks show -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) --query "sku.name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to determine AKS cluster SKU via 'az aks show'." -ForegroundColor Red
        Write-Host "  Ensure you are logged in, have access to the subscription, and the cluster exists." -ForegroundColor Red
        exit 1
    }

    $clusterSku = if ($clusterSkuOutput) { $clusterSkuOutput.Trim() } else { "" }
    if ([string]::IsNullOrEmpty($clusterSku)) {
        Write-Host "  ERROR: AKS cluster SKU was not returned by 'az aks show'." -ForegroundColor Red
        exit 1
    }

    $script:isAutomatic = ($clusterSku -eq "Automatic")

    if ($script:isAutomatic) {
        Write-Host "  Cluster type: AKS Automatic" -ForegroundColor Cyan
        Write-Host "  Safeguards: Enforced (cannot be modified)" -ForegroundColor Yellow
        Write-Host "  Workloads must be compliant with Deployment Safeguards" -ForegroundColor Yellow
        return
    }

    Write-Host "  Cluster type: Standard AKS" -ForegroundColor Cyan
    Write-Host "  Configuring AKS safeguards..." -ForegroundColor Cyan

    $excludedNsList = @(
        "kube-system", "gatekeeper-system", "platform",
        "elasticsearch", "aks-istio-ingress", "postgresql", "redis"
    )

    $maxRetries = 3
    $retryCount = 0
    $configured = $false

    while (-not $configured -and $retryCount -lt $maxRetries) {
        $retryCount++
        Write-Host "  Attempt $retryCount of $maxRetries..." -ForegroundColor Gray

        Write-Host "  Trying az aks safeguards update..." -ForegroundColor Gray
        $null = az aks safeguards update -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) `
            --level Warn --excluded-ns @excludedNsList --only-show-errors 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Fallback: trying az aks update --safeguards-level..." -ForegroundColor Gray
            $excludedNsComma = $excludedNsList -join ","
            $null = az aks update -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) `
                --safeguards-level Warning --safeguards-excluded-ns $excludedNsComma --only-show-errors 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            $configured = $true
            Write-Host "  Safeguards: Warning mode" -ForegroundColor Green
            Write-Host "  Excluded: $($excludedNsList -join ', ')" -ForegroundColor Gray
        }
        elseif ($retryCount -lt $maxRetries) {
            Write-Host "  Safeguards configuration failed, retrying in 30 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        }
    }

    if (-not $configured) {
        Write-Host "  ERROR: Safeguards configuration failed after $maxRetries attempts" -ForegroundColor Red
        exit 1
    }
}

function Wait-ForGatekeeper {
    param($Ctx)

    Write-Host "`n[3/4] Waiting for Gatekeeper controller..." -ForegroundColor Cyan

    if ($env:SKIP_SAFEGUARDS_WAIT -eq "true") {
        Write-Host "  SKIP_SAFEGUARDS_WAIT=true — Bypassing all safeguards checks" -ForegroundColor Yellow
        return
    }

    # Check if Azure Policy add-on is enabled
    Write-Host "  Checking Azure Policy add-on status..." -ForegroundColor Gray
    $policyEnabled = az aks show -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) --query "addonProfiles.azurepolicy.enabled" -o tsv 2>$null

    if ($policyEnabled -ne "true") {
        Write-Host "  Azure Policy add-on not enabled — skipping Gatekeeper check" -ForegroundColor Yellow
        return
    }
    Write-Host "  Azure Policy add-on: Enabled" -ForegroundColor Green

    $maxWait = if ($env:SAFEGUARDS_WAIT_TIMEOUT) { [int]$env:SAFEGUARDS_WAIT_TIMEOUT } else { 1200 }
    $interval = 15

    # Wait for gatekeeper-system namespace
    Write-Host "  Checking for Gatekeeper namespace..." -ForegroundColor Gray
    $elapsed = 0
    $nsFound = $false
    while (-not $nsFound -and $elapsed -lt $maxWait) {
        $ns = kubectl get namespace gatekeeper-system --no-headers 2>$null
        if (-not [string]::IsNullOrEmpty($ns)) {
            $nsFound = $true
            Write-Host "  Gatekeeper namespace: Found" -ForegroundColor Green
        }
        else {
            Write-Host "  Waiting for gatekeeper-system namespace... ($elapsed`s)" -ForegroundColor Gray
            Start-Sleep -Seconds $interval
            $elapsed += $interval
        }
    }

    if (-not $nsFound) {
        Write-Host "  ERROR: Gatekeeper namespace not found after ${maxWait}s" -ForegroundColor Red
        Write-Host "  Bypass: SKIP_SAFEGUARDS_WAIT=true azd hooks run postprovision" -ForegroundColor Yellow
        exit 1
    }

    # Wait for Gatekeeper controller deployment
    Write-Host "  Checking Gatekeeper controller status..." -ForegroundColor Gray
    $elapsed = 0
    $ready = $false
    while (-not $ready -and $elapsed -lt $maxWait) {
        # Try gatekeeper-controller (AKS Automatic), then gatekeeper-controller-manager (standard)
        $null = kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller --timeout=10s 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ready = $true
            Write-Host "  Gatekeeper controller: Ready" -ForegroundColor Green
        }
        else {
            $null = kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=10s 2>&1
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                Write-Host "  Gatekeeper controller-manager: Ready" -ForegroundColor Green
            }
            else {
                Write-Host "  Waiting for Gatekeeper controller... ($elapsed`s)" -ForegroundColor Gray
                Start-Sleep -Seconds $interval
                $elapsed += $interval
            }
        }
    }

    if (-not $ready) {
        Write-Host "  ERROR: Gatekeeper controller not ready after ${maxWait}s" -ForegroundColor Red
        exit 1
    }
}

function Test-Exclusions {
    param($Ctx)

    Write-Host "`n[4/4] Final verification..." -ForegroundColor Cyan

    if ($env:SKIP_SAFEGUARDS_WAIT -eq "true") {
        Write-Host "  Bypassed" -ForegroundColor Yellow
        return
    }

    if ($script:isAutomatic) {
        Test-ProbeExemption
    }
    else {
        Test-NamespaceExclusions
    }
}

function Test-ProbeExemption {
    Write-Host "  AKS Automatic — verifying probe exemption propagation..." -ForegroundColor Cyan
    Write-Host "  Namespaces will be created by Terraform during deploy" -ForegroundColor Gray

    $maxWaitDefault = 1200
    $maxWait = $maxWaitDefault
    if ($env:SAFEGUARDS_WAIT_TIMEOUT) {
        if (-not [int]::TryParse($env:SAFEGUARDS_WAIT_TIMEOUT, [ref]$maxWait)) {
            Write-Host "  WARNING: SAFEGUARDS_WAIT_TIMEOUT '$($env:SAFEGUARDS_WAIT_TIMEOUT)' is not a valid integer; using default ${maxWaitDefault}s." -ForegroundColor Yellow
            $maxWait = $maxWaitDefault
        }
    }
    $interval = 30
    $elapsed = 0

    # Job that is fully safeguards-compliant EXCEPT for probes.
    # If the probe exemption has propagated, this dry-run succeeds.
    $testJobYaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: probe-exemption-test
  namespace: default
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: probe-exemption-test
      containers:
      - name: test
        image: mcr.microsoft.com/cbl-mariner/base/core:2.0
        command: ["true"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 64Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
      restartPolicy: Never
"@

    while ($elapsed -lt $maxWait) {
        $result = $testJobYaml | kubectl create --dry-run=server -f - 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Probe exemption: Propagated" -ForegroundColor Green
            return
        }
        $output = "$result"
        if ($output -match "livenessProbe|readinessProbe|Probe|probe") {
            Write-Host "  Waiting for probe exemption propagation... ($elapsed`s / $maxWait`s)" -ForegroundColor Gray
            Start-Sleep -Seconds $interval
            $elapsed += $interval
        }
        else {
            Write-Host "  ERROR: kubectl dry-run failed (not probe-related):" -ForegroundColor Red
            Write-Host "  $output" -ForegroundColor DarkGray
            exit 1
        }
    }

    Write-Host "  WARNING: Probe exemption not detected after $maxWait`s" -ForegroundColor Yellow
    Write-Host "  CNPG initdb Job may be blocked by deployment safeguards." -ForegroundColor Yellow
    Write-Host "  Bypass: SKIP_SAFEGUARDS_WAIT=true azd hooks run postprovision" -ForegroundColor Gray
    exit 1
}

function Test-NamespaceExclusions {
    $targetNamespaces = @("platform", "elasticsearch", "postgresql", "redis")

    foreach ($ns in $targetNamespaces) {
        $nsExists = kubectl get namespace $ns --no-headers 2>$null
        if ([string]::IsNullOrEmpty($nsExists)) {
            Write-Host "  Creating namespace: $ns" -ForegroundColor Gray
            $nsResult = kubectl create namespace $ns 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: Failed to create namespace $ns" -ForegroundColor Red
                Write-Host "        $nsResult" -ForegroundColor Gray
                exit 1
            }
        }
    }

    Write-Host "  Verifying namespace exclusions via dry-run..." -ForegroundColor Gray

    # Deployment that triggers multiple policies (no probes, no securityContext, latest tag)
    $testDeploymentYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: safeguards-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: safeguards-test
  template:
    metadata:
      labels:
        app: safeguards-test
    spec:
      containers:
      - name: test
        image: nginx:latest
"@

    $allOk = $true
    $failedNs = @()

    foreach ($ns in $targetNamespaces) {
        $result = $testDeploymentYaml | kubectl apply --dry-run=server -n $ns -f - 2>&1
        $exitCode = $LASTEXITCODE
        $isPolicyError = ($result -match "denied|violation|constraint")

        # Retry once for transient (non-policy) errors
        if ($exitCode -ne 0 -and -not $isPolicyError) {
            Write-Host "  RETRY: $ns — transient error, retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $result = $testDeploymentYaml | kubectl apply --dry-run=server -n $ns -f - 2>&1
            $exitCode = $LASTEXITCODE
            $isPolicyError = ($result -match "denied|violation|constraint")
        }

        if ($exitCode -ne 0) {
            $allOk = $false
            $failedNs += $ns
            $label = if ($isPolicyError) { "policy violation" } else { "dry-run error" }
            Write-Host "  FAIL: $ns — $label" -ForegroundColor Red
            Write-Host "        $(($result -split "`n")[0])" -ForegroundColor Gray
        }
        else {
            Write-Host "  OK: $ns — exclusions working" -ForegroundColor Green
        }
    }

    if (-not $allOk) {
        Write-Host "`n  ERROR: Namespace exclusions not effective for: $($failedNs -join ', ')" -ForegroundColor Red
        Write-Host "  Possible causes:" -ForegroundColor Yellow
        Write-Host "    - Another Azure Policy assignment at subscription/management group level" -ForegroundColor Yellow
        Write-Host "    - Azure Policy addon has not reconciled yet (try again in 2-3 min)" -ForegroundColor Yellow
        Write-Host "  Debug:" -ForegroundColor Yellow
        Write-Host "    kubectl get constraints -o json | jq '.items[].spec.match.excludedNamespaces'" -ForegroundColor Yellow
        Write-Host "  Bypass:" -ForegroundColor Yellow
        Write-Host "    SKIP_SAFEGUARDS_WAIT=true azd hooks run postprovision" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  All namespace exclusions verified" -ForegroundColor Green
}

#endregion

# --- Main Flow ---

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Post-Provision: Ensure Safeguards Readiness"                      -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$ctx = Get-ClusterContext
Write-Host "  Resource Group: $($ctx.ResourceGroup)" -ForegroundColor Gray
Write-Host "  Cluster Name: $($ctx.ClusterName)" -ForegroundColor Gray
if (-not [string]::IsNullOrEmpty($ctx.SubscriptionId)) {
    Write-Host "  Subscription: $($ctx.SubscriptionId)" -ForegroundColor Gray
}

Connect-Cluster -Ctx $ctx
Set-Safeguards -Ctx $ctx
Wait-ForGatekeeper -Ctx $ctx
Test-Exclusions -Ctx $ctx

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Post-Provision Complete — safeguards ready"                       -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next step: azd deploy" -ForegroundColor Gray
Write-Host ""
exit 0
