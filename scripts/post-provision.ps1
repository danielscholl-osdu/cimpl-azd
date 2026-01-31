#!/usr/bin/env pwsh
# Post-provision orchestrator - Two-phase deployment
#
# This script runs after cluster provisioning (azd provision) and orchestrates:
# - Phase 1: Ensure safeguards are ready (ensure-safeguards.ps1)
# - Phase 2: Deploy platform layer (deploy-platform.ps1)
#
# The two-phase approach eliminates race conditions with eventual consistency
# of Azure Policy/Gatekeeper by making safeguards readiness an explicit gate.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

Write-Host "=== Post-Provision: Two-Phase Deployment ===" -ForegroundColor Cyan
Write-Host "Phase 1: Ensure safeguards readiness" -ForegroundColor Gray
Write-Host "Phase 2: Deploy platform layer" -ForegroundColor Gray
Write-Host ""

# Phase 1: Ensure safeguards are ready
Write-Host "Starting Phase 1..." -ForegroundColor Cyan
& "$scriptDir/ensure-safeguards.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nPhase 1 failed. Safeguards not ready." -ForegroundColor Red
    Write-Host "Please check Azure Policy/Gatekeeper status and retry." -ForegroundColor Yellow
    Write-Host "`nTo retry manually:" -ForegroundColor Gray
    Write-Host "  ./scripts/ensure-safeguards.ps1" -ForegroundColor DarkGray
    Write-Host "  ./scripts/deploy-platform.ps1" -ForegroundColor DarkGray
    exit 1
}

Write-Host ""

# Phase 2: Deploy platform layer
Write-Host "Starting Phase 2..." -ForegroundColor Cyan
& "$scriptDir/deploy-platform.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nPhase 2 failed. Platform deployment incomplete." -ForegroundColor Red
    Write-Host "Safeguards are ready, so you can retry platform deployment:" -ForegroundColor Yellow
    Write-Host "  ./scripts/deploy-platform.ps1" -ForegroundColor DarkGray
    exit 1
}

Write-Host "`n=== Post-Provision Complete ===" -ForegroundColor Green
