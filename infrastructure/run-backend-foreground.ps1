param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$Port = 8080,
    [string]$Profile = "dev",
    [int]$RestartDelaySeconds = 15
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            return
        }

        $parts = $line.Split("=", 2)
        if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0])) {
            return
        }

        [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }
}

$backendRoot = Join-Path $ProjectRoot "backend"
$jarPath = Join-Path $backendRoot "target\aisizheng-1.0.0-SNAPSHOT.jar"
$logsRoot = Join-Path $backendRoot "logs"
$consoleLog = Join-Path $logsRoot "backend-console.log"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

Import-DotEnv (Join-Path $ProjectRoot ".env.tencent.local")
Import-DotEnv (Join-Path $ProjectRoot ".env.cloud.local")

$java = $env:JAVA_EXE
if ([string]::IsNullOrWhiteSpace($java)) {
    $java = (Get-Command java -ErrorAction Stop).Source
}

Set-Location $backendRoot

while ($true) {
    "[$(Get-Date -Format o)] Starting backend on port $Port, profile $Profile" | Out-File -FilePath $consoleLog -Encoding UTF8 -Append

    if (Test-Path -LiteralPath $jarPath) {
        & $java "-Dfile.encoding=UTF-8" -jar $jarPath "--server.port=$Port" "--spring.profiles.active=$Profile" *>> $consoleLog
        $exitCode = $LASTEXITCODE
    } else {
        $maven = $env:MAVEN_CMD
        if ([string]::IsNullOrWhiteSpace($maven)) {
            $maven = (Get-Command mvn.cmd -ErrorAction Stop).Source
        }

        & $maven spring-boot:run "-Dspring-boot.run.arguments=--server.port=$Port --spring.profiles.active=$Profile" *>> $consoleLog
        $exitCode = $LASTEXITCODE
    }

    "[$(Get-Date -Format o)] Backend exited with code $exitCode. Restarting in $RestartDelaySeconds seconds." | Out-File -FilePath $consoleLog -Encoding UTF8 -Append
    Start-Sleep -Seconds $RestartDelaySeconds
}
