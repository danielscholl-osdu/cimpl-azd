#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-deploy: deploy platform software layer.
.DESCRIPTION
    Runs before service deployment (azd deploy) to deploy the platform Helm charts
    (PostgreSQL, Redis, Keycloak, etc.) onto the AKS cluster via Terraform.
.EXAMPLE
    azd deploy
.EXAMPLE
    azd hooks run predeploy
#>

#Requires -Version 7.4

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Pre-Deploy: Platform Layer"                                       -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

& "$scriptDir/deploy-platform.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  FAILED: Platform deployment incomplete"                           -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  To retry: azd deploy" -ForegroundColor Yellow
    Write-Host "  Or directly: ./scripts/deploy-platform.ps1" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Pre-Deploy Complete — platform layer deployed"                    -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
exit 0
