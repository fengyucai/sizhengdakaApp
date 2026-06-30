param(
    [string]$FlutterRoot = "C:\flutter",
    [switch]$NoPub
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $FlutterRoot "bin\flutter.bat"
$cacheDir = Join-Path $FlutterRoot "bin\cache"
$lockPaths = @(
    (Join-Path $cacheDir "lockfile"),
    (Join-Path $cacheDir "flutter.bat.lock")
)

if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter command not found at $flutter"
}

foreach ($lockPath in $lockPaths) {
    if (-not (Test-Path -LiteralPath $lockPath)) {
        continue
    }
    $item = Get-Item -LiteralPath $lockPath -Force
    if ($item.Length -eq 0 -and $item.LastWriteTime -lt (Get-Date).AddMinutes(-2)) {
        Remove-Item -LiteralPath $lockPath -Force
    }
}

Push-Location $projectRoot
try {
    if ($NoPub) {
        & $flutter analyze --no-pub
    }
    else {
        & $flutter analyze
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
