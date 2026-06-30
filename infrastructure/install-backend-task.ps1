param(
    [string]$TaskName = "AI-Sizheng-Backend",
    [int]$Port = 8080,
    [string]$Profile = "dev",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$runner = Join-Path $PSScriptRoot "run-backend-foreground.ps1"
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Missing runner script: $runner"
}

$healthUrl = "http://127.0.0.1:$Port/actuator/health"
$quotedRunner = '"' + $runner + '"'
$quotedRoot = '"' + $ProjectRoot + '"'
$arguments = "-NoProfile -ExecutionPolicy Bypass -File $quotedRunner -ProjectRoot $quotedRoot -Port $Port -Profile $Profile"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments -WorkingDirectory $ProjectRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
    -MultipleInstances IgnoreNew `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Limited

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $TaskName

$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Seconds 3
    try {
        $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3
        if ($health.status -eq "UP") {
            [pscustomobject]@{
                task = $TaskName
                status = "UP"
                url = $healthUrl
            }
            exit 0
        }
    } catch {
        # Keep waiting until timeout.
    }
} while ((Get-Date) -lt $deadline)

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue

[pscustomobject]@{
    task = $TaskName
    status = "NOT_READY"
    state = $task.State
    lastRunTime = $info.LastRunTime
    lastTaskResult = $info.LastTaskResult
    log = Join-Path $ProjectRoot "backend\logs\backend-console.log"
}

exit 1
