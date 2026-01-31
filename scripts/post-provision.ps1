#!/usr/bin/env pwsh
# Post-provision script - Deploys Platform Layer (Layer 2)
#
# This script runs after the cluster is provisioned and:
# 1. Configures kubeconfig
# 2. Configures AKS safeguards for Helm compatibility
# 3. Deploys the platform layer via terraform
# 4. Verifies all components

$ErrorActionPreference = "Stop"

Write-Host "=== Post-Provision: Deploying Platform Layer ===" -ForegroundColor Cyan

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
Write-Host "`n[1/4] Configuring kubeconfig..." -ForegroundColor Cyan
az aks get-credentials -g $resourceGroup -n $clusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get kubeconfig" -ForegroundColor Red
    exit 1
}
kubelogin convert-kubeconfig -l azurecli
Write-Host "  Kubeconfig configured" -ForegroundColor Green

# Step 2: Configure AKS safeguards
Write-Host "`n[2/4] Configuring AKS safeguards..." -ForegroundColor Cyan
$excludedNs = "elastic-system,elastic-search,cert-manager,aks-istio-ingress,postgresql,minio"
$safeguardsResult = az aks update -g $resourceGroup -n $clusterName `
    --safeguards-level Warning `
    --safeguards-excluded-ns $excludedNs `
    --only-show-errors 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Safeguards: Warning mode" -ForegroundColor Green
    Write-Host "  Excluded: $excludedNs" -ForegroundColor Gray
}
else {
    Write-Host "  Safeguards configuration skipped (preview feature)" -ForegroundColor Yellow
}

# Step 3: Deploy platform layer
Write-Host "`n[3/4] Deploying platform layer..." -ForegroundColor Cyan
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

# Step 4: Verify deployment
Write-Host "`n[4/4] Verifying deployment..." -ForegroundColor Cyan

# Wait for components to stabilize
Write-Host "  Waiting 30 seconds for components to stabilize..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Verify nodes
$nodes = kubectl get nodes --no-headers 2>$null
$nodeCount = ($nodes -split "`n").Count
Write-Host "  Nodes: $nodeCount ready" -ForegroundColor Green

# Verify Elasticsearch
$es = kubectl get elasticsearch -n elastic-search -o jsonpath='{.items[0].status.health}' 2>$null
if ($es) {
    Write-Host "  Elasticsearch: $es" -ForegroundColor $(if ($es -eq "green") { "Green" } else { "Yellow" })
}

# Verify Kibana
$kibana = kubectl get kibana -n elastic-search -o jsonpath='{.items[0].status.health}' 2>$null
if ($kibana) {
    Write-Host "  Kibana: $kibana" -ForegroundColor $(if ($kibana -eq "green") { "Green" } else { "Yellow" })
}

# Verify PostgreSQL
$pgPods = kubectl get pods -n postgresql -o jsonpath='{.items[*].status.phase}' 2>$null
if ($pgPods -like "*Running*") {
    Write-Host "  PostgreSQL: Running" -ForegroundColor Green
}

# Verify MinIO
$minioPods = kubectl get pods -n minio -o jsonpath='{.items[*].status.phase}' 2>$null
if ($minioPods -like "*Running*") {
    Write-Host "  MinIO: Running" -ForegroundColor Green
}

# Get external IP
$ip = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

# Summary
Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
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

Write-Host "`n=== Post-Provision Complete ===" -ForegroundColor Green
