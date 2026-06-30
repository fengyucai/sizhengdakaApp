param(
    [string]$ApiBaseUrl = "http://127.0.0.1:8080",
    [string]$AmapAndroidKey = "",
    [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = "C:\flutter\bin\flutter.bat"
$gradle = Join-Path $projectRoot "android\gradlew.bat"
$localPropertiesPath = Join-Path $projectRoot "android\local.properties"
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"

if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter not found at $flutter"
}

if (-not (Test-Path -LiteralPath $gradle)) {
    throw "Gradle wrapper not found at $gradle"
}

if ([string]::IsNullOrWhiteSpace($AmapAndroidKey)) {
    $AmapAndroidKey = $env:AMAP_ANDROID_KEY
}

if ([string]::IsNullOrWhiteSpace($AmapAndroidKey) -and (Test-Path -LiteralPath $localPropertiesPath)) {
    $line = Get-Content -LiteralPath $localPropertiesPath |
        Where-Object { $_ -match "^AMAP_ANDROID_KEY=" } |
        Select-Object -First 1
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $AmapAndroidKey = $parts[1].Trim()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($AmapAndroidKey)) {
    throw "AMap Android key is required. Pass -AmapAndroidKey, set AMAP_ANDROID_KEY env var, or set AMAP_ANDROID_KEY in android/local.properties."
}

Push-Location $projectRoot
try {
    if (Test-Path -LiteralPath $keyPropertiesPath) {
        Write-Host "Release signing: android/key.properties"
    }
    else {
        Write-Host "Release signing: debug fallback. Run .\tool\create-release-keystore.ps1 before formal pilot packaging."
    }

    if (-not $SkipPubGet) {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    $defines = @(
        "API_BASE_URL=$ApiBaseUrl",
        "AMAP_ANDROID_KEY=$AmapAndroidKey"
    ) | ForEach-Object {
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
    }
    $dartDefinesArg = "-Pdart-defines=" + ($defines -join ",")

    & $gradle :app:assembleRelease `
        $dartDefinesArg `
        "-PAMAP_ANDROID_KEY=$AmapAndroidKey" `
        --console=plain `
        --no-daemon

    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $apk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "Release APK: $apk"
}
finally {
    Pop-Location
}
