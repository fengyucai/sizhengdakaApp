param(
    [string]$FlutterRoot = "C:\flutter"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$dart = Join-Path $FlutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$packageConfig = Join-Path $projectRoot ".dart_tool\package_config.json"

if (-not (Test-Path -LiteralPath $dart)) {
    throw "Dart SDK not found at $dart"
}

if (-not (Test-Path -LiteralPath $packageConfig)) {
    throw "Missing .dart_tool\package_config.json. Run flutter pub get once, then retry."
}

Push-Location $projectRoot
try {
    & $dart analyze
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
