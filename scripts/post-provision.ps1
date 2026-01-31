#!/usr/bin/env pwsh
# Post-provision verification script

$ErrorActionPreference = "Continue"

Write-Host "=== Post-Provision Verification ===" -ForegroundColor Cyan

# Get resource group and cluster name from terraform outputs
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

# Configure AKS Automatic safeguards for Helm chart compatibility
Write-Host "`nConfiguring deployment safeguards..." -ForegroundColor Cyan
Write-Host "  Setting safeguards-level to Warning and excluding namespaces..." -ForegroundColor Gray

$excludedNs = "elastic-system,elastic-search,cert-manager,aks-istio-ingress,postgresql,minio"
$safeguardsResult = az aks update -g $resourceGroup -n $clusterName `
    --safeguards-level Warning `
    --safeguards-excluded-ns $excludedNs `
    --only-show-errors 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Safeguards configured: Warning mode" -ForegroundColor Green
    Write-Host "  Excluded namespaces: $excludedNs" -ForegroundColor Gray
}
else {
    Write-Host "  Safeguards configuration failed (may need aks-preview extension)" -ForegroundColor Yellow
    Write-Host "  Install with: az extension add --name aks-preview" -ForegroundColor Gray
}

# Update Azure Policy assignment to add excluded namespaces for constraints
Write-Host "`nUpdating policy assignment excluded namespaces..." -ForegroundColor Gray
$scope = "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$resourceGroup/providers/Microsoft.ContainerService/managedClusters/$clusterName"
$currentExcluded = @(
    "aks-command", "kube-system", "calico-system", "azuresecuritylinuxagent",
    "tigera-system", "gatekeeper-system", "azappconfig-system", "azureml",
    "dapr-system", "dataprotection-microsoft", "flux-system", "acstor",
    "sc-system", "azure-extensions-usage-system", "app-routing-system",
    "aks-periscope", "aks-istio-system", "aks-istio-ingress", "aks-istio-egress",
    "elastic-search", "elastic-system", "cert-manager", "postgresql", "minio"
)
$excludedJson = $currentExcluded | ConvertTo-Json -Compress

az policy assignment update `
    --name "aks-deployment-safeguards-policy-assignment" `
    --scope $scope `
    --set "parameters.excludedNamespaces.value=$excludedJson" `
    --only-show-errors 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Policy assignment updated with excluded namespaces" -ForegroundColor Green
}
else {
    Write-Host "  Policy update skipped (assignment may not exist yet)" -ForegroundColor Gray
}

# Get kubeconfig
Write-Host "`nGetting kubeconfig..." -ForegroundColor Cyan
az aks get-credentials -g $resourceGroup -n $clusterName --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Verify cluster connectivity
Write-Host "`nVerifying cluster connectivity..." -ForegroundColor Cyan
$nodes = kubectl get nodes -o json 2>$null | ConvertFrom-Json
if ($nodes) {
    Write-Host "  Nodes: $($nodes.items.Count)" -ForegroundColor Green
    foreach ($node in $nodes.items) {
        $ready = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
        $pool = $node.metadata.labels.'agentpool'
        Write-Host "    $($node.metadata.name) [$pool]: $ready" -ForegroundColor Gray
    }
}
else {
    Write-Host "  Could not connect to cluster" -ForegroundColor Red
}

# Verify Istio ingress
Write-Host "`nVerifying Istio ingress (aks-istio-ingress)..." -ForegroundColor Cyan
$istioPods = kubectl get pods -n aks-istio-ingress -o json 2>$null | ConvertFrom-Json
if ($istioPods -and $istioPods.items.Count -gt 0) {
    Write-Host "  Istio ingress pods:" -ForegroundColor Green
    foreach ($pod in $istioPods.items) {
        $phase = $pod.status.phase
        Write-Host "    $($pod.metadata.name): $phase" -ForegroundColor Gray
    }
}
else {
    Write-Host "  Istio ingress not found (may still be initializing)" -ForegroundColor Yellow
}

# Get external IP
Write-Host "`nGetting external ingress IP..." -ForegroundColor Cyan
$svc = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o json 2>$null | ConvertFrom-Json
$ip = $null
if ($svc -and $svc.status.loadBalancer.ingress) {
    $ip = $svc.status.loadBalancer.ingress[0].ip
    Write-Host "  External IP: $ip" -ForegroundColor Green
}
else {
    Write-Host "  External IP not yet assigned" -ForegroundColor Yellow
}

# Verify Gateway API CRDs
Write-Host "`nVerifying Gateway API CRDs..." -ForegroundColor Cyan
$gatewayCrds = kubectl get crd gateways.gateway.networking.k8s.io 2>$null
if ($gatewayCrds) {
    Write-Host "  Gateway API CRDs installed" -ForegroundColor Green
}
else {
    Write-Host "  Gateway API CRDs not found" -ForegroundColor Yellow
}

# Verify Gateway
Write-Host "`nVerifying Gateway resource..." -ForegroundColor Cyan
$gateway = kubectl get gateway -n aks-istio-ingress istio -o json 2>$null | ConvertFrom-Json
if ($gateway) {
    Write-Host "  Gateway: $($gateway.metadata.name)" -ForegroundColor Green
    $conditions = $gateway.status.conditions
    if ($conditions) {
        foreach ($cond in $conditions) {
            Write-Host "    $($cond.type): $($cond.status)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "  Gateway not found (may still be creating)" -ForegroundColor Yellow
}

# Verify cert-manager
Write-Host "`nVerifying cert-manager..." -ForegroundColor Cyan
$certManagerPods = kubectl get pods -n cert-manager -o json 2>$null | ConvertFrom-Json
if ($certManagerPods -and $certManagerPods.items.Count -gt 0) {
    $running = ($certManagerPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
    Write-Host "  cert-manager pods running: $running/$($certManagerPods.items.Count)" -ForegroundColor Green
}
else {
    Write-Host "  cert-manager not found" -ForegroundColor Yellow
}

# Verify ClusterIssuer
Write-Host "`nVerifying ClusterIssuer..." -ForegroundColor Cyan
$issuer = kubectl get clusterissuer letsencrypt-prod -o json 2>$null | ConvertFrom-Json
if ($issuer) {
    $ready = ($issuer.status.conditions | Where-Object { $_.type -eq "Ready" }).status
    Write-Host "  ClusterIssuer letsencrypt-prod: $ready" -ForegroundColor Green
}
else {
    Write-Host "  ClusterIssuer not found (may still be creating)" -ForegroundColor Yellow
}

# Verify ECK operator
Write-Host "`nVerifying ECK operator..." -ForegroundColor Cyan
$eckPods = kubectl get pods -n elastic-system -o json 2>$null | ConvertFrom-Json
if ($eckPods -and $eckPods.items.Count -gt 0) {
    $running = ($eckPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
    Write-Host "  ECK operator pods running: $running/$($eckPods.items.Count)" -ForegroundColor Green
}
else {
    Write-Host "  ECK operator not found" -ForegroundColor Yellow
}

# Verify Elasticsearch
Write-Host "`nVerifying Elasticsearch..." -ForegroundColor Cyan
$es = kubectl get elasticsearch -n elastic-search -o json 2>$null | ConvertFrom-Json
if ($es -and $es.items.Count -gt 0) {
    $esCluster = $es.items[0]
    Write-Host "  Elasticsearch: $($esCluster.metadata.name)" -ForegroundColor Green
    Write-Host "    Phase: $($esCluster.status.phase)" -ForegroundColor Gray
    Write-Host "    Health: $($esCluster.status.health)" -ForegroundColor Gray
    Write-Host "    Nodes: $($esCluster.status.availableNodes)/$($esCluster.spec.nodeSets[0].count)" -ForegroundColor Gray
}
else {
    Write-Host "  Elasticsearch not found (may still be initializing)" -ForegroundColor Yellow
}

# Verify Kibana
Write-Host "`nVerifying Kibana..." -ForegroundColor Cyan
$kibana = kubectl get kibana -n elastic-search -o json 2>$null | ConvertFrom-Json
if ($kibana -and $kibana.items.Count -gt 0) {
    $kb = $kibana.items[0]
    Write-Host "  Kibana: $($kb.metadata.name)" -ForegroundColor Green
    Write-Host "    Health: $($kb.status.health)" -ForegroundColor Gray
    Write-Host "    Available: $($kb.status.availableNodes)/$($kb.spec.count)" -ForegroundColor Gray
}
else {
    Write-Host "  Kibana not found (may still be initializing)" -ForegroundColor Yellow
}

# Verify PostgreSQL
Write-Host "`nVerifying PostgreSQL..." -ForegroundColor Cyan
$pgPods = kubectl get pods -n postgresql -o json 2>$null | ConvertFrom-Json
if ($pgPods -and $pgPods.items.Count -gt 0) {
    $running = ($pgPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
    Write-Host "  PostgreSQL pods running: $running/$($pgPods.items.Count)" -ForegroundColor Green
    foreach ($pod in $pgPods.items) {
        $phase = $pod.status.phase
        Write-Host "    $($pod.metadata.name): $phase" -ForegroundColor Gray
    }
    # Test PostgreSQL readiness
    $pgReady = kubectl exec -n postgresql postgresql-0 -- pg_isready 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PostgreSQL is ready and accepting connections" -ForegroundColor Green
    }
    else {
        Write-Host "  PostgreSQL not yet ready" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  PostgreSQL not found (may still be initializing)" -ForegroundColor Yellow
}

# Verify MinIO
Write-Host "`nVerifying MinIO..." -ForegroundColor Cyan
$minioPods = kubectl get pods -n minio -o json 2>$null | ConvertFrom-Json
if ($minioPods -and $minioPods.items.Count -gt 0) {
    $running = ($minioPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
    Write-Host "  MinIO pods running: $running/$($minioPods.items.Count)" -ForegroundColor Green
    foreach ($pod in $minioPods.items) {
        $phase = $pod.status.phase
        Write-Host "    $($pod.metadata.name): $phase" -ForegroundColor Gray
    }
    Write-Host "  MinIO console accessible via: kubectl port-forward svc/minio 9001:9001 -n minio" -ForegroundColor Gray
}
else {
    Write-Host "  MinIO not found (may still be initializing)" -ForegroundColor Yellow
}

# Verify TLS Certificate
Write-Host "`nVerifying TLS Certificate..." -ForegroundColor Cyan
$cert = kubectl get certificate -n aks-istio-ingress kibana-tls -o json 2>$null | ConvertFrom-Json
if ($cert) {
    $ready = ($cert.status.conditions | Where-Object { $_.type -eq "Ready" }).status
    Write-Host "  Certificate kibana-tls: $ready" -ForegroundColor Green
    if ($cert.status.notAfter) {
        Write-Host "    Expires: $($cert.status.notAfter)" -ForegroundColor Gray
    }
}
else {
    Write-Host "  Certificate not found (may still be issuing)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Post-Provision Summary ===" -ForegroundColor Cyan
Write-Host "Cluster: $clusterName" -ForegroundColor White
Write-Host "Resource Group: $resourceGroup" -ForegroundColor White

if ($ip) {
    Write-Host "External IP: $ip" -ForegroundColor White

    # Get Kibana URL from terraform output
    Push-Location $PSScriptRoot/../infra
    $kibanaUrl = terraform output -raw KIBANA_URL 2>$null
    Pop-Location

    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Create DNS A record for your kibana hostname pointing to: $ip" -ForegroundColor Gray
    Write-Host "  2. Wait for certificate to be issued:" -ForegroundColor Gray
    Write-Host "     kubectl get certificate -n aks-istio-ingress -w" -ForegroundColor DarkGray
    Write-Host "  3. Get Elasticsearch password:" -ForegroundColor Gray
    Write-Host "     kubectl get secret elasticsearch-es-elastic-user -n elastic-search -o jsonpath='{.data.elastic}' | base64 -d" -ForegroundColor DarkGray
    Write-Host "  4. Access Kibana at: $kibanaUrl" -ForegroundColor Gray
    Write-Host "     Username: elastic" -ForegroundColor DarkGray
}

Write-Host "`n=== Post-Provision Complete ===" -ForegroundColor Green
