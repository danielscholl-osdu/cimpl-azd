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

Write-Host "=== Phase 2: Deploying Platform Layer ===" -ForegroundColor Cyan

# Get resource group, cluster name, and subscription from environment or terraform outputs
$resourceGroup = $env:AZURE_RESOURCE_GROUP
$clusterName = $env:AZURE_AKS_CLUSTER_NAME
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName) -or [string]::IsNullOrEmpty($subscriptionId)) {
    Write-Host "Getting values from terraform outputs..." -ForegroundColor Gray
    Push-Location $PSScriptRoot/../infra
    if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = terraform output -raw AZURE_RESOURCE_GROUP 2>$null }
    if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = terraform output -raw AZURE_AKS_CLUSTER_NAME 2>$null }
    if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = terraform output -raw AZURE_SUBSCRIPTION_ID 2>$null }
    Pop-Location
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

# Step 1: Verify kubeconfig
Write-Host "`n[1/3] Verifying cluster access..." -ForegroundColor Cyan
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

# Step 2: Deploy platform layer
Write-Host "`n[2/3] Deploying platform layer..." -ForegroundColor Cyan
Push-Location $PSScriptRoot/../platform

# Initialize terraform if needed
if (-not (Test-Path ".terraform")) {
    Write-Host "  Initializing terraform..." -ForegroundColor Gray
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Terraform init failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}

# Get variables from environment
$acmeEmail = $env:TF_VAR_acme_email
$kibanaHostname = $env:TF_VAR_kibana_hostname

if ([string]::IsNullOrEmpty($acmeEmail) -or [string]::IsNullOrEmpty($kibanaHostname)) {
    Write-Host "  Missing TF_VAR_acme_email or TF_VAR_kibana_hostname" -ForegroundColor Red
    Write-Host "  Set these in .azure/<env>/.env" -ForegroundColor Gray
    Pop-Location
    exit 1
}

# Run terraform apply
Write-Host "  Running terraform apply..." -ForegroundColor Gray
terraform apply -auto-approve `
    -var="cluster_name=$clusterName" `
    -var="resource_group_name=$resourceGroup" `
    -var="acme_email=$acmeEmail" `
    -var="kibana_hostname=$kibanaHostname"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Platform deployment failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "  Platform layer deployed" -ForegroundColor Green
Pop-Location

# Step 3: Verify deployment
Write-Host "`n[3/3] Verifying deployment..." -ForegroundColor Cyan

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

# Summary
Write-Host "`n=== Phase 2 Complete: Platform Deployed ===" -ForegroundColor Cyan
Write-Host "Cluster: $clusterName" -ForegroundColor White
Write-Host "Resource Group: $resourceGroup" -ForegroundColor White

if ($ip) {
    Write-Host "External IP: $ip" -ForegroundColor White
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Create DNS A record: $kibanaHostname -> $ip" -ForegroundColor Gray
    Write-Host "  2. Access Kibana: https://$kibanaHostname" -ForegroundColor Gray
    Write-Host "  3. Get Elasticsearch password:" -ForegroundColor Gray
    Write-Host "     kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d" -ForegroundColor DarkGray
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
