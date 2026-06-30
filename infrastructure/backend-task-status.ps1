param(
    [string]$TaskName = "AI-Sizheng-Backend",
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

$healthUrl = "http://127.0.0.1:$Port/actuator/health"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
$healthStatus = "DOWN"

try {
    $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3
    $healthStatus = $health.status
} catch {
    $healthStatus = "DOWN"
}

[pscustomobject]@{
    task = $TaskName
    taskState = if ($task) { $task.State } else { "NOT_INSTALLED" }
    lastRunTime = if ($info) { $info.LastRunTime } else { $null }
    lastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
    health = $healthStatus
    url = $healthUrl
}
