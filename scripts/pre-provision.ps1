#!/usr/bin/env pwsh
# Pre-provision validation script
# Validates prerequisites and configures environment defaults before azd provision.
#
# Following the osdu-developer pattern:
# - Auto-detect values where possible (email from Azure AD)
# - Generate secure defaults for credentials
# - Persist via 'azd env set' so values survive across runs
# - Allow user override: azd env set TF_VAR_<name> <value>

$ErrorActionPreference = "Stop"

# Track validation issues for summary
$issues = [System.Collections.ArrayList]::new()

# Helper: Generate a random alphanumeric password (safe for YAML/Helm values)
function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $passwordChars = New-Object 'System.Char[]' ($Length)

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object 'System.Byte[]' ($Length)
        $rng.GetBytes($bytes)

        for ($i = 0; $i -lt $Length; $i++) {
            $index = $bytes[$i] % $chars.Length
            $passwordChars[$i] = $chars[$index]
        }
    }
    finally {
        $rng.Dispose()
    }

    return -join $passwordChars
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Pre-Provision Validation"                                         -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

#region Required Tools
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Checking Required Tools"
Write-Host "=================================================================="

$requiredTools = @(
    @{Name = "terraform"; MinVersion = "1.5.0"; VersionCmd = 'terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version' },
    @{Name = "az"; MinVersion = "2.50.0"; VersionCmd = '(az version | ConvertFrom-Json)."azure-cli"' },
    @{Name = "kubelogin"; MinVersion = "0.0.0"; VersionCmd = 'kubelogin --version 2>&1 | Select-String -Pattern "v[\d\.]+" | ForEach-Object { $_.Matches[0].Value -replace "v","" }' },
    @{Name = "kubectl"; MinVersion = "1.28.0"; VersionCmd = '(kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion -replace "v",""'; InstallHint = "Install kubectl: https://kubernetes.io/docs/tasks/tools/" }
)

foreach ($tool in $requiredTools) {
    Write-Host "  $($tool.Name)..." -NoNewline

    $cmd = Get-Command $tool.Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        if ($tool.InstallHint) {
            Write-Host "    $($tool.InstallHint)" -ForegroundColor Gray
        } else {
            Write-Host "    Please install $($tool.Name)" -ForegroundColor Gray
        }
        [void]$issues.Add("$($tool.Name) is not installed")
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
#endregion

#region Azure CLI Login
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Checking Azure CLI Login"
Write-Host "=================================================================="

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "  Status: NOT LOGGED IN" -ForegroundColor Red
    Write-Host "    Run: az login" -ForegroundColor Gray
    [void]$issues.Add("Azure CLI is not logged in")
}
else {
    Write-Host "  Status: OK" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host "  Tenant: $($account.tenantId)" -ForegroundColor Gray
}
#endregion

#region Environment Defaults
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Configuring Environment Defaults"
Write-Host "=================================================================="

# --- TF_VAR_acme_email: auto-detect from Azure AD signed-in user ---
$acmeEmail = [Environment]::GetEnvironmentVariable("TF_VAR_acme_email")
Write-Host "  TF_VAR_acme_email..." -NoNewline
if ([string]::IsNullOrEmpty($acmeEmail)) {
    if ($account) {
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
            azd env set TF_VAR_acme_email $detectedEmail 2>$null
            Write-Host " auto-detected ($detectedEmail)" -ForegroundColor Green
        }
        else {
            Write-Host " NOT SET" -ForegroundColor Yellow
            Write-Host "    Could not auto-detect a valid email from Azure AD" -ForegroundColor Gray
            Write-Host "    Set with: azd env set TF_VAR_acme_email 'you@example.com'" -ForegroundColor Gray
            [void]$issues.Add("TF_VAR_acme_email could not be auto-detected")
        }
    }
    else {
        Write-Host " SKIPPED (not logged in)" -ForegroundColor Yellow
    }
}
else {
    Write-Host " $acmeEmail" -ForegroundColor Green
}

# --- CIMPL_INGRESS_PREFIX: unique prefix for ingress hostnames ---
$ingressPrefix = [Environment]::GetEnvironmentVariable("CIMPL_INGRESS_PREFIX")
Write-Host "  CIMPL_INGRESS_PREFIX..." -NoNewline
if ([string]::IsNullOrEmpty($ingressPrefix)) {
    # Generate 8-char random alphanumeric prefix (lowercase + digits)
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object 'System.Byte[]' 8
        $rng.GetBytes($bytes)
        $prefixChars = for ($i = 0; $i -lt 8; $i++) { $chars[$bytes[$i] % $chars.Length] }
        $ingressPrefix = -join $prefixChars
    } finally { $rng.Dispose() }
    azd env set CIMPL_INGRESS_PREFIX $ingressPrefix 2>$null
    Write-Host " generated ($ingressPrefix)" -ForegroundColor Green
    Write-Host "    Override: azd env set CIMPL_INGRESS_PREFIX 'myteam'" -ForegroundColor Gray
}
else {
    Write-Host " $ingressPrefix" -ForegroundColor Green
}

# --- TF_VAR_use_letsencrypt_production: default to false (staging) ---
$useProd = [Environment]::GetEnvironmentVariable("TF_VAR_use_letsencrypt_production")
Write-Host "  TF_VAR_use_letsencrypt_production..." -NoNewline
if ([string]::IsNullOrEmpty($useProd)) {
    azd env set TF_VAR_use_letsencrypt_production "false" 2>$null
    Write-Host " using default (false = staging)" -ForegroundColor Green
}
else {
    Write-Host " $useProd" -ForegroundColor Green
}

# --- DNS zone: auto-discover or use explicit value ---
$dnsZone = [Environment]::GetEnvironmentVariable("TF_VAR_dns_zone_name")
Write-Host "  TF_VAR_dns_zone_name..." -NoNewline
if (-not [string]::IsNullOrEmpty($dnsZone)) {
    # Explicit value set — validate related vars
    Write-Host " $dnsZone" -ForegroundColor Green

    $dnsRg = [Environment]::GetEnvironmentVariable("TF_VAR_dns_zone_resource_group")
    Write-Host "  TF_VAR_dns_zone_resource_group..." -NoNewline
    if ([string]::IsNullOrEmpty($dnsRg)) {
        Write-Host " NOT SET" -ForegroundColor Yellow
        Write-Host "    Required when dns_zone_name is set: azd env set TF_VAR_dns_zone_resource_group '<rg>'" -ForegroundColor Gray
        [void]$issues.Add("TF_VAR_dns_zone_resource_group is required when TF_VAR_dns_zone_name is set")
    }
    else {
        Write-Host " $dnsRg" -ForegroundColor Green
    }

    $dnsSub = [Environment]::GetEnvironmentVariable("TF_VAR_dns_zone_subscription_id")
    Write-Host "  TF_VAR_dns_zone_subscription_id..." -NoNewline
    if ([string]::IsNullOrEmpty($dnsSub)) {
        Write-Host " NOT SET" -ForegroundColor Yellow
        Write-Host "    Required when dns_zone_name is set: azd env set TF_VAR_dns_zone_subscription_id '<sub-id>'" -ForegroundColor Gray
        [void]$issues.Add("TF_VAR_dns_zone_subscription_id is required when TF_VAR_dns_zone_name is set")
    }
    else {
        Write-Host " $dnsSub" -ForegroundColor Green
    }
}
elseif ($account) {
    # Auto-discover DNS zones in current subscription
    $subId = $account.id
    $zonesJson = az network dns zone list --subscription $subId --query "[].{name:name, id:id, resourceGroup:resourceGroup}" -o json 2>$null
    $zoneListExitCode = $LASTEXITCODE

    if ($zoneListExitCode -ne 0) {
        # Command failed — permissions or auth issue
        Write-Host " failed to list DNS zones" -ForegroundColor Yellow
        Write-Host "    The 'az network dns zone list' command failed (exit code: $zoneListExitCode)" -ForegroundColor Yellow
        Write-Host "    Check Azure CLI authentication and permissions for subscription $subId" -ForegroundColor Gray
        Write-Host "    ExternalDNS will be disabled unless you manually configure DNS zone settings" -ForegroundColor Gray
        [void]$issues.Add("Failed to list DNS zones - check Azure CLI auth and permissions")
    }
    else {
        $zones = if ($zonesJson) { $zonesJson | ConvertFrom-Json } else { @() }

        if ($zones.Count -eq 1) {
        # Single zone found — auto-configure
        $discoveredZone = $zones[0].name
        $discoveredRg = $zones[0].resourceGroup

        azd env set TF_VAR_dns_zone_name $discoveredZone 2>$null
        azd env set TF_VAR_dns_zone_resource_group $discoveredRg 2>$null
        azd env set TF_VAR_dns_zone_subscription_id $subId 2>$null

        Write-Host " auto-discovered ($discoveredZone)" -ForegroundColor Green
        Write-Host "    Resource Group: $discoveredRg" -ForegroundColor Gray
        Write-Host "    ExternalDNS will be enabled automatically" -ForegroundColor Gray
        Write-Host "    Ingress hostnames: <prefix>-<service>.$discoveredZone" -ForegroundColor Gray
    }
    elseif ($zones.Count -gt 1) {
        # Multiple zones — user must pick
        Write-Host " multiple DNS zones found" -ForegroundColor Yellow
        foreach ($z in $zones) {
            Write-Host "    - $($z.name) (rg: $($z.resourceGroup))" -ForegroundColor Gray
        }
        Write-Host "    To select: azd env set TF_VAR_dns_zone_name '<zone-name>'" -ForegroundColor Gray
    }
    else {
        # No zones found
        Write-Host " no DNS zones found (ExternalDNS disabled)" -ForegroundColor Gray
        Write-Host "    To enable: azd env set TF_VAR_dns_zone_name 'your.dns.zone'" -ForegroundColor Gray
    }
    }
}
else {
    Write-Host " SKIPPED (not logged in)" -ForegroundColor Yellow
}

# --- TF_VAR_cimpl_subscriber_private_key_id: generate random if not set ---
$cimplSubscriberPrivateKeyId = [Environment]::GetEnvironmentVariable("TF_VAR_cimpl_subscriber_private_key_id")
Write-Host "  TF_VAR_cimpl_subscriber_private_key_id..." -NoNewline
if ([string]::IsNullOrEmpty($cimplSubscriberPrivateKeyId)) {
    $generatedCimplSubscriberPrivateKeyId = New-RandomPassword
    azd env set TF_VAR_cimpl_subscriber_private_key_id $generatedCimplSubscriberPrivateKeyId 2>$null
    Write-Host " generated" -ForegroundColor Green
}
else {
    Write-Host " set" -ForegroundColor Green
}

# --- TF_VAR_postgresql_password: generate random if not set ---
$pgPassword = [Environment]::GetEnvironmentVariable("TF_VAR_postgresql_password")
Write-Host "  TF_VAR_postgresql_password..." -NoNewline
if ([string]::IsNullOrEmpty($pgPassword)) {
    $generatedPgPassword = New-RandomPassword
    azd env set TF_VAR_postgresql_password $generatedPgPassword 2>$null
    Write-Host " generated" -ForegroundColor Green
}
else {
    Write-Host " set" -ForegroundColor Green
}

# --- TF_VAR_redis_password: generate random if not set ---
$redisPassword = [Environment]::GetEnvironmentVariable("TF_VAR_redis_password")
Write-Host "  TF_VAR_redis_password..." -NoNewline
if ([string]::IsNullOrEmpty($redisPassword)) {
    $generatedRedisPassword = New-RandomPassword
    azd env set TF_VAR_redis_password $generatedRedisPassword 2>$null
    Write-Host " generated" -ForegroundColor Green
}
else {
    Write-Host " set" -ForegroundColor Green
}

# --- TF_VAR_minio_root_user: default to minioadmin ---
$minioUser = [Environment]::GetEnvironmentVariable("TF_VAR_minio_root_user")
Write-Host "  TF_VAR_minio_root_user..." -NoNewline
if ([string]::IsNullOrEmpty($minioUser)) {
    $defaultUser = "minioadmin"
    azd env set TF_VAR_minio_root_user $defaultUser 2>$null
    Write-Host " using default ($defaultUser)" -ForegroundColor Green
}
else {
    Write-Host " $minioUser" -ForegroundColor Green
}

# --- TF_VAR_minio_root_password: generate random if not set ---
$minioPassword = [Environment]::GetEnvironmentVariable("TF_VAR_minio_root_password")
Write-Host "  TF_VAR_minio_root_password..." -NoNewline
if ([string]::IsNullOrEmpty($minioPassword)) {
    $generatedMinioPassword = New-RandomPassword
    azd env set TF_VAR_minio_root_password $generatedMinioPassword 2>$null
    Write-Host " generated" -ForegroundColor Green
}
else {
    Write-Host " set" -ForegroundColor Green
}
#endregion

#region Azure Resource Providers
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Checking Azure Resource Providers"
Write-Host "=================================================================="

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
        [void]$issues.Add("Resource provider $provider is not registered ($state)")
    }
}
#endregion

#region Summary
Write-Host ""
if ($issues.Count -gt 0) {
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Pre-Provision Validation FAILED ($($issues.Count) issues)"       -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Red
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "  $($i + 1). $($issues[$i])" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}

Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Pre-Provision Validation PASSED"                                  -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  To view configured values:  azd env get-values" -ForegroundColor Gray
Write-Host "  To override a value:        azd env set TF_VAR_<name> <value>" -ForegroundColor Gray
Write-Host ""
exit 0
#endregion
