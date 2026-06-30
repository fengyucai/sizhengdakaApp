param(
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [string]$Database = "ai_sizheng",
    [Parameter(Mandatory = $true)]
    [string]$Username,
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [switch]$Seed
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$initScript = Join-Path $root "init_db.sql"
$seedScript = Join-Path $root "seed_data.sql"

if (-not (Test-Path -LiteralPath $initScript)) {
    throw "Init script not found: $initScript"
}

function Invoke-CloudSql {
    param(
        [string]$TargetDatabase,
        [string]$Query,
        [string]$InputFile
    )

    $args = @("-S", $Server, "-U", $Username, "-P", $Password, "-d", $TargetDatabase, "-b")
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $args += @("-Q", $Query)
    }
    if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
        $args += @("-i", $InputFile)
    }
    & sqlcmd @args
}

Write-Host "Ensuring database exists: $Database"
Invoke-CloudSql -TargetDatabase "master" -Query @"
IF DB_ID(N'$Database') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [$Database]');
END
"@

Write-Host "Applying base schema..."
Invoke-CloudSql -TargetDatabase $Database -InputFile $initScript

Write-Host "Applying migrations..."
& (Join-Path $root "run-migrations.ps1") -Server $Server -Database $Database -Username $Username -Password $Password
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Seed) {
    if (-not (Test-Path -LiteralPath $seedScript)) {
        throw "Seed script not found: $seedScript"
    }
    Write-Host "Applying seed data. This may delete existing demo rows."
    Invoke-CloudSql -TargetDatabase $Database -InputFile $seedScript
}

Write-Host "Cloud database is ready."
