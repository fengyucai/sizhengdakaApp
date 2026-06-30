param(
    [string]$Server = "localhost",
    [string]$Database = "ai_sizheng",
    [string]$BackupDir = ".\backups",
    [string]$Username = "",
    [string]$Password = "",
    [int]$RetentionDays = 14
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw "sqlcmd was not found. Install SQL Server command line tools first."
}

$fullBackupDir = (Resolve-Path -Path (New-Item -ItemType Directory -Force -Path $BackupDir)).Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $fullBackupDir "$Database`_$timestamp.bak"
$query = "BACKUP DATABASE [$Database] TO DISK = N'$backupFile' WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;"

$args = @("-S", $Server, "-b", "-Q", $query)
if ($Username -and $Password) {
    $args += @("-U", $Username, "-P", $Password)
} else {
    $args += @("-E")
}

Write-Host "Backing up [$Database] on [$Server] to [$backupFile]..."
& sqlcmd @args

$cutoff = (Get-Date).AddDays(-[Math]::Abs($RetentionDays))
Get-ChildItem -Path $fullBackupDir -Filter "$Database`_*.bak" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force

Write-Host "Backup completed: $backupFile"
