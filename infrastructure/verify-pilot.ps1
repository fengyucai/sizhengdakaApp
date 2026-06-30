param(
    [string]$BaseUrl = "http://localhost:8080",
    [switch]$SkipBackendTests,
    [switch]$SkipFlutterAnalyze,
    [switch]$SkipWebBuild
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "== AI Sizheng pilot verification =="
Write-Host "Project: $root"

Write-Host ""
Write-Host "== Health check =="
& (Join-Path $PSScriptRoot "check-health.ps1") -BaseUrl $BaseUrl

if (-not $SkipBackendTests) {
    Write-Host ""
    Write-Host "== Backend tests =="
    Push-Location (Join-Path $root "backend")
    try {
        & mvn.cmd test
    } finally {
        Pop-Location
    }
}

if (-not $SkipFlutterAnalyze) {
    Write-Host ""
    Write-Host "== Flutter analyze =="
    $flutter = "C:\flutter\bin\flutter.bat"
    if (-not (Test-Path $flutter)) {
        throw "Flutter SDK not found at $flutter"
    }
    Push-Location (Join-Path $root "mobile")
    try {
        & $flutter analyze --no-pub
    } finally {
        Pop-Location
    }
}

if (-not $SkipWebBuild) {
    Write-Host ""
    Write-Host "== Admin web build =="
    Push-Location (Join-Path $root "admin-web")
    try {
        & npm.cmd run build
    } finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "== Dashboard build =="
    Push-Location (Join-Path $root "dashboard")
    try {
        & npm.cmd run build
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Pilot verification completed."
