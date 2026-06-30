param(
    [string]$Server = "localhost",
    [string]$Database = "ai_sizheng",
    [string]$ExportDir = ".\trial-export",
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw "sqlcmd was not found. Install SQL Server command line tools first."
}

$fullExportDir = (Resolve-Path -Path (New-Item -ItemType Directory -Force -Path $ExportDir)).Path
$tables = @(
    "sys_user",
    "checkin_site",
    "class_session",
    "checkin_record",
    "leave_request",
    "intern_log",
    "notification",
    "audit_log"
)

$baseArgs = @("-S", $Server, "-d", $Database, "-b", "-s", ",", "-W", "-w", "65535")
if ($Username -and $Password) {
    $baseArgs += @("-U", $Username, "-P", $Password)
} else {
    $baseArgs += @("-E")
}

foreach ($table in $tables) {
    $file = Join-Path $fullExportDir "$table.csv"
    Write-Host "Exporting $table -> $file"
    & sqlcmd @baseArgs -Q "SET NOCOUNT ON; SELECT * FROM [$table];" -o $file
}

Write-Host "Trial data export completed: $fullExportDir"
