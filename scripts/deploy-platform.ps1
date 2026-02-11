#!/usr/bin/env pwsh
# Phase 2: Deploy Platform Layer
#
# This script deploys the platform components (Elasticsearch, PostgreSQL, MinIO, etc.)
# It should only be run AFTER Phase 1 (ensure-safeguards.ps1) completes successfully.
#
# Prerequisites:
# - Phase 1 completed successfully (safeguards in warn mode)
# - kubeconfig already configured
# - Environment variables set: TF_VAR_acme_email, CIMPL_INGRESS_PREFIX

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Phase 2: Deploy Platform Layer"                                   -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Get resource group, cluster name, and subscription from environment or terraform outputs
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$clusterName = $env:AZURE_AKS_CLUSTER_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "  Getting values from terraform outputs..." -ForegroundColor Gray
    $envNameFallback = $env:AZURE_ENV_NAME
    $infraStateFallback = "$PSScriptRoot/../.azure/$envNameFallback/infra/terraform.tfstate"
    Push-Location $PSScriptRoot/../infra
    if (Test-Path $infraStateFallback) {
        if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = terraform output -raw "-state=$infraStateFallback" AZURE_RESOURCE_GROUP 2>$null }
        if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = terraform output -raw "-state=$infraStateFallback" AZURE_AKS_CLUSTER_NAME 2>$null }
        if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = terraform output -raw "-state=$infraStateFallback" AZURE_SUBSCRIPTION_ID 2>$null }
    }
    else {
        if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null }
        if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = terraform output -raw AZURE_AKS_CLUSTER_NAME 2>$null }
        if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = terraform output -raw AZURE_SUBSCRIPTION_ID 2>$null }
    }
    Pop-Location
}

if ([string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "Subscription ID not provided; falling back to current az account..." -ForegroundColor Gray
    $subscriptionId = az account show --query id -o tsv 2>$null
}

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
    Write-Host "  ERROR: Could not determine resource group or cluster name" -ForegroundColor Red
    exit 1
}

Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "  Cluster: $clusterName" -ForegroundColor Gray
if (-not [string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "  Subscription: $subscriptionId" -ForegroundColor Gray
}

# Build common subscription argument for az commands
$subscriptionArgs = if (-not [string]::IsNullOrEmpty($subscriptionId)) { @("--subscription", $subscriptionId) } else { @() }

#region Step 1: Verify kubeconfig
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [1/3] Verifying Cluster Access"
Write-Host "=================================================================="

$nodes = kubectl get nodes --no-headers 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Kubeconfig not configured, configuring now..." -ForegroundColor Yellow
    az aks get-credentials -g $resourceGroup -n $clusterName @subscriptionArgs --overwrite-existing
    kubelogin convert-kubeconfig -l azurecli
    # Re-fetch nodes after configuring kubeconfig
    $nodes = kubectl get nodes --no-headers 2>$null
}
$nodeCount = ($nodes -split "`n" | Where-Object { $_ }).Count
Write-Host "  Cluster access verified ($nodeCount nodes)" -ForegroundColor Green
#endregion

#region Step 2: Deploy platform layer
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [2/3] Deploying Platform Layer"
Write-Host "=================================================================="

Push-Location $PSScriptRoot/../platform

# Initialize terraform if needed
if (-not (Test-Path ".terraform")) {
    Write-Host "  Initializing terraform..." -ForegroundColor Gray
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Terraform init failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}

# Get variables from environment
$acmeEmail = $env:TF_VAR_acme_email
$ingressPrefix = $env:CIMPL_INGRESS_PREFIX

if ([string]::IsNullOrEmpty($acmeEmail)) {
    Write-Host "  ERROR: Missing TF_VAR_acme_email" -ForegroundColor Red
    Write-Host "    Set with: azd env set TF_VAR_acme_email 'you@example.com'" -ForegroundColor Gray
    Pop-Location
    exit 1
}

# Get ExternalDNS / issuer vars from environment and infra outputs
$useLetsencryptProd = $env:TF_VAR_use_letsencrypt_production
if ([string]::IsNullOrEmpty($useLetsencryptProd)) { $useLetsencryptProd = "false" }

$dnsZoneName = $env:TF_VAR_dns_zone_name
$dnsZoneRg = $env:TF_VAR_dns_zone_resource_group
$dnsZoneSubId = $env:TF_VAR_dns_zone_subscription_id

# Get UAMI client ID and tenant ID from infra terraform outputs
# azd manages infra state at .azure/<env>/infra/terraform.tfstate, not in the source dir
# Determine state file location
$envName = $env:AZURE_ENV_NAME
$stateArgs = @()
if (-not [string]::IsNullOrEmpty($envName)) {
    $infraStateFile = "$PSScriptRoot/../.azure/$envName/infra/terraform.tfstate"
    if (Test-Path $infraStateFile) {
        $stateArgs = @("-state=$infraStateFile")
    }
    else {
        Write-Host "  WARNING: Infra state not found at $infraStateFile, falling back to local state" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  WARNING: AZURE_ENV_NAME not set; using local infra state (non-azd workflow)" -ForegroundColor Yellow
}

# Read outputs (single block, uses $stateArgs if azd state exists)
Push-Location $PSScriptRoot/../infra
$externalDnsClientId = terraform output -raw @stateArgs EXTERNAL_DNS_CLIENT_ID 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  WARNING: Could not read EXTERNAL_DNS_CLIENT_ID from infra state" -ForegroundColor Yellow
    $externalDnsClientId = ""
}
$tenantId = terraform output -raw @stateArgs AZURE_TENANT_ID 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  WARNING: Could not read AZURE_TENANT_ID from infra state" -ForegroundColor Yellow
    $tenantId = ""
}
Pop-Location

# Determine if DNS zone is fully configured
$hasDnsZoneConfig = (-not [string]::IsNullOrEmpty($dnsZoneName)) -and `
                     (-not [string]::IsNullOrEmpty($dnsZoneRg)) -and `
                     (-not [string]::IsNullOrEmpty($dnsZoneSubId))

# Fix #67: If DNS zone configured but ExternalDNS identity missing, re-apply infra layer
if ($hasDnsZoneConfig -and [string]::IsNullOrEmpty($externalDnsClientId)) {
    Write-Host "  DNS zone configured but ExternalDNS identity not found — applying infra layer..." -ForegroundColor Yellow
    Push-Location $PSScriptRoot/../infra
    $env:ARM_SUBSCRIPTION_ID = $subscriptionId
    # azd stores infra variables in main.tfvars.json alongside the state file
    $infraVarFileArgs = @()
    if (-not [string]::IsNullOrEmpty($envName)) {
        $infraVarFile = "$PSScriptRoot/../.azure/$envName/infra/main.tfvars.json"
        if (Test-Path $infraVarFile) {
            $infraVarFileArgs = @("-var-file=$infraVarFile")
        }
    }
    terraform apply -auto-approve @stateArgs @infraVarFileArgs
    if ($LASTEXITCODE -eq 0) {
        $externalDnsClientId = terraform output -raw @stateArgs EXTERNAL_DNS_CLIENT_ID 2>$null
        if ($LASTEXITCODE -ne 0) { $externalDnsClientId = "" }
        $tenantId = terraform output -raw @stateArgs AZURE_TENANT_ID 2>$null
        if ($LASTEXITCODE -ne 0) { $tenantId = "" }
        Write-Host "  ExternalDNS identity created" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Infra re-apply failed, ExternalDNS will be disabled" -ForegroundColor Yellow
    }
    Pop-Location
}

# Determine if ExternalDNS should be enabled.
# Require full DNS zone configuration (name, resource group, subscription) and identity (client + tenant).

$hasIdentityConfig = (-not [string]::IsNullOrEmpty($externalDnsClientId)) -and `
                      (-not [string]::IsNullOrEmpty($tenantId))

$enableExternalDns = if ($hasDnsZoneConfig -and $hasIdentityConfig) { "true" } else { "false" }

Write-Host "  LetsEncrypt issuer: $(if ($useLetsencryptProd -eq 'true') { 'production' } else { 'staging' })" -ForegroundColor Gray
Write-Host "  ExternalDNS: $(if ($enableExternalDns -eq 'true') { 'enabled' } else { 'disabled' })" -ForegroundColor Gray

# Run terraform apply
Write-Host "  Running terraform apply..." -ForegroundColor Gray
terraform apply -auto-approve `
    -var="cluster_name=$clusterName" `
    -var="resource_group_name=$resourceGroup" `
    -var="acme_email=$acmeEmail" `
    -var="ingress_prefix=$ingressPrefix" `
    -var="use_letsencrypt_production=$useLetsencryptProd" `
    -var="enable_external_dns=$enableExternalDns" `
    -var="dns_zone_name=$dnsZoneName" `
    -var="dns_zone_resource_group=$dnsZoneRg" `
    -var="dns_zone_subscription_id=$dnsZoneSubId" `
    -var="external_dns_client_id=$externalDnsClientId" `
    -var="tenant_id=$tenantId"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Platform deployment failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "  Platform layer deployed" -ForegroundColor Green
Pop-Location
#endregion

#region Step 3: Verify deployment
Write-Host ""
Write-Host "=================================================================="
Write-Host "  [3/3] Verifying Deployment"
Write-Host "=================================================================="

# Wait for components to stabilize
Write-Host "  Waiting 30 seconds for components to stabilize..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Verify nodes
$nodes = kubectl get nodes --no-headers 2>$null
$nodeCount = ($nodes -split "`n" | Where-Object { $_ }).Count
Write-Host "  Nodes: $nodeCount ready" -ForegroundColor Green

# Verify Elasticsearch
$es = kubectl get elasticsearch -n elastic-search -o jsonpath='{.items[0].status.health}' 2>$null
if ($es) {
    Write-Host "  Elasticsearch: $es" -ForegroundColor $(if ($es -eq "green") { "Green" } else { "Yellow" })
}
else {
    Write-Host "  Elasticsearch: Pending" -ForegroundColor Yellow
}

# Verify Kibana
$kibana = kubectl get kibana -n elastic-search -o jsonpath='{.items[0].status.health}' 2>$null
if ($kibana) {
    Write-Host "  Kibana: $kibana" -ForegroundColor $(if ($kibana -eq "green") { "Green" } else { "Yellow" })
}
else {
    Write-Host "  Kibana: Pending" -ForegroundColor Yellow
}

# Verify PostgreSQL
$pgPods = kubectl get pods -n postgresql -o jsonpath='{.items[*].status.phase}' 2>$null
if ($pgPods -like "*Running*") {
    Write-Host "  PostgreSQL: Running" -ForegroundColor Green
}
else {
    Write-Host "  PostgreSQL: Pending" -ForegroundColor Yellow
}

# Verify Redis
$redisPods = kubectl get pods -n redis -o jsonpath='{.items[*].status.phase}' 2>$null
if ($redisPods -like "*Running*") {
    Write-Host "  Redis: Running" -ForegroundColor Green
}
else {
    Write-Host "  Redis: Pending" -ForegroundColor Yellow
}

# Verify MinIO
$minioPods = kubectl get pods -n minio -o jsonpath='{.items[*].status.phase}' 2>$null
if ($minioPods -like "*Running*") {
    Write-Host "  MinIO: Running" -ForegroundColor Green
}
else {
    Write-Host "  MinIO: Pending" -ForegroundColor Yellow
}

# Get external IP
$ip = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
#endregion

#region Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Phase 2 Complete: Platform Deployed"                              -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Cluster: $clusterName"
Write-Host "  Resource Group: $resourceGroup"

if ($ip) {
    Write-Host "  External IP: $ip"
    Write-Host ""
    # Derive Kibana hostname from ingress prefix + DNS zone
    $kibanaHost = if (-not [string]::IsNullOrEmpty($ingressPrefix) -and -not [string]::IsNullOrEmpty($dnsZoneName)) {
        "$ingressPrefix-kibana.$dnsZoneName"
    } else { "" }

    Write-Host "  Next steps:" -ForegroundColor Yellow
    if ($enableExternalDns -eq "true" -and -not [string]::IsNullOrEmpty($kibanaHost)) {
        Write-Host "    1. DNS A record will be auto-created by ExternalDNS" -ForegroundColor Gray
        Write-Host "    2. Access Kibana: https://$kibanaHost" -ForegroundColor Gray
    }
    elseif (-not [string]::IsNullOrEmpty($kibanaHost)) {
        Write-Host "    1. Create DNS A record: $kibanaHost -> $ip" -ForegroundColor Gray
        Write-Host "    2. Access Kibana: https://$kibanaHost" -ForegroundColor Gray
    }
    else {
        Write-Host "    1. Configure DNS zone for external access" -ForegroundColor Gray
    }
    Write-Host "    3. Get Elasticsearch password:" -ForegroundColor Gray
    Write-Host "       kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d" -ForegroundColor DarkGray
}
Write-Host ""
exit 0
#endregion
