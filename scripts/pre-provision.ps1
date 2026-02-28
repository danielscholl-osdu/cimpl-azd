#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-provision validation and environment configuration.
.DESCRIPTION
    Validates prerequisites and configures environment defaults before azd provision.
    Auto-logs in when Azure CLI auth fails, auto-detects values where possible,
    generates secure defaults for credentials, and persists via 'azd env set'.
.EXAMPLE
    azd hooks run preprovision
.EXAMPLE
    ./scripts/pre-provision.ps1
#>

#Requires -Version 7.4

$ErrorActionPreference = "Stop"

# Track validation results
$script:issues = [System.Collections.ArrayList]::new()
$script:warnings = [System.Collections.ArrayList]::new()

#region Utility Functions

function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object 'System.Byte[]' ($Length)
        $rng.GetBytes($bytes)
        return -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    }
    finally { $rng.Dispose() }
}

function Set-EnvValue {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet("Critical", "Warning")][string]$Severity = "Critical"
    )
    azd env set $Name $Value 2>$null
    if ($LASTEXITCODE -ne 0) {
        $msg = "Failed to persist $Name via 'azd env set'"
        if ($Severity -eq "Critical") { [void]$script:issues.Add($msg) }
        else { [void]$script:warnings.Add($msg) }
        return $false
    }
    return $true
}

#endregion

#region Core Functions

function Test-RequiredTools {
    Write-Host "`n=================================================================="
    Write-Host "  Checking Required Tools"
    Write-Host "=================================================================="

    $tools = @(
        @{ Name = "terraform"; VersionCmd = 'terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version' },
        @{ Name = "az"; VersionCmd = '(az version | ConvertFrom-Json)."azure-cli"' },
        @{ Name = "kubelogin"; VersionCmd = 'kubelogin --version 2>&1 | Select-String -Pattern "v[\d\.]+" | ForEach-Object { $_.Matches[0].Value -replace "v","" }' },
        @{ Name = "kubectl"; VersionCmd = '(kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion -replace "v",""'; InstallHint = "Install kubectl: https://kubernetes.io/docs/tasks/tools/" }
    )

    foreach ($tool in $tools) {
        Write-Host "  $($tool.Name)..." -NoNewline
        $cmd = Get-Command $tool.Name -ErrorAction SilentlyContinue
        if (-not $cmd) {
            Write-Host " NOT FOUND" -ForegroundColor Red
            $hint = if ($tool.InstallHint) { $tool.InstallHint } else { "Please install $($tool.Name)" }
            Write-Host "    $hint" -ForegroundColor Gray
            [void]$script:issues.Add("$($tool.Name) is not installed")
            continue
        }
        try {
            $version = Invoke-Expression $tool.VersionCmd
            Write-Host " v$version" -ForegroundColor Green
        }
        catch { Write-Host " (version check failed)" -ForegroundColor Yellow }
    }
}

function Connect-Azure {
    Write-Host "`n=================================================================="
    Write-Host "  Checking Azure CLI Login"
    Write-Host "=================================================================="

    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "  Status: NOT LOGGED IN — attempting login..." -ForegroundColor Yellow
        az login 2>$null | Out-Null
        $account = az account show 2>$null | ConvertFrom-Json
        if (-not $account) {
            Write-Host "  Status: LOGIN FAILED" -ForegroundColor Red
            Write-Host "    Run manually: az login" -ForegroundColor Gray
            [void]$script:issues.Add("Azure CLI is not logged in (auto-login failed)")
            return $null
        }
        Write-Host "  Status: OK (logged in automatically)" -ForegroundColor Green
    }
    else {
        Write-Host "  Status: OK" -ForegroundColor Green
    }

    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "  Tenant: $($account.tenantId)" -ForegroundColor Gray

    # Auto-persist subscription ID if not already set
    $currentSubId = [Environment]::GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID")
    if ([string]::IsNullOrEmpty($currentSubId)) {
        Set-EnvValue -Name "AZURE_SUBSCRIPTION_ID" -Value $account.id -Severity "Warning" | Out-Null
        Write-Host "  AZURE_SUBSCRIPTION_ID: auto-set ($($account.id))" -ForegroundColor Green
    }

    return $account
}

function Set-EnvironmentDefaults {
    param($Account)

    Write-Host "`n=================================================================="
    Write-Host "  Configuring Environment Defaults"
    Write-Host "=================================================================="

    Set-AcmeEmail -Account $Account
    Set-IngressPrefix
    Set-SimpleDefaults
    Set-DnsZone -Account $Account
    Set-Credentials
}

function Set-AcmeEmail {
    param($Account)

    $acmeEmail = [Environment]::GetEnvironmentVariable("TF_VAR_acme_email")
    Write-Host "  TF_VAR_acme_email..." -NoNewline

    if (-not [string]::IsNullOrEmpty($acmeEmail)) {
        Write-Host " $acmeEmail" -ForegroundColor Green
        return
    }
    if (-not $Account) {
        Write-Host " SKIPPED (not logged in)" -ForegroundColor Yellow
        return
    }

    # Try 'mail' property first (works for both member and guest users)
    $detectedEmail = az ad signed-in-user show --query mail -o tsv 2>$null

    # Fallback: parse UPN for guest users (user_domain.com#EXT#@tenant → user@domain.com)
    if ([string]::IsNullOrEmpty($detectedEmail) -or $detectedEmail -eq "null") {
        $upn = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null
        if (-not [string]::IsNullOrEmpty($upn) -and $upn -match '^(.+)#EXT#@') {
            $detectedEmail = $Matches[1] -replace '_([^_]+)$', '@$1'
        }
        elseif (-not [string]::IsNullOrEmpty($upn) -and $upn -notmatch '#') {
            $detectedEmail = $upn
        }
    }

    if (-not [string]::IsNullOrEmpty($detectedEmail) -and $detectedEmail -ne "null" -and $detectedEmail -notmatch '#') {
        Set-EnvValue -Name "TF_VAR_acme_email" -Value $detectedEmail -Severity "Warning" | Out-Null
        Write-Host " auto-detected ($detectedEmail)" -ForegroundColor Green
    }
    else {
        Write-Host " NOT SET" -ForegroundColor Yellow
        Write-Host "    Could not auto-detect a valid email from Azure AD" -ForegroundColor Gray
        Write-Host "    Set with: azd env set TF_VAR_acme_email 'you@example.com'" -ForegroundColor Gray
        [void]$script:warnings.Add("TF_VAR_acme_email could not be auto-detected (only needed for Let's Encrypt)")
    }
}

function Set-IngressPrefix {
    $ingressPrefix = [Environment]::GetEnvironmentVariable("CIMPL_INGRESS_PREFIX")
    Write-Host "  CIMPL_INGRESS_PREFIX..." -NoNewline

    if (-not [string]::IsNullOrEmpty($ingressPrefix)) {
        Write-Host " $ingressPrefix" -ForegroundColor Green
        return
    }

    # Generate 8-char random alphanumeric prefix (lowercase + digits)
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object 'System.Byte[]' 8
        $rng.GetBytes($bytes)
        $ingressPrefix = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    } finally { $rng.Dispose() }

    Set-EnvValue -Name "CIMPL_INGRESS_PREFIX" -Value $ingressPrefix -Severity "Warning" | Out-Null
    Write-Host " generated ($ingressPrefix)" -ForegroundColor Green
    Write-Host "    Override: azd env set CIMPL_INGRESS_PREFIX 'myteam'" -ForegroundColor Gray
}

function Set-SimpleDefaults {
    $defaults = @(
        @{ Name = "TF_VAR_enable_public_ingress"; Default = "true"; Label = "true = public LB"; Hint = "Set to false for internal-only ingress" },
        @{ Name = "TF_VAR_use_letsencrypt_production"; Default = "false"; Label = "false = staging" }
    )

    foreach ($d in $defaults) {
        $current = [Environment]::GetEnvironmentVariable($d.Name)
        Write-Host "  $($d.Name)..." -NoNewline
        if ([string]::IsNullOrEmpty($current)) {
            Set-EnvValue -Name $d.Name -Value $d.Default -Severity "Warning" | Out-Null
            Write-Host " using default ($($d.Label))" -ForegroundColor Green
            if ($d.Hint) { Write-Host "    $($d.Hint)" -ForegroundColor Gray }
        }
        else {
            Write-Host " $current" -ForegroundColor Green
        }
    }
}

function Set-DnsZone {
    param($Account)

    $dnsZone = [Environment]::GetEnvironmentVariable("TF_VAR_dns_zone_name")
    Write-Host "  TF_VAR_dns_zone_name..." -NoNewline

    # --- Explicit value: validate related vars ---
    if (-not [string]::IsNullOrEmpty($dnsZone)) {
        Write-Host " $dnsZone" -ForegroundColor Green
        Set-EnvValue -Name "DNS_ZONE_NAME" -Value $dnsZone -Severity "Warning" | Out-Null

        foreach ($pair in @(
            @{ TfVar = "TF_VAR_dns_zone_resource_group"; Mirror = "DNS_ZONE_RESOURCE_GROUP" },
            @{ TfVar = "TF_VAR_dns_zone_subscription_id"; Mirror = "DNS_ZONE_SUBSCRIPTION_ID" }
        )) {
            $val = [Environment]::GetEnvironmentVariable($pair.TfVar)
            Write-Host "  $($pair.TfVar)..." -NoNewline
            if ([string]::IsNullOrEmpty($val)) {
                Write-Host " NOT SET" -ForegroundColor Yellow
                Write-Host "    Required when dns_zone_name is set: azd env set $($pair.TfVar) '<value>'" -ForegroundColor Gray
                [void]$script:issues.Add("$($pair.TfVar) is required when TF_VAR_dns_zone_name is set")
            }
            else {
                Write-Host " $val" -ForegroundColor Green
                Set-EnvValue -Name $pair.Mirror -Value $val -Severity "Warning" | Out-Null
            }
        }
        return
    }

    # --- Not logged in: skip discovery ---
    if (-not $Account) {
        Write-Host " SKIPPED (not logged in)" -ForegroundColor Yellow
        return
    }

    # --- Auto-discover DNS zones in current subscription ---
    $subId = $Account.id
    $zonesJson = az network dns zone list --subscription $subId --query "[].{name:name, id:id, resourceGroup:resourceGroup}" -o json 2>$null
    $zoneListExitCode = $LASTEXITCODE

    if ($zoneListExitCode -ne 0) {
        Write-Host " failed to list DNS zones" -ForegroundColor Yellow
        Write-Host "    The 'az network dns zone list' command failed (exit code: $zoneListExitCode)" -ForegroundColor Yellow
        Write-Host "    Check Azure CLI authentication and permissions for subscription $subId" -ForegroundColor Gray
        Write-Host "    ExternalDNS will be disabled unless you manually configure DNS zone settings" -ForegroundColor Gray
        [void]$script:warnings.Add("Failed to list DNS zones — ExternalDNS will be disabled unless configured manually")
        return
    }

    $zones = if ($zonesJson) { $zonesJson | ConvertFrom-Json } else { @() }

    if ($zones.Count -eq 1) {
        $z = $zones[0]
        foreach ($pair in @(
            @{ Name = "TF_VAR_dns_zone_name"; Value = $z.name },
            @{ Name = "DNS_ZONE_NAME"; Value = $z.name },
            @{ Name = "TF_VAR_dns_zone_resource_group"; Value = $z.resourceGroup },
            @{ Name = "DNS_ZONE_RESOURCE_GROUP"; Value = $z.resourceGroup },
            @{ Name = "TF_VAR_dns_zone_subscription_id"; Value = $subId },
            @{ Name = "DNS_ZONE_SUBSCRIPTION_ID"; Value = $subId }
        )) { Set-EnvValue -Name $pair.Name -Value $pair.Value -Severity "Warning" | Out-Null }

        Write-Host " auto-discovered ($($z.name))" -ForegroundColor Green
        Write-Host "    Resource Group: $($z.resourceGroup)" -ForegroundColor Gray
        Write-Host "    ExternalDNS will be enabled automatically" -ForegroundColor Gray
        Write-Host "    Ingress hostnames: <prefix>-<service>.$($z.name)" -ForegroundColor Gray
    }
    elseif ($zones.Count -gt 1) {
        Write-Host " multiple DNS zones found" -ForegroundColor Yellow
        foreach ($z in $zones) {
            Write-Host "    - $($z.name) (rg: $($z.resourceGroup))" -ForegroundColor Gray
        }
        Write-Host "    To select: azd env set TF_VAR_dns_zone_name '<zone-name>'" -ForegroundColor Gray
    }
    else {
        Write-Host " no DNS zones found (ExternalDNS disabled)" -ForegroundColor Gray
        Write-Host "    To enable: azd env set TF_VAR_dns_zone_name 'your.dns.zone'" -ForegroundColor Gray
    }
}

function Set-Credentials {
    # Password/secret defaults — critical: if azd env set fails, provisioning will break
    $secrets = @(
        @{ Name = "TF_VAR_cimpl_subscriber_private_key_id" },
        @{ Name = "TF_VAR_postgresql_password" },
        @{ Name = "TF_VAR_keycloak_db_password" },
        @{ Name = "TF_VAR_airflow_db_password" },
        @{ Name = "TF_VAR_redis_password" },
        @{ Name = "TF_VAR_rabbitmq_password" },
        @{ Name = "TF_VAR_rabbitmq_erlang_cookie"; Length = 32 },
        @{ Name = "TF_VAR_minio_root_password" },
        @{ Name = "TF_VAR_datafier_client_secret" }
    )

    foreach ($s in $secrets) {
        $current = [Environment]::GetEnvironmentVariable($s.Name)
        Write-Host "  $($s.Name)..." -NoNewline
        if ([string]::IsNullOrEmpty($current)) {
            $len = if ($s.ContainsKey('Length')) { $s.Length } else { 16 }
            $generated = New-RandomPassword -Length $len
            if (Set-EnvValue -Name $s.Name -Value $generated -Severity "Critical") {
                Write-Host " generated" -ForegroundColor Green
            }
            else {
                Write-Host " FAILED" -ForegroundColor Red
            }
        }
        else {
            Write-Host " set" -ForegroundColor Green
        }
    }

    # Non-secret default
    $minioUser = [Environment]::GetEnvironmentVariable("TF_VAR_minio_root_user")
    Write-Host "  TF_VAR_minio_root_user..." -NoNewline
    if ([string]::IsNullOrEmpty($minioUser)) {
        Set-EnvValue -Name "TF_VAR_minio_root_user" -Value "minioadmin" -Severity "Warning" | Out-Null
        Write-Host " using default (minioadmin)" -ForegroundColor Green
    }
    else {
        Write-Host " $minioUser" -ForegroundColor Green
    }
}

function Register-Providers {
    Write-Host "`n=================================================================="
    Write-Host "  Checking Azure Resource Providers"
    Write-Host "=================================================================="

    $providers = @("Microsoft.ContainerService", "Microsoft.OperationsManagement")

    foreach ($provider in $providers) {
        Write-Host "  $provider..." -NoNewline
        $stateRaw = az provider show -n $provider --query "registrationState" -o tsv 2>$null
        $exitCode = $LASTEXITCODE
        $state = if ($stateRaw) { "$stateRaw".Trim() } else { "Unknown" }

        if ($exitCode -ne 0) {
            Write-Host " check failed" -ForegroundColor Yellow
            [void]$script:warnings.Add("Could not check resource provider $provider (az CLI error)")
        }
        elseif ($state -eq "Registered") {
            Write-Host " Registered" -ForegroundColor Green
        }
        else {
            Write-Host " $state — registering..." -ForegroundColor Yellow
            az provider register -n $provider 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    Registration failed" -ForegroundColor Red
                [void]$script:issues.Add("Failed to register resource provider $provider")
            }
            else {
                Write-Host "    Registration initiated (Terraform will wait during apply)" -ForegroundColor Gray
                [void]$script:warnings.Add("Resource provider $provider registration initiated (not yet complete)")
            }
        }
    }
}

function Show-Summary {
    Write-Host ""

    if ($script:warnings.Count -gt 0) {
        Write-Host "==================================================================" -ForegroundColor Yellow
        Write-Host "  Warnings ($($script:warnings.Count))"                              -ForegroundColor Yellow
        Write-Host "==================================================================" -ForegroundColor Yellow
        for ($i = 0; $i -lt $script:warnings.Count; $i++) {
            Write-Host "  $($i + 1). $($script:warnings[$i])" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($script:issues.Count -gt 0) {
        Write-Host "==================================================================" -ForegroundColor Red
        Write-Host "  Pre-Provision Validation FAILED ($($script:issues.Count) issues)"  -ForegroundColor Red
        Write-Host "==================================================================" -ForegroundColor Red
        for ($i = 0; $i -lt $script:issues.Count; $i++) {
            Write-Host "  $($i + 1). $($script:issues[$i])" -ForegroundColor Yellow
        }
        Write-Host ""
        exit 1
    }

    $label = if ($script:warnings.Count -gt 0) { "PASSED (with $($script:warnings.Count) warnings)" } else { "PASSED" }
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "  Pre-Provision Validation $label"                                   -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  To view configured values:  azd env get-values" -ForegroundColor Gray
    Write-Host "  To override a value:        azd env set TF_VAR_<name> <value>" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

#endregion

# --- Main Flow ---

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Pre-Provision Validation"                                         -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Test-RequiredTools
$account = Connect-Azure
Set-EnvironmentDefaults -Account $account
Register-Providers
Show-Summary
