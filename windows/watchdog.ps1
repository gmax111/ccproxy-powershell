<#
.SYNOPSIS
    CCProxy Watchdog - Auto-restarts ccproxy on crash

.DESCRIPTION
    Monitors ccproxy health by checking port 4000 availability.
    Automatically restarts ccproxy if it becomes unresponsive.
    Designed to handle the Windows asyncio bug (CPython #93821)
    that crashes ccproxy when requests are interrupted.

.NOTES
    Author: AliraOS
    Version: 1.0.0
    Platform: Windows PowerShell 7+
#>

param(
    [int]$CheckInterval = 5,      # Seconds between health checks
    [int]$MaxRestarts = 10,       # Max restarts before giving up
    [int]$RestartCooldown = 30,   # Seconds to wait after restart before checking
    [switch]$Verbose
)

$script:ConfigDir = "$env:USERPROFILE\.ccproxy"
$script:Port = 4000
$script:RestartCount = 0
$script:LastRestartTime = $null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
        "OK"    { Write-Host $logLine -ForegroundColor Green }
        default { Write-Host $logLine -ForegroundColor Gray }
    }

    # Append to log file
    $logFile = Join-Path $script:ConfigDir "watchdog.log"
    Add-Content -Path $logFile -Value $logLine -ErrorAction SilentlyContinue
}

function Test-CCProxyHealth {
    try {
        # Check if port 4000 is listening
        $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port $script:Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

        if ($connection.TcpTestSucceeded) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-CCProxyProcess {
    # Check if ccproxy process is running
    $process = Get-Process -Name "python*" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*ccproxy*" -or $_.CommandLine -like "*litellm*"
    }
    return $null -ne $process
}

function Restart-CCProxy {
    Write-Log "Attempting to restart ccproxy..." "WARN"

    # Stop any existing ccproxy
    try {
        ccproxy --config-dir $script:ConfigDir stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Log "Stop command failed (may already be stopped): $_" "WARN"
    }

    # Kill any orphaned processes on port 4000
    try {
        $portProcess = Get-NetTCPConnection -LocalPort $script:Port -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique
        if ($portProcess) {
            foreach ($pid in $portProcess) {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Write-Log "Killed orphaned process on port $($script:Port): PID $pid" "WARN"
            }
            Start-Sleep -Seconds 2
        }
    }
    catch {
        # Port might not be in use
    }

    # Start ccproxy
    try {
        $env:PYTHONIOENCODING = 'utf-8'
        ccproxy --config-dir $script:ConfigDir start --detach 2>&1 | Out-Null

        $script:RestartCount++
        $script:LastRestartTime = Get-Date

        Write-Log "CCProxy restart initiated (attempt $($script:RestartCount)/$MaxRestarts)" "INFO"

        # Wait for startup
        Start-Sleep -Seconds $RestartCooldown

        # Verify it started
        if (Test-CCProxyHealth) {
            Write-Log "CCProxy restarted successfully and is healthy" "OK"
            return $true
        }
        else {
            Write-Log "CCProxy started but health check failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to restart ccproxy: $_" "ERROR"
        return $false
    }
}

function Start-Watchdog {
    Write-Log "CCProxy Watchdog starting..." "INFO"
    Write-Log "Config: CheckInterval=${CheckInterval}s, MaxRestarts=$MaxRestarts, Port=$($script:Port)" "INFO"

    # Initial health check
    if (-not (Test-CCProxyHealth)) {
        Write-Log "CCProxy not healthy on startup, attempting restart..." "WARN"
        if (-not (Restart-CCProxy)) {
            Write-Log "Initial startup failed" "ERROR"
        }
    }
    else {
        Write-Log "CCProxy is healthy" "OK"
    }

    # Main monitoring loop
    while ($true) {
        Start-Sleep -Seconds $CheckInterval

        if (-not (Test-CCProxyHealth)) {
            Write-Log "CCProxy health check FAILED" "ERROR"

            # Check restart limits
            if ($script:RestartCount -ge $MaxRestarts) {
                # Reset counter if enough time has passed (1 hour)
                if ($script:LastRestartTime -and ((Get-Date) - $script:LastRestartTime).TotalHours -ge 1) {
                    Write-Log "Restart counter reset after 1 hour cooldown" "INFO"
                    $script:RestartCount = 0
                }
                else {
                    Write-Log "Max restart attempts reached ($MaxRestarts). Watchdog pausing for 5 minutes..." "ERROR"
                    Start-Sleep -Seconds 300
                    $script:RestartCount = 0  # Reset and try again
                    continue
                }
            }

            # Attempt restart
            Restart-CCProxy
        }
        elseif ($Verbose) {
            Write-Log "CCProxy healthy" "OK"
        }
    }
}

# Run the watchdog
Start-Watchdog
