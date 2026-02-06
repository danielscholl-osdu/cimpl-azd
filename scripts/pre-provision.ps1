#!/usr/bin/env pwsh
# Pre-provision validation script

$ErrorActionPreference = "Stop"

Write-Host "=== Pre-Provision Validation ===" -ForegroundColor Cyan

# Check required tools
$requiredTools = @(
    @{Name = "terraform"; MinVersion = "1.5.0"; VersionCmd = 'terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version' },
    @{Name = "az"; MinVersion = "2.50.0"; VersionCmd = '(az version | ConvertFrom-Json)."azure-cli"' },
    @{Name = "kubelogin"; MinVersion = "0.0.0"; VersionCmd = 'kubelogin --version 2>&1 | Select-String -Pattern "v[\d\.]+" | ForEach-Object { $_.Matches[0].Value -replace "v","" }' },
    @{Name = "kubectl"; MinVersion = "1.28.0"; VersionCmd = '(kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion -replace "v",""'; InstallHint = "Install kubectl: https://kubernetes.io/docs/tasks/tools/" }
)

$allPassed = $true

foreach ($tool in $requiredTools) {
    Write-Host "`nChecking $($tool.Name)..." -NoNewline

    $cmd = Get-Command $tool.Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        if ($tool.InstallHint) {
            Write-Host "  $($tool.InstallHint)" -ForegroundColor Yellow
        } else {
            Write-Host "  Please install $($tool.Name)" -ForegroundColor Yellow
        }
        $allPassed = $false
        continue
    }

    try {
        $version = Invoke-Expression $tool.VersionCmd
        Write-Host " v$version" -ForegroundColor Green
    }
    catch {
        Write-Host " (version check failed)" -ForegroundColor Yellow
    }
}

# Verify Azure CLI login
Write-Host "`nChecking Azure CLI login..." -NoNewline
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host " NOT LOGGED IN" -ForegroundColor Red
    Write-Host "  Please run: az login" -ForegroundColor Yellow
    $allPassed = $false
}
else {
    Write-Host " OK" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "  Tenant: $($account.tenantId)" -ForegroundColor Gray
}

# Verify required environment variables
Write-Host "`nChecking environment variables..." -ForegroundColor Cyan
$requiredEnvVars = @("TF_VAR_acme_email", "TF_VAR_kibana_hostname", "TF_VAR_postgresql_password", "TF_VAR_minio_root_user", "TF_VAR_minio_root_password")

foreach ($envVar in $requiredEnvVars) {
    $value = [Environment]::GetEnvironmentVariable($envVar)
    Write-Host "  $envVar..." -NoNewline
    if ([string]::IsNullOrEmpty($value)) {
        Write-Host " NOT SET" -ForegroundColor Yellow
        Write-Host "    Set with: `$env:$envVar = 'value'" -ForegroundColor Gray
        $allPassed = $false
    }
    else {
        Write-Host " OK" -ForegroundColor Green
    }
}

# Check Azure subscription has required providers
Write-Host "`nChecking Azure resource providers..." -ForegroundColor Cyan
$requiredProviders = @(
    "Microsoft.ContainerService",
    "Microsoft.OperationsManagement"
)

foreach ($provider in $requiredProviders) {
    Write-Host "  $provider..." -NoNewline
    $stateRaw = az provider show -n $provider --query "registrationState" -o tsv 2>$null
    $state = if ($stateRaw) { "$stateRaw".Trim() } else { "Unknown" }
    if ($state -eq "Registered") {
        Write-Host " Registered" -ForegroundColor Green
    }
    else {
        Write-Host " $state" -ForegroundColor Yellow
        Write-Host "    Register with: az provider register -n $provider" -ForegroundColor Gray
    }
}

if (-not $allPassed) {
    Write-Host "`n=== Pre-provision validation FAILED ===" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Pre-provision validation PASSED ===" -ForegroundColor Green
