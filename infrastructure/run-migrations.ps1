param(
    [string]$Server = "localhost",
    [string]$Database = "ai_sizheng",
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrationDir = Join-Path $root "migrations"

if (-not (Test-Path -LiteralPath $migrationDir)) {
    throw "Migration directory not found: $migrationDir"
}

$files = Get-ChildItem -LiteralPath $migrationDir -Filter "*.sql" | Sort-Object Name
if ($files.Count -eq 0) {
    Write-Host "No migration files found."
    exit 0
}

function Invoke-Sql {
    param([string]$Query, [string]$InputFile)

    $args = @("-S", $Server, "-d", $Database, "-b")
    if ([string]::IsNullOrWhiteSpace($Username)) {
        $args += "-E"
    }
    else {
        $args += @("-U", $Username, "-P", $Password)
    }
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $args += @("-Q", $Query)
    }
    if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
        $args += @("-i", $InputFile)
    }
    & sqlcmd @args
}

Invoke-Sql -Query @"
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='schema_migration' AND xtype='U')
CREATE TABLE schema_migration (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    script_name NVARCHAR(200) NOT NULL UNIQUE,
    applied_at DATETIME2 DEFAULT GETDATE()
);
"@

foreach ($file in $files) {
    $escapedName = $file.Name.Replace("'", "''")
    $alreadyApplied = (Invoke-Sql -Query "SET NOCOUNT ON; SELECT COUNT(1) FROM schema_migration WHERE script_name = N'$escapedName';" |
        Where-Object { $_ -match "^\s*\d+\s*$" } |
        Select-Object -First 1).Trim()
    if ($alreadyApplied -eq "1") {
        Write-Host "Skipping migration: $($file.Name)"
        continue
    }

    Write-Host "Applying migration: $($file.Name)"
    Invoke-Sql -InputFile $file.FullName
    Invoke-Sql -Query "INSERT INTO schema_migration(script_name) VALUES (N'$escapedName');"
}

Write-Host "All migrations applied."
