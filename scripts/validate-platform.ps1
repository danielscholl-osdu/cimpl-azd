#!/usr/bin/env pwsh
# Phase 1 Platform Validation: Keycloak, RabbitMQ, Airflow

$ErrorActionPreference = "Stop"

function Test-PodsReady {
    param(
        [string]$Namespace,
        [string]$Description,
        [string]$NamePattern = "",
        [string]$LabelSelector = ""
    )

    Write-Host "`nChecking $Description..." -ForegroundColor Cyan

    $kubectlArgs = @("get", "pods", "-n", $Namespace, "-o", "json")
    if (-not [string]::IsNullOrEmpty($LabelSelector)) {
        $kubectlArgs += @("-l", $LabelSelector)
    }

    $podsJson = (kubectl @kubectlArgs 2>$null) -join ''
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: Unable to list pods in namespace '$Namespace'" -ForegroundColor Red
        return $false
    }

    $pods = @((ConvertFrom-Json $podsJson).items)
    if (-not [string]::IsNullOrEmpty($NamePattern)) {
        $pods = @($pods | Where-Object { $_.metadata.name -match $NamePattern })
    }

    if (-not $pods -or $pods.Count -eq 0) {
        Write-Host "  FAIL: No pods found in namespace '$Namespace'" -ForegroundColor Red
        return $false
    }

    $notReady = @($pods | Where-Object {
        $_.status.phase -ne "Running" -or
        -not $_.status.containerStatuses -or
        ($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -gt 0
    })

    if ($notReady.Count -gt 0) {
        Write-Host "  FAIL: $($notReady.Count) pod(s) not ready" -ForegroundColor Red
        return $false
    }

    Write-Host "  OK: $($pods.Count) pod(s) ready" -ForegroundColor Green
    return $true
}

function Test-KeycloakJwks {
    Write-Host "`nChecking Keycloak JWKS endpoint..." -ForegroundColor Cyan

    $jwksPath = "/api/v1/namespaces/keycloak/services/keycloak:http/proxy/realms/osdu/protocol/openid-connect/certs"
    $jwksRaw = (kubectl get --raw $jwksPath 2>$null) -join ''
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: JWKS endpoint not reachable via Kubernetes proxy" -ForegroundColor Red
        return $false
    }

    if (-not ($jwksRaw | Test-Json)) {
        Write-Host "  FAIL: JWKS response is not valid JSON" -ForegroundColor Red
        return $false
    }

    $jwks = $jwksRaw | ConvertFrom-Json

    if (-not $jwks.keys -or $jwks.keys.Count -eq 0) {
        Write-Host "  FAIL: JWKS response missing keys" -ForegroundColor Red
        return $false
    }

    Write-Host "  OK: JWKS endpoint responding" -ForegroundColor Green
    return $true
}

$overallSuccess = $true

if (-not (Test-PodsReady -Namespace "keycloak" -Description "Keycloak pods (keycloak)" -LabelSelector "app.kubernetes.io/instance=keycloak")) {
    $overallSuccess = $false
}

if (-not (Test-KeycloakJwks)) {
    $overallSuccess = $false
}

if (-not (Test-PodsReady -Namespace "rabbitmq" -Description "RabbitMQ pods (rabbitmq)" -LabelSelector "app.kubernetes.io/name=rabbitmq")) {
    $overallSuccess = $false
}

if (-not (Test-PodsReady -Namespace "airflow" -Description "Airflow scheduler pods (airflow)" -NamePattern "^airflow-scheduler")) {
    $overallSuccess = $false
}

if (-not (Test-PodsReady -Namespace "airflow" -Description "Airflow webserver pods (airflow)" -NamePattern "^airflow-webserver")) {
    $overallSuccess = $false
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })
Write-Host "  Platform Validation: $(if ($overallSuccess) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })
Write-Host "==================================================================" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })
Write-Host ""

if (-not $overallSuccess) {
    exit 1
}

exit 0
