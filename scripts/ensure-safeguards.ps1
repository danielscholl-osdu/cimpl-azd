#!/usr/bin/env pwsh
# Phase 1: Ensure AKS safeguards are ready
#
# This script runs after cluster provisioning and:
# 1. Configures kubeconfig
# 2. Configures AKS safeguards to Warning mode with namespace exclusions
# 3. Waits for Gatekeeper controller to be ready
# 4. Verifies exclusions via server-side dry-run (behavioral gate)
#
# Platform deployment (Phase 2) should only run after this succeeds.
#
# The dry-run approach tests actual admission behavior rather than checking
# constraint enforcement modes, which may not reflect namespace exclusions.

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 1: Ensuring Safeguards Readiness ===" -ForegroundColor Cyan

# Get resource group, cluster name, and subscription from environment or terraform outputs
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$clusterName = $env:AZURE_AKS_CLUSTER_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "Getting values from terraform outputs..." -ForegroundColor Gray
    Push-Location $PSScriptRoot/../infra
    if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null }
    if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = terraform output -raw AZURE_AKS_CLUSTER_NAME 2>$null }
    if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = terraform output -raw AZURE_SUBSCRIPTION_ID 2>$null }
    Pop-Location
}

if ([string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "Subscription ID not provided; falling back to current az account..." -ForegroundColor Gray
    $subscriptionId = az account show --query id -o tsv 2>$null
}

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "Could not determine resource group or cluster name" -ForegroundColor Red
    exit 1
}

Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Cluster Name: $clusterName" -ForegroundColor Gray
if (-not [string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
}

# Build common subscription argument for az commands
$subscriptionArgs = if (-not [string]::IsNullOrEmpty($subscriptionId)) { @("--subscription", $subscriptionId) } else { @() }

# Step 1: Get kubeconfig
Write-Host "`n[1/4] Configuring kubeconfig..." -ForegroundColor Cyan
az aks get-credentials -g $resourceGroup -n $clusterName @subscriptionArgs --overwrite-existing
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get kubeconfig" -ForegroundColor Red
    exit 1
}
kubelogin convert-kubeconfig -l azurecli
Write-Host "  Kubeconfig configured" -ForegroundColor Green

# Step 1.5: Verify RBAC permissions (can take minutes to propagate on fresh clusters)
Write-Host "`n[1.5/4] Verifying RBAC permissions..." -ForegroundColor Cyan
$rbacMaxWait = 300  # 5 minutes
$rbacWaitInterval = 15
$rbacElapsed = 0

while ($rbacElapsed -lt $rbacMaxWait) {
    $canCreate = kubectl auth can-i create namespaces 2>&1
    if ($canCreate -eq "yes") {
        Write-Host "  RBAC permissions: OK" -ForegroundColor Green
        break
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
    Write-Host "  Waiting for RBAC propagation... ($rbacElapsed`s)" -ForegroundColor Gray
    Start-Sleep -Seconds $rbacWaitInterval
    $rbacElapsed += $rbacWaitInterval
}

if ($rbacElapsed -ge $rbacMaxWait) {
    # Final check to catch permissions that propagated during the last sleep interval
    $canCreate = kubectl auth can-i create namespaces 2>&1
    if ($canCreate -ne "yes") {
        Write-Host "  ERROR: RBAC permissions not available after ${rbacMaxWait}s" -ForegroundColor Red
        Write-Host "  User cannot create namespaces. Check role assignments." -ForegroundColor Red
        exit 1
    }
    Write-Host "  RBAC permissions: OK (detected on final check)" -ForegroundColor Green
}

# Step 2: Check cluster type and configure safeguards (if supported)
Write-Host "`n[2/4] Checking cluster configuration..." -ForegroundColor Cyan

# Detect AKS Automatic (safeguards cannot be modified)
# Note: Using 2>$null to discard stderr (aks-preview warnings) since we only need the SKU value
$clusterSkuOutput = az aks show -g $resourceGroup -n $clusterName @subscriptionArgs --query "sku.name" -o tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to determine AKS cluster SKU via 'az aks show'." -ForegroundColor Red
    Write-Host "  Ensure you are logged in (az login), have access to the subscription, and the cluster exists." -ForegroundColor Red
    exit 1
}

$clusterSku = if ($clusterSkuOutput) { $clusterSkuOutput.Trim() } else { "" }
if ([string]::IsNullOrEmpty($clusterSku)) {
    Write-Host "  ERROR: AKS cluster SKU was not returned by 'az aks show'." -ForegroundColor Red
    Write-Host "  Command succeeded but did not return a SKU name. Investigate cluster configuration and Azure CLI." -ForegroundColor Red
    exit 1
}

$isAutomatic = ($clusterSku -eq "Automatic")

if ($isAutomatic) {
    Write-Host "  Cluster type: AKS Automatic" -ForegroundColor Cyan
    Write-Host "  Safeguards: Enforced (cannot be modified)" -ForegroundColor Yellow
    Write-Host "  Workloads must be compliant with Deployment Safeguards" -ForegroundColor Yellow
    $safeguardsConfigured = $true
}
else {
    Write-Host "  Cluster type: Standard AKS" -ForegroundColor Cyan
    Write-Host "  Configuring AKS safeguards..." -ForegroundColor Cyan

    # Aligned with docs/architecture.md
    # Pass as array - Azure CLI expects multiple values for az aks safeguards update
    $excludedNsList = @(
        "kube-system",
        "gatekeeper-system",
        "platform",
        "elasticsearch",
        "aks-istio-ingress",
        "postgresql",
        "redis"
    )

    $maxRetries = 3
    $retryCount = 0
    $safeguardsConfigured = $false

    while (-not $safeguardsConfigured -and $retryCount -lt $maxRetries) {
        $retryCount++
        Write-Host "  Attempt $retryCount of $maxRetries..." -ForegroundColor Gray

        # Try new command first (az aks safeguards update), fallback to old for CLI compatibility
        Write-Host "  Trying az aks safeguards update..." -ForegroundColor Gray
        $safeguardsResult = az aks safeguards update -g $resourceGroup -n $clusterName @subscriptionArgs `
            --level Warn `
            --excluded-ns @excludedNsList `
            --only-show-errors 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Fallback: trying az aks update --safeguards-level..." -ForegroundColor Gray
            $excludedNsComma = $excludedNsList -join ","
            $safeguardsResult = az aks update -g $resourceGroup -n $clusterName @subscriptionArgs `
                --safeguards-level Warning `
                --safeguards-excluded-ns $excludedNsComma `
                --only-show-errors 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            $safeguardsConfigured = $true
            Write-Host "  Safeguards: Warning mode" -ForegroundColor Green
            Write-Host "  Excluded: $($excludedNsList -join ', ')" -ForegroundColor Gray
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
}

# Step 3: Wait for Gatekeeper (exclusion verification happens in Step 4 for Standard AKS only)
Write-Host "`n[3/4] Waiting for Gatekeeper controller..." -ForegroundColor Cyan

# Allow bypass via environment variable (for debugging or known-good clusters)
if ($env:SKIP_SAFEGUARDS_WAIT -eq "true") {
    Write-Host "  SKIP_SAFEGUARDS_WAIT=true - Bypassing all safeguards checks" -ForegroundColor Yellow
    Write-Host "`n=== Phase 1 Complete: Safeguards Ready (bypassed) ===" -ForegroundColor Green
    Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
    exit 0
}

# Check if Azure Policy add-on is enabled on the cluster
Write-Host "  Checking Azure Policy add-on status..." -ForegroundColor Gray
$clusterInfo = az aks show -g $resourceGroup -n $clusterName @subscriptionArgs --query "addonProfiles.azurepolicy.enabled" -o tsv 2>$null

if ($clusterInfo -ne "true") {
    Write-Host "  Azure Policy add-on not enabled on cluster" -ForegroundColor Yellow
    Write-Host "  Skipping Gatekeeper readiness check" -ForegroundColor Yellow
    Write-Host "`n=== Phase 1 Complete: Safeguards Ready (no Azure Policy) ===" -ForegroundColor Green
    Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
    exit 0
}

Write-Host "  Azure Policy add-on: Enabled" -ForegroundColor Green

# Azure Policy sync can take up to 20 minutes per docs
$maxWaitSeconds = if ($env:SAFEGUARDS_WAIT_TIMEOUT) { [int]$env:SAFEGUARDS_WAIT_TIMEOUT } else { 1200 }  # 20 min default
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
    Write-Host "  ERROR: Gatekeeper namespace not found after ${maxWaitSeconds}s" -ForegroundColor Red
    Write-Host "  Azure Policy add-on is enabled but Gatekeeper not running" -ForegroundColor Red
    Write-Host "  Bypass: SKIP_SAFEGUARDS_WAIT=true ./scripts/ensure-safeguards.ps1" -ForegroundColor Yellow
    exit 1
}
else {
    # Reset timer for controller wait (namespace wait already consumed some time)
    $elapsedSeconds = 0

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

# Step 4: Verify exclusions (for standard AKS) or skip for AKS Automatic
Write-Host "`n[4/4] Final verification..." -ForegroundColor Cyan

if ($isAutomatic) {
    # AKS Automatic: Workloads must comply with Deployment Safeguards.
    # The CNPG probe exemption (Azure Policy waiver) can take up to 20 min to
    # propagate from Azure Policy to the in-cluster Gatekeeper constraint.
    # Verify propagation by dry-running a Job without probes before proceeding.
    Write-Host "  AKS Automatic detected - verifying probe exemption propagation..." -ForegroundColor Cyan
    Write-Host "  Namespaces will be created by Terraform in Phase 2" -ForegroundColor Gray

    $exemptionMaxWaitDefault = 1200  # 20 min
    $exemptionMaxWait = $exemptionMaxWaitDefault
    if ($env:SAFEGUARDS_WAIT_TIMEOUT) {
        if (-not [int]::TryParse($env:SAFEGUARDS_WAIT_TIMEOUT, [ref]$exemptionMaxWait)) {
            Write-Host "  WARNING: SAFEGUARDS_WAIT_TIMEOUT '$($env:SAFEGUARDS_WAIT_TIMEOUT)' is not a valid integer; using default ${exemptionMaxWaitDefault}s." -ForegroundColor Yellow
            $exemptionMaxWait = $exemptionMaxWaitDefault
        }
    }
    $exemptionInterval = 30
    $exemptionElapsed = 0
    $exemptionReady = $false

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

    while (-not $exemptionReady -and $exemptionElapsed -lt $exemptionMaxWait) {
        $result = $testJobYaml | kubectl create --dry-run=server -f - 2>&1
        if ($LASTEXITCODE -eq 0) {
            $exemptionReady = $true
            Write-Host "  Probe exemption: Propagated" -ForegroundColor Green
        }
        else {
            $output = "$result"
            if ($output -match "livenessProbe|readinessProbe|Probe|probe") {
                Write-Host "  Waiting for probe exemption propagation... ($exemptionElapsed`s / $($exemptionMaxWait)s)" -ForegroundColor Gray
                Start-Sleep -Seconds $exemptionInterval
                $exemptionElapsed += $exemptionInterval
            }
            else {
                # Non-probe error: fail fast so the user can diagnose connectivity/RBAC/schema issues
                Write-Host "  ERROR: kubectl dry-run failed (not probe-related):" -ForegroundColor Red
                Write-Host "  $output" -ForegroundColor DarkGray
                Write-Host "  Resolve the issue above and re-run this script." -ForegroundColor Yellow
                exit 1
            }
        }
    }

    if (-not $exemptionReady) {
        Write-Host "  WARNING: Probe exemption not detected after $($exemptionMaxWait)s" -ForegroundColor Yellow
        Write-Host "  CNPG initdb Job may be blocked by deployment safeguards." -ForegroundColor Yellow
        Write-Host "  You can retry later: ./scripts/deploy-platform.ps1" -ForegroundColor Gray
        Write-Host "  Or bypass: SKIP_SAFEGUARDS_WAIT=true ./scripts/ensure-safeguards.ps1" -ForegroundColor Gray
        exit 1
    }
}
else {
    # Standard AKS: Verify exclusions are effective via server-side dry-run
    # Instead of checking constraint enforcement modes (which may not reflect exclusions),
    # we test actual admission behavior by dry-running a non-compliant workload

    # For Standard AKS, we need to create namespaces for the dry-run test
    # These will be managed by Terraform later, but we need them for testing exclusions
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

    # Deployment that triggers multiple policies:
    # - K8sAzureV2ContainerEnforceProbes (no readiness/liveness probes)
    # - K8sAzureV2ContainerNoPrivilege (missing securityContext)
    # - K8sAzureV2BlockDefault (uses default namespace - but we test in excluded ns)
    # - K8sAzureV2ContainerRestrictedImagePulls (uses nginx:latest)
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

    # Helper function to test dry-run and return structured result
    function Test-DryRun {
        param([string]$Namespace, [string]$Yaml)

        $result = $Yaml | kubectl apply --dry-run=server -n $Namespace -f - 2>&1
        $exitCode = $LASTEXITCODE
        return @{
            Success = ($exitCode -eq 0)
            Output = $result
            IsPolicyError = ($result -match "denied|violation|constraint")
        }
    }

    $allExclusionsWork = $true
    $failedNamespaces = @()

    foreach ($ns in $targetNamespaces) {
        $dryRun = Test-DryRun -Namespace $ns -Yaml $testDeploymentYaml

        if (-not $dryRun.Success) {
            # Retry once for transient errors (not policy violations)
            if (-not $dryRun.IsPolicyError) {
                Write-Host "  RETRY: $ns - transient error, retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                $dryRun = Test-DryRun -Namespace $ns -Yaml $testDeploymentYaml
            }
        }

        if (-not $dryRun.Success) {
            $allExclusionsWork = $false
            $failedNamespaces += $ns

            if ($dryRun.IsPolicyError) {
                Write-Host "  FAIL: $ns - policy violation" -ForegroundColor Red
            }
            else {
                Write-Host "  FAIL: $ns - dry-run error (RBAC/network/other)" -ForegroundColor Red
            }
            $firstLine = ($dryRun.Output -split "`n")[0]
            Write-Host "        $firstLine" -ForegroundColor Gray
        }
        else {
            Write-Host "  OK: $ns - exclusions working" -ForegroundColor Green
        }
    }

    if (-not $allExclusionsWork) {
        Write-Host "`n  ERROR: Namespace exclusions not effective for: $($failedNamespaces -join ', ')" -ForegroundColor Red
        Write-Host "  Possible causes:" -ForegroundColor Yellow
        Write-Host "    - Another Azure Policy assignment at subscription/management group level" -ForegroundColor Yellow
        Write-Host "    - Azure Policy addon has not reconciled yet (try again in 2-3 min)" -ForegroundColor Yellow
        Write-Host "  Debug:" -ForegroundColor Yellow
        Write-Host "    kubectl get constraints -o json | jq '.items[].spec.match.excludedNamespaces'" -ForegroundColor Yellow
        Write-Host "    az policy assignment list --scope /subscriptions/`$(az account show --query id -o tsv)" -ForegroundColor Yellow
        Write-Host "  Bypass:" -ForegroundColor Yellow
        Write-Host "    SKIP_SAFEGUARDS_WAIT=true ./scripts/ensure-safeguards.ps1" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  All namespace exclusions verified" -ForegroundColor Green
}

Write-Host "`n=== Phase 1 Complete: Safeguards Ready ===" -ForegroundColor Green
Write-Host "You can now run Phase 2: ./scripts/deploy-platform.ps1" -ForegroundColor Cyan
