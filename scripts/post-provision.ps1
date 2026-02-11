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

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Post-Provision: Two-Phase Deployment"                             -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Phase 1: Ensure safeguards readiness" -ForegroundColor Gray
Write-Host "  Phase 2: Deploy platform layer" -ForegroundColor Gray

#region Phase 1
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Starting Phase 1: Ensure Safeguards Readiness"
Write-Host "=================================================================="

& "$scriptDir/ensure-safeguards.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Phase 1 FAILED: Safeguards not ready"                             -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Check Azure Policy/Gatekeeper status and retry." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To retry manually:" -ForegroundColor Gray
    Write-Host "    ./scripts/ensure-safeguards.ps1" -ForegroundColor DarkGray
    Write-Host "    ./scripts/deploy-platform.ps1" -ForegroundColor DarkGray
    exit 1
}
#endregion

#region Phase 2
Write-Host ""
Write-Host "=================================================================="
Write-Host "  Starting Phase 2: Deploy Platform Layer"
Write-Host "=================================================================="

& "$scriptDir/deploy-platform.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Phase 2 FAILED: Platform deployment incomplete"                   -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Safeguards are ready, so you can retry platform deployment:" -ForegroundColor Yellow
    Write-Host "    ./scripts/deploy-platform.ps1" -ForegroundColor DarkGray
    exit 1
}
#endregion

#region Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Post-Provision Complete"                                          -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
exit 0
#endregion
