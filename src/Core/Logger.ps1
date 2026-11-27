# WinSweep Core Logger Module

function Initialize-WinSweepLog {
    param(
        [string]$LogDir,
        [string]$Mode = "CLEANUP",
        [int]$RetentionDays = 30
    )

    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    # Prune old logs according to retention policy
    if ($RetentionDays -gt 0) {
        $cutoff = (Get-Date).AddDays(-$RetentionDays)
        Get-ChildItem -LiteralPath $LogDir -Filter "*.log" -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $startTime = Get-Date
    $stamp = $startTime.ToString('yyyy-MM-dd_HH-mm-ss')
    $prefix = if ($Mode -eq "SCAN") { "Scan" } else { "Cleanup" }
    $logPath = Join-Path $LogDir "${prefix}_${stamp}.log"

    $header = @"
================================================================================
WINSWEEP v4.0 - DETAILED EXECUTION LOG ($Mode)
================================================================================
Date and Time : $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
Computer      : $env:COMPUTERNAME
User          : $env:USERNAME
Log File      : $logPath
Safe Guard    : Browser caches, passwords and histories are strictly excluded.
================================================================================

"@
    [System.IO.File]::WriteAllText($logPath, $header, [System.Text.Encoding]::UTF8)
    return $logPath
}

function Write-WinSweepLog {
    param(
        [string]$Message,
        [string]$Type = "INFO",
        [hashtable]$SyncState = $null,
        [string]$LogPath = $null
    )

    $now = Get-Date
    $stampShort = $now.ToString('HH:mm:ss')
    $stampFull  = $now.ToString('yyyy-MM-dd HH:mm:ss')

    $uiLine   = "[$stampShort] [$Type] $Message"
    $diskLine = "[$stampFull] [$Type] $Message"

    if ($SyncState -and $SyncState.LogQueue) {
        $SyncState.LogQueue.Enqueue([pscustomobject]@{
            Time = $stampShort
            Type = $Type
            Text = $uiLine
            Raw  = $Message
        })
    } elseif ($null -eq $SyncState) {
        # CLI / Headless mode
        $color = switch ($Type) {
            "OK"    { "Green" }
            "DONE"  { "Green" }
            "ERR"   { "Red" }
            "RUN"   { "Cyan" }
            "DRY"   { "Yellow" }
            "WARN"  { "Yellow" }
            "SKIP"  { "DarkGray" }
            default { "Gray" }
        }
        Write-Host $uiLine -ForegroundColor $color
    }

    $targetLog = if ($LogPath) { $LogPath } elseif ($SyncState -and $SyncState.CurrentLogPath) { $SyncState.CurrentLogPath } else { $null }
    if ($targetLog) {
        $lock = if ($SyncState -and $SyncState.LogLock) { $SyncState.LogLock } else { $null }
        if ($lock) { [System.Threading.Monitor]::Enter($lock) }
        try {
            Add-Content -LiteralPath $targetLog -Value $diskLine -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {} finally {
            if ($lock) { [System.Threading.Monitor]::Exit($lock) }
        }
    }
}
