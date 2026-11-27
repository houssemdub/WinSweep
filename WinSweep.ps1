<#
.SYNOPSIS
    WinSweep v4.0 - Interactive & CLI Windows System, GPU, AI & Privacy Cleaner
.DESCRIPTION
    Modular WPF + PowerShell cleanup suite with Dry Run scanning, async execution,
    GPU/3D shader caches, AI runtime & conversation cleanup, LLM model/blob inspector,
    custom exclusions, age filtering, and headless CLI automation.
    Browser data is NEVER touched.
.NOTES
    Must be run as Administrator (STA mode for GUI).
    Version: 4.0
#>

[CmdletBinding()]
param(
    [switch]$NoGui,
    [ValidateSet("Recommended", "All", "Security", "System", "Caches", "Graphics", "Apps", "AI", "Privacy")]
    [string]$Preset = "Recommended",
    [switch]$DryRun,
    [switch]$Silent,
    [int]$OlderThanDays = -1
)

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'

# -- 1. Admin Verification & Auto-Elevation ------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    if ($NoGui -and $Silent) {
        Write-Error "WinSweep requires Administrator privileges."
        exit 1
    }
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
    if ($NoGui)         { $argList += " -NoGui -Preset $Preset" }
    if ($DryRun)        { $argList += " -DryRun" }
    if ($Silent)        { $argList += " -Silent" }
    if ($OlderThanDays -ge 0) { $argList += " -OlderThanDays $OlderThanDays" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    exit
}

# -- 2. Load Core Modules & Task Registry --------------------------------------
$script:RootDir = $PSScriptRoot
$script:LogDir  = Join-Path $script:RootDir "Logs"

. (Join-Path $script:RootDir "src\Core\Config.ps1")
. (Join-Path $script:RootDir "src\Core\Logger.ps1")
. (Join-Path $script:RootDir "src\Core\Cleaner.ps1")
. (Join-Path $script:RootDir "src\Core\ModelScanner.ps1")
. (Join-Path $script:RootDir "src\Tasks\TaskRegistry.ps1")

$config = Load-WinSweepConfig -RootDir $script:RootDir
if ($OlderThanDays -ge 0) {
    $config.OlderThanDays = $OlderThanDays
}
$tasks = Get-WinSweepTasks

# -- 3. Headless CLI Mode (-NoGui) ---------------------------------------------
if ($NoGui) {
    $mode = if ($DryRun) { "SCAN" } else { "CLEANUP" }
    $logPath = Initialize-WinSweepLog -LogDir $script:LogDir -Mode $mode -RetentionDays $config.LogRetentionDays

    $selectedKeys = switch ($Preset) {
        "All"         { @($tasks.Keys) }
        "Security"    { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "Security" }) }
        "System"      { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "System" }) }
        "Caches"      { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "Caches" }) }
        "Graphics"    { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "Graphics" }) }
        "Apps"        { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "Apps" }) }
        "AI"          { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "AI" }) }
        "Privacy"     { @($tasks.Keys | Where-Object { $tasks[$_].Category -eq "AI" -or $_ -eq "chkThumbIcons" }) }
        default       { @($tasks.Keys | Where-Object { $tasks[$_].Default }) }
    }

    $ctx = @{
        SyncState          = $null
        DryRun             = [bool]$DryRun
        OlderThanDays      = $config.OlderThanDays
        Exclusions         = $config.Exclusions
        CustomCleanupPaths = $config.CustomCleanupPaths
        LogPath            = $logPath
        LogDir             = $script:LogDir
        TotalFreed         = [long]0
        TotalCleaned       = 0
        TotalErrors        = 0
        TaskBytes          = [long]0
    }

    if (-not $Silent) {
        Write-WinSweepLog "Starting WinSweep CLI ($mode) | Preset: $Preset | Tasks: $($selectedKeys.Count)" "INFO" $null $logPath
    }

    foreach ($tk in $selectedKeys) {
        $task = $tasks[$tk]
        $ctx.TaskBytes = [long]0
        try {
            & $task.Action $ctx
        } catch {
            Write-WinSweepLog "Error in $($task.Name): $_" "ERR" $null $logPath
            $ctx.TotalErrors++
        }
    }

    Write-WinSweepLog "Finished ($mode): $($ctx.TotalCleaned) operations | $(Format-ByteSize -Bytes $ctx.TotalFreed) | Errors: $($ctx.TotalErrors)" "DONE" $null $logPath
    exit 0
}

# -- 4. Launch WPF GUI ---------------------------------------------------------
. (Join-Path $script:RootDir "src\UI\MainWindow.ps1")
Start-WinSweepGui -RootDir $script:RootDir -LogDir $script:LogDir -Config $config -Tasks $tasks
