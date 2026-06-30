param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$DbServer = "",
    [int]$DbPort = 1433
)

$ErrorActionPreference = "Stop"

function Test-HttpEndpoint {
    param([string]$Url, [string]$Name)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8
        Write-Host "OK   $Name $($response.StatusCode) $Url"
    } catch {
        Write-Host "FAIL $Name $Url"
        Write-Host "     $($_.Exception.Message)"
    }
}

Test-HttpEndpoint "$BaseUrl/actuator/health" "backend health"
Test-HttpEndpoint "$BaseUrl/v3/api-docs" "openapi"

if ($DbServer) {
    $tcp = Test-NetConnection -ComputerName $DbServer -Port $DbPort -WarningAction SilentlyContinue
    if ($tcp.TcpTestSucceeded) {
        Write-Host "OK   sqlserver tcp $DbServer`:$DbPort"
    } else {
        Write-Host "FAIL sqlserver tcp $DbServer`:$DbPort"
    }
}

Write-Host ""
Write-Host "Troubleshooting:"
Write-Host "- If health is down, check backend/logs/ai-sizheng.log and backend/logs/ai-sizheng-error.log."
Write-Host "- If SQL Server fails, verify DB_URL, DB_USERNAME, DB_PASSWORD and that TCP 1433 is open."
Write-Host "- If API docs fail but health passes, verify SpringDoc dependency and security whitelist."
