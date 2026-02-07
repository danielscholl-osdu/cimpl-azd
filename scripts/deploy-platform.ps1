#!/usr/bin/env pwsh
# Phase 2: Deploy Platform Layer
#
# This script deploys the platform components (Elasticsearch, PostgreSQL, MinIO, etc.)
# It should only be run AFTER Phase 1 (ensure-safeguards.ps1) completes successfully.
#
# Prerequisites:
# - Phase 1 completed successfully (safeguards in warn mode)
# - kubeconfig already configured
# - Environment variables set: TF_VAR_acme_email, TF_VAR_kibana_hostname

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
$kibanaHostname = $env:TF_VAR_kibana_hostname

if ([string]::IsNullOrEmpty($acmeEmail) -or [string]::IsNullOrEmpty($kibanaHostname)) {
    Write-Host "  ERROR: Missing TF_VAR_acme_email or TF_VAR_kibana_hostname" -ForegroundColor Red
    Write-Host "    Set these in .azure/<env>/.env" -ForegroundColor Gray
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
Push-Location $PSScriptRoot/../infra
$externalDnsClientId = terraform output -raw EXTERNAL_DNS_CLIENT_ID 2>$null
$tenantId = terraform output -raw AZURE_TENANT_ID 2>$null
Pop-Location

# Determine if ExternalDNS should be enabled.
# Require full DNS zone configuration (name, resource group, subscription) and identity (client + tenant).
$hasDnsZoneConfig = (-not [string]::IsNullOrEmpty($dnsZoneName)) -and `
                     (-not [string]::IsNullOrEmpty($dnsZoneRg)) -and `
                     (-not [string]::IsNullOrEmpty($dnsZoneSubId))

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
    -var="kibana_hostname=$kibanaHostname" `
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
    Write-Host "  Next steps:" -ForegroundColor Yellow
    if ($enableExternalDns -eq "true") {
        Write-Host "    1. DNS A record will be auto-created by ExternalDNS" -ForegroundColor Gray
    }
    else {
        Write-Host "    1. Create DNS A record: $kibanaHostname -> $ip" -ForegroundColor Gray
    }
    Write-Host "    2. Access Kibana: https://$kibanaHostname" -ForegroundColor Gray
    Write-Host "    3. Get Elasticsearch password:" -ForegroundColor Gray
    Write-Host "       kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d" -ForegroundColor DarkGray
}
Write-Host ""
exit 0
#endregion
