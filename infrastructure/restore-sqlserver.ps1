param(
    [string]$Server = "localhost",
    [string]$Database = "ai_sizheng",
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    [string]$Username = "",
    [string]$Password = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw "sqlcmd was not found. Install SQL Server command line tools first."
}

$fullBackupFile = (Resolve-Path -Path $BackupFile).Path
$prefix = if ($Username -and $Password) { @("-S", $Server, "-U", $Username, "-P", $Password, "-b") } else { @("-S", $Server, "-E", "-b") }

if (-not $Force) {
    Write-Host "Dry run only. Re-run with -Force to restore [$Database] from [$fullBackupFile]."
    exit 0
}

$query = @"
IF DB_ID(N'$Database') IS NOT NULL
BEGIN
    ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
RESTORE DATABASE [$Database] FROM DISK = N'$fullBackupFile' WITH REPLACE, RECOVERY, STATS = 10;
ALTER DATABASE [$Database] SET MULTI_USER;
"@

Write-Host "Restoring [$Database] on [$Server] from [$fullBackupFile]..."
& sqlcmd @prefix -Q $query
Write-Host "Restore completed."
