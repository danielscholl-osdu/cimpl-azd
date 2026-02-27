#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-deploy: deploy platform software layer.
.DESCRIPTION
    Runs before service deployment (azd deploy) to deploy the platform Helm charts
    (Elasticsearch, PostgreSQL, Redis, MinIO, etc.) onto the AKS cluster via Terraform.

    Prerequisites:
    - Cluster provisioned (azd provision)
    - Safeguards configured (post-provision)
    - Environment variables set: TF_VAR_acme_email, CIMPL_INGRESS_PREFIX
.EXAMPLE
    azd deploy
.EXAMPLE
    azd hooks run predeploy
.EXAMPLE
    ./scripts/pre-deploy.ps1
#>

#Requires -Version 7.4

$ErrorActionPreference = "Stop"

#region Functions

function Get-ClusterContext {
    $resourceGroup = $env:AZURE_RESOURCE_GROUP
    $clusterName = $env:AZURE_AKS_CLUSTER_NAME
    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID

    if ([string]::IsNullOrEmpty($resourceGroup) -or [string]::IsNullOrEmpty($clusterName)) {
        Write-Host "  Getting values from azd environment..." -ForegroundColor Gray
        if ([string]::IsNullOrEmpty($resourceGroup)) { $resourceGroup = azd env get-value AZURE_RESOURCE_GROUP 2>$null }
        if ([string]::IsNullOrEmpty($clusterName)) { $clusterName = azd env get-value AZURE_AKS_CLUSTER_NAME 2>$null }
        if ([string]::IsNullOrEmpty($subscriptionId)) { $subscriptionId = azd env get-value AZURE_SUBSCRIPTION_ID 2>$null }
    }

    if ([string]::IsNullOrEmpty($subscriptionId)) {
        Write-Host "  Subscription ID not provided; falling back to current az account..." -ForegroundColor Gray
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

    return @{
        ResourceGroup  = $resourceGroup
        ClusterName    = $clusterName
        SubscriptionId = $subscriptionId
        SubArgs        = if (-not [string]::IsNullOrEmpty($subscriptionId)) { @("--subscription", $subscriptionId) } else { @() }
    }
}

function Connect-Cluster {
    param([hashtable]$Ctx)

    Write-Host ""
    Write-Host "=================================================================="
    Write-Host "  [1/3] Verifying Cluster Access"
    Write-Host "=================================================================="

    $nodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Kubeconfig not configured, configuring now..." -ForegroundColor Yellow
        az aks get-credentials -g $Ctx.ResourceGroup -n $Ctx.ClusterName @($Ctx.SubArgs) --overwrite-existing
        kubelogin convert-kubeconfig -l azurecli
        $nodes = kubectl get nodes --no-headers 2>$null
    }
    $nodeCount = ($nodes -split "`n" | Where-Object { $_ }).Count
    Write-Host "  Cluster access verified ($nodeCount nodes)" -ForegroundColor Green
}

function Get-PlatformVars {
    param([hashtable]$Ctx)

    $acmeEmail = $env:TF_VAR_acme_email
    if ([string]::IsNullOrEmpty($acmeEmail)) {
        Write-Host "  ERROR: Missing TF_VAR_acme_email" -ForegroundColor Red
        Write-Host "    Set with: azd env set TF_VAR_acme_email 'you@example.com'" -ForegroundColor Gray
        exit 1
    }

    $ingressPrefix = $env:CIMPL_INGRESS_PREFIX

    $useLetsencryptProd = $env:TF_VAR_use_letsencrypt_production
    if ([string]::IsNullOrEmpty($useLetsencryptProd)) { $useLetsencryptProd = "false" }

    $enablePublicIngress = $env:TF_VAR_enable_public_ingress
    if ([string]::IsNullOrEmpty($enablePublicIngress)) { $enablePublicIngress = "true" }

    $dnsZoneName = $env:TF_VAR_dns_zone_name
    $dnsZoneRg = $env:TF_VAR_dns_zone_resource_group
    $dnsZoneSubId = $env:TF_VAR_dns_zone_subscription_id

    # Get UAMI client ID and tenant ID from azd environment
    $externalDnsClientId = azd env get-value EXTERNAL_DNS_CLIENT_ID 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($externalDnsClientId)) {
        $externalDnsClientId = ""
    }
    $tenantId = azd env get-value AZURE_TENANT_ID 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($tenantId)) {
        $tenantId = ""
    }

    # Resolve infra working directory (azd copies infra/ to .azure/<env>/infra/)
    $envName = $env:AZURE_ENV_NAME
    $infraDir = "$PSScriptRoot/../infra"
    if (-not [string]::IsNullOrEmpty($envName)) {
        $azdInfraDir = "$PSScriptRoot/../.azure/$envName/infra"
        if (Test-Path $azdInfraDir) { $infraDir = $azdInfraDir }
    }

    # Determine if DNS zone is fully configured
    $hasDnsZoneConfig = (-not [string]::IsNullOrEmpty($dnsZoneName)) -and
                        (-not [string]::IsNullOrEmpty($dnsZoneRg)) -and
                        (-not [string]::IsNullOrEmpty($dnsZoneSubId))

    # Fix #67: If DNS zone configured but ExternalDNS identity missing, re-apply infra layer
    if ($hasDnsZoneConfig -and [string]::IsNullOrEmpty($externalDnsClientId)) {
        Write-Host "  DNS zone configured but ExternalDNS identity not found — applying infra layer..." -ForegroundColor Yellow
        Push-Location $infraDir
        $env:ARM_SUBSCRIPTION_ID = $Ctx.SubscriptionId
        $infraVarFileArgs = @()
        $infraVarFile = Join-Path $infraDir "main.tfvars.json"
        if (Test-Path $infraVarFile) {
            $infraVarFileArgs = @("-var-file=$infraVarFile")
        }
        terraform apply -auto-approve @infraVarFileArgs
        if ($LASTEXITCODE -eq 0) {
            $externalDnsClientId = terraform output -raw EXTERNAL_DNS_CLIENT_ID 2>$null
            if ($LASTEXITCODE -ne 0) { $externalDnsClientId = "" }
            $tenantId = terraform output -raw AZURE_TENANT_ID 2>$null
            if ($LASTEXITCODE -ne 0) { $tenantId = "" }
            Write-Host "  ExternalDNS identity created" -ForegroundColor Green
        }
        else {
            Write-Host "  WARNING: Infra re-apply failed, ExternalDNS will be disabled" -ForegroundColor Yellow
        }
        Pop-Location
    }

    $hasIdentityConfig = (-not [string]::IsNullOrEmpty($externalDnsClientId)) -and
                         (-not [string]::IsNullOrEmpty($tenantId))
    $enableExternalDns = if ($hasDnsZoneConfig -and $hasIdentityConfig) { "true" } else { "false" }

    Write-Host "  LetsEncrypt issuer: $(if ($useLetsencryptProd -eq 'true') { 'production' } else { 'staging' })" -ForegroundColor Gray
    Write-Host "  ExternalDNS: $(if ($enableExternalDns -eq 'true') { 'enabled' } else { 'disabled' })" -ForegroundColor Gray

    return @{
        AcmeEmail            = $acmeEmail
        IngressPrefix        = $ingressPrefix
        UseLetsencryptProd   = $useLetsencryptProd
        EnablePublicIngress  = $enablePublicIngress
        DnsZoneName          = $dnsZoneName
        DnsZoneRg            = $dnsZoneRg
        DnsZoneSubId         = $dnsZoneSubId
        ExternalDnsClientId  = $externalDnsClientId
        TenantId             = $tenantId
        EnableExternalDns    = $enableExternalDns
    }
}

function Deploy-Platform {
    param([hashtable]$Ctx, [hashtable]$Vars)

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

    Write-Host "  Running terraform apply..." -ForegroundColor Gray
    terraform apply -auto-approve `
        -var="cluster_name=$($Ctx.ClusterName)" `
        -var="resource_group_name=$($Ctx.ResourceGroup)" `
        -var="acme_email=$($Vars.AcmeEmail)" `
        -var="ingress_prefix=$($Vars.IngressPrefix)" `
        -var="enable_public_ingress=$($Vars.EnablePublicIngress)" `
        -var="use_letsencrypt_production=$($Vars.UseLetsencryptProd)" `
        -var="enable_external_dns=$($Vars.EnableExternalDns)" `
        -var="dns_zone_name=$($Vars.DnsZoneName)" `
        -var="dns_zone_resource_group=$($Vars.DnsZoneRg)" `
        -var="dns_zone_subscription_id=$($Vars.DnsZoneSubId)" `
        -var="external_dns_client_id=$($Vars.ExternalDnsClientId)" `
        -var="tenant_id=$($Vars.TenantId)"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Platform deployment failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "  Platform layer deployed" -ForegroundColor Green
    Pop-Location
}

function Test-Deployment {
    param([hashtable]$Vars)

    Write-Host ""
    Write-Host "=================================================================="
    Write-Host "  [3/3] Verifying Deployment"
    Write-Host "=================================================================="

    Write-Host "  Waiting 30 seconds for components to stabilize..." -ForegroundColor Gray
    Start-Sleep -Seconds 30

    $nodes = kubectl get nodes --no-headers 2>$null
    $nodeCount = ($nodes -split "`n" | Where-Object { $_ }).Count
    Write-Host "  Nodes: $nodeCount ready" -ForegroundColor Green

    $es = kubectl get elasticsearch -n elasticsearch -o jsonpath='{.items[0].status.health}' 2>$null
    if ($es) {
        Write-Host "  Elasticsearch: $es" -ForegroundColor $(if ($es -eq "green") { "Green" } else { "Yellow" })
    }
    else { Write-Host "  Elasticsearch: Pending" -ForegroundColor Yellow }

    $kibana = kubectl get kibana -n elasticsearch -o jsonpath='{.items[0].status.health}' 2>$null
    if ($kibana) {
        Write-Host "  Kibana: $kibana" -ForegroundColor $(if ($kibana -eq "green") { "Green" } else { "Yellow" })
    }
    else { Write-Host "  Kibana: Pending" -ForegroundColor Yellow }

    $pgPods = kubectl get pods -n postgresql -o jsonpath='{.items[*].status.phase}' 2>$null
    if ($pgPods -like "*Running*") { Write-Host "  PostgreSQL: Running" -ForegroundColor Green }
    else { Write-Host "  PostgreSQL: Pending" -ForegroundColor Yellow }

    $redisPods = kubectl get pods -n redis -o jsonpath='{.items[*].status.phase}' 2>$null
    if ($redisPods -like "*Running*") { Write-Host "  Redis: Running" -ForegroundColor Green }
    else { Write-Host "  Redis: Pending" -ForegroundColor Yellow }

    $minioPods = kubectl get pods -n platform -l 'minio.service/variant=api' -o jsonpath='{.items[*].status.phase}' 2>$null
    if ($minioPods -like "*Running*") { Write-Host "  MinIO: Running" -ForegroundColor Green }
    else { Write-Host "  MinIO: Pending" -ForegroundColor Yellow }

    # Return external IP for summary
    return kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
}

function Show-Summary {
    param([hashtable]$Ctx, [hashtable]$Vars, [string]$ExternalIp)

    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "  Pre-Deploy Complete: Platform Deployed"                            -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "  Cluster: $($Ctx.ClusterName)"
    Write-Host "  Resource Group: $($Ctx.ResourceGroup)"

    if ($ExternalIp) {
        Write-Host "  External IP: $ExternalIp"
        Write-Host ""

        $kibanaHost = if (-not [string]::IsNullOrEmpty($Vars.IngressPrefix) -and -not [string]::IsNullOrEmpty($Vars.DnsZoneName)) {
            "$($Vars.IngressPrefix)-kibana.$($Vars.DnsZoneName)"
        }
        else { "" }

        Write-Host "  Next steps:" -ForegroundColor Yellow
        if ($Vars.EnableExternalDns -eq "true" -and -not [string]::IsNullOrEmpty($kibanaHost)) {
            Write-Host "    1. DNS A record will be auto-created by ExternalDNS" -ForegroundColor Gray
            Write-Host "    2. Access Kibana: https://$kibanaHost" -ForegroundColor Gray
        }
        elseif (-not [string]::IsNullOrEmpty($kibanaHost)) {
            Write-Host "    1. Create DNS A record: $kibanaHost -> $ExternalIp" -ForegroundColor Gray
            Write-Host "    2. Access Kibana: https://$kibanaHost" -ForegroundColor Gray
        }
        else {
            Write-Host "    1. Configure DNS zone for external access" -ForegroundColor Gray
        }
        Write-Host "    3. Get Elasticsearch password:" -ForegroundColor Gray
        Write-Host "       kubectl get secret elasticsearch-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d" -ForegroundColor DarkGray
    }
    Write-Host ""
}

#endregion

#region Main

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Pre-Deploy: Platform Layer"                                       -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$ctx = Get-ClusterContext
Connect-Cluster -Ctx $ctx
$vars = Get-PlatformVars -Ctx $ctx
Deploy-Platform -Ctx $ctx -Vars $vars
$ip = Test-Deployment -Vars $vars
Show-Summary -Ctx $ctx -Vars $vars -ExternalIp $ip

exit 0

#endregion
