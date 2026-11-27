<#
.SYNOPSIS
    WinSweep - Modern Interactive Windows Cleanup & Privacy Tool
.DESCRIPTION
    WPF-based graphical interface with interactive checkboxes, category grouping,
    presets, and live progress logging.
    Detailed log file saved for every cleanup run with full date and time stamps.
    Browser data is NEVER touched.
    No special icons or emojis used - 100% standard ASCII text.
.NOTES
    Must be run as Administrator in STA mode.
    Version: 3.3
#>

[CmdletBinding()]
param(
    [switch]$NoGui
)

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'

# -- 1. Admin Verification & Auto-Elevation ------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# -- 2. Load GUI Assemblies ---------------------------------------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

# -- 3. Logging Setup & Global Variables --------------------------------------
$script:LogDir = Join-Path $PSScriptRoot "Logs"
if (-not (Test-Path -LiteralPath $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}
$script:CurrentLogPath = $null

$script:totalFreed   = [long]0
$script:totalErrors  = 0
$script:totalCleaned = 0

function Get-UserProfiles {
    Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
}

function Pump-WpfEvents {
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Action[System.Object]]{ param($f) $f.Continue = $false },
        $frame
    ) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Log-Gui {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $now = Get-Date
    $stampShort = $now.ToString('HH:mm:ss')
    $stampFull  = $now.ToString('yyyy-MM-dd HH:mm:ss')

    $guiLine = "[$stampShort] [$Type] $Message`r`n"
    $logLine = "[$stampFull] [$Type] $Message"

    # Update GUI console
    if ($txtLog) {
        $txtLog.AppendText($guiLine)
        $txtLog.ScrollToEnd()
        Pump-WpfEvents
    } else {
        Write-Host $guiLine
    }

    # Write to disk log file
    if ($script:CurrentLogPath) {
        try {
            Add-Content -LiteralPath $script:CurrentLogPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Clean-FolderContents {
    param(
        [string]$Path,
        [string]$Label,
        [string]$Filter = '*',
        [switch]$Recurse
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Log-Gui "$Label (Path not found: $Path)" "SKIP"
        return
    }

    # Safety guard: Never scan drive roots recursively
    if ($Path -match '^[a-zA-Z]:\\?$') {
        Log-Gui "$Label (Refusing direct root directory scan for safety)" "SKIP"
        return
    }

    try {
        $items = if ($Recurse) {
            Get-ChildItem -LiteralPath $Path -Filter $Filter -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem -LiteralPath $Path -Filter $Filter -Force -ErrorAction SilentlyContinue
        }

        if (-not $items -or $items.Count -eq 0) {
            Log-Gui "$Label (0 items to clean)" "SKIP"
            return
        }

        # Calculate freed bytes directly from matching files (instantaneous)
        $freedBytes = [long]0
        foreach ($item in $items) {
            if (-not $item.PSIsContainer) {
                $freedBytes += $item.Length
            }
        }

        $items | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        $script:totalFreed += $freedBytes
        $script:totalCleaned++
        $freedMb = [math]::Round($freedBytes / 1MB, 2)
        Log-Gui "$Label - Freed ~$freedMb MB ($($items.Count) items)" "OK"
    } catch {
        $script:totalErrors++
        Log-Gui "$Label failed: $_" "ERR"
    }
}

function Clean-SingleFile {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        Log-Gui "$Label (File not found)" "SKIP"
        return
    }
    try {
        $size = (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Length
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($size) { $script:totalFreed += $size }
        $script:totalCleaned++
        $freedMb = [math]::Round($size / 1MB, 2)
        Log-Gui "$Label - Freed ~$freedMb MB" "OK"
    } catch {
        $script:totalErrors++
        Log-Gui "$Label failed: $_" "ERR"
    }
}

# -- 4. Task Definitions -------------------------------------------------------
$tasks = [ordered]@{
    # -- Antivirus & Security --
    "chkKaspersky" = @{
        Name = "Kaspersky Lab Logs & Traces"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning Kaspersky Lab logs, reports, traces, and crash dumps..." "RUN"
            Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .log files" -Filter "*.log" -Recurse
            Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .rpt files" -Filter "*.rpt" -Recurse
            Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .trace files" -Filter "*.trace" -Recurse
            Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .dmp files" -Filter "*.dmp" -Recurse
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Kaspersky Lab") "Kaspersky User Logs: $($p.Name)" -Recurse
            }
        }
    }
    "chkDefender" = @{
        Name = "Windows Defender Scan & Support Logs"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning Windows Defender scan history & support logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Scans\History" "Defender Scan History" -Recurse
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Support" "Defender Support Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Quarantine" "Defender Quarantine Cache" -Recurse
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\LocalCopy" "Defender LocalCopy" -Recurse
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Network Inspection System\Support" "Defender NIS Logs" -Recurse
        }
    }
    "chkEset" = @{
        Name = "ESET / NOD32 Antivirus Logs"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning ESET logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\ESET\ESET Security\Logs" "ESET Security Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\ESET\ESET NOD32 Antivirus\Logs" "ESET NOD32 Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\ESET\RemoteAdministrator\Agent\Logs" "ESET RA Logs" -Recurse
        }
    }
    "chkAvastAvg" = @{
        Name = "Avast & AVG Logs & Reports"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning Avast and AVG logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\log" "Avast Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\report" "Avast Reports" -Recurse
            Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\chest" "Avast Quarantine Chest" -Recurse
            Clean-FolderContents "$env:ProgramData\AVG\Antivirus\log" "AVG Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\AVG\Antivirus\report" "AVG Reports" -Recurse
        }
    }
    "chkBitdefender" = @{
        Name = "Bitdefender Logs & Dumps"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning Bitdefender logs and dumps..." "RUN"
            Clean-FolderContents "$env:ProgramData\Bitdefender\Desktop\Profiles\Logs" "Bitdefender Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Bitdefender\DumpFolder" "Bitdefender Dumps" -Recurse
        }
    }
    "chkNorton" = @{
        Name = "Norton & Symantec SEP Logs"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning Norton and Symantec logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\Norton\Logs" "Norton Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Logs" "Symantec SEP Logs" -Recurse
        }
    }
    "chkMcafee" = @{
        Name = "McAfee Logs & WebAdvisor Data"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning McAfee logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\McAfee\DesktopProtection\Logs" "McAfee DP Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\McAfee\Endpoint Security\Logs" "McAfee ES Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\McAfee\Agent\Logs" "McAfee Agent Logs" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\McAfee\WebAdvisor\Logs" "McAfee WebAdvisor" -Recurse
        }
    }
    "chkOtherAv" = @{
        Name = "Malwarebytes, Sophos, Trend Micro, CrowdStrike Logs"
        Category = "Security"
        Default = $true
        Action = {
            Log-Gui "Cleaning other security suites logs..." "RUN"
            Clean-FolderContents "$env:ProgramData\Malwarebytes\MBAMService\Logs" "Malwarebytes Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Malwarebytes\MBAMService\ScanResults" "Malwarebytes Scans" -Recurse
            Clean-FolderContents "$env:ProgramData\Sophos\Sophos Anti-Virus\logs" "Sophos AV Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Sophos\Endpoint Defense\Logs" "Sophos Endpoint" -Recurse
            Clean-FolderContents "$env:ProgramData\Trend Micro\Logs" "Trend Micro Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Trend Micro\AMSP\log" "Trend Micro AMSP" -Recurse
            Clean-FolderContents "$env:ProgramData\F-Secure\Log" "F-Secure Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Comodo\Firewall Pro\Logs" "Comodo Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\Panda Security\Logs" "Panda Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\G Data\Logs" "G Data Logs" -Recurse
            Clean-FolderContents "$env:ProgramData\WRData\Logs" "Webroot Logs" -Recurse
            Clean-FolderContents "$env:SystemRoot\System32\drivers\CrowdStrike\Logs" "CrowdStrike Logs" -Recurse
        }
    }

    # -- Windows System & Logs --
    "chkEventLogs" = @{
        Name = "Windows Event Logs (System, App, Security)"
        Category = "System"
        Default = $true
        Action = {
            Log-Gui "Clearing Windows Event Logs via API..." "RUN"
            try {
                $evLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
                $count = 0
                foreach ($lg in $evLogs) {
                    try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($lg.LogName); $count++ } catch {}
                }
                Log-Gui "Cleared $count active Windows Event logs" "OK"
                $script:totalCleaned++
            } catch {
                Log-Gui "Event log clearing: $_" "ERR"
            }
            Clean-FolderContents "$env:SystemRoot\System32\winevt\Logs" "Archived .evtx log files" -Filter "*.evtx" -Recurse
        }
    }
    "chkWinLogs" = @{
        Name = "Windows Diagnostic & Setup Logs (Panther, CBS, DISM)"
        Category = "System"
        Default = $true
        Action = {
            Log-Gui "Cleaning Windows diagnostic and setup logs..." "RUN"
            Clean-FolderContents "$env:SystemRoot\Logs" "Windows\Logs directory" -Recurse
            Clean-FolderContents "$env:SystemRoot\Panther" "Panther setup logs" -Recurse
            Clean-FolderContents "$env:SystemRoot\inf" "Driver install logs (.log)" -Filter "*.log" -Recurse
            Clean-FolderContents "$env:SystemRoot\System32\LogFiles" "System32 LogFiles" -Recurse
            Clean-FolderContents "$env:SystemRoot\System32\wbem\Logs" "WMI Logs" -Recurse
            Clean-FolderContents "$env:SystemRoot\debug" "Windows debug logs" -Recurse
            Clean-FolderContents "$env:SystemRoot\LiveKernelReports" "Live Kernel Reports" -Recurse
            Clean-FolderContents "$env:SystemRoot\Performance\WinSAT\DataStore" "WinSAT DataStore" -Recurse
            Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\DataStore\Logs" "Windows Update DataStore Logs" -Recurse
            Clean-FolderContents "$env:SystemRoot\System32\SleepStudy" "SleepStudy diagnostics" -Recurse
            Clean-SingleFile "$env:SystemRoot\Logs\CBS\CBS.log" "CBS servicing log"
            Clean-SingleFile "$env:SystemRoot\Logs\DISM\dism.log" "DISM servicing log"
            Clean-FolderContents "$env:SystemDrive\inetpub\logs\LogFiles" "IIS Web Logs" -Recurse
        }
    }
    "chkCrashDumps" = @{
        Name = "Crash Dumps & Windows Error Reports (WER)"
        Category = "System"
        Default = $true
        Action = {
            Log-Gui "Cleaning memory dumps and WER crash reports..." "RUN"
            Clean-FolderContents "$env:LOCALAPPDATA\CrashDumps" "User Crash Dumps" -Recurse
            Clean-FolderContents "$env:SystemRoot\Minidump" "System Minidumps" -Recurse
            Clean-SingleFile "$env:SystemRoot\MEMORY.DMP" "Full Memory Dump (MEMORY.DMP)"
            Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\WER" "User WER reports" -Recurse
            Clean-FolderContents "$env:ProgramData\Microsoft\Windows\WER" "System WER reports" -Recurse
            Clean-FolderContents "$env:SystemRoot\System32\config\systemprofile\AppData\Local\CrashDumps" "System Profile Dumps" -Recurse
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\CrashDumps") "CrashDumps: $($p.Name)" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\Windows\WER") "WER: $($p.Name)" -Recurse
            }
        }
    }
    "chkDeliveryOpt" = @{
        Name = "Delivery Optimization & Windows.old residue"
        Category = "System"
        Default = $true
        Action = {
            Log-Gui "Cleaning Delivery Optimization and previous installation backups..." "RUN"
            Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization Cache" -Recurse
            Clean-FolderContents "$env:SystemDrive\Windows.old" "Windows.old archive directory" -Recurse

            # Root setup logs: target only files directly in C:\, without scanning subdirectories
            $rootLogs = Get-ChildItem -Path "$env:SystemDrive\*.log" -Force -ErrorAction SilentlyContinue
            if ($rootLogs -and $rootLogs.Count -gt 0) {
                foreach ($f in $rootLogs) {
                    Clean-SingleFile $f.FullName "Root setup log: $($f.Name)"
                }
            } else {
                Log-Gui "Root setup logs: None found in $env:SystemDrive\" "SKIP"
            }

            Clean-FolderContents "$env:SystemRoot\System32\config\systemprofile\AppData\Local\Microsoft\Windows\RetailDemo" "Retail Demo Offline" -Recurse
        }
    }
    "chkSearchLogs" = @{
        Name = "Windows Search Gather Logs"
        Category = "System"
        Default = $true
        Action = {
            Log-Gui "Cleaning Windows Search gather logs..." "RUN"
            Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
            Clean-FolderContents "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\GatherLogs" "Search Gather Logs" -Recurse
            Start-Service -Name WSearch -ErrorAction SilentlyContinue
        }
    }

    # -- Temporary & System Caches --
    "chkTempFiles" = @{
        Name = "System & User Temp Files (%TEMP%)"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Cleaning all user and system Temp folders..." "RUN"
            Clean-FolderContents $env:TEMP "User Temp ($env:TEMP)" -Recurse
            Clean-FolderContents "$env:SystemRoot\Temp" "System Temp ($env:SystemRoot\Temp)" -Recurse
            Clean-FolderContents "$env:SystemRoot\SystemTemp" "SystemTemp" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Temp" "Local AppData Temp" -Recurse
            Clean-FolderContents "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\Temp" "LocalService Temp" -Recurse
            Clean-FolderContents "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Temp" "NetworkService Temp" -Recurse
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Temp") "Temp: $($p.Name)" -Recurse
            }
        }
    }
    "chkPrefetch" = @{
        Name = "Windows Prefetch Cache"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Cleaning Windows Prefetch execution cache..." "RUN"
            Clean-FolderContents "$env:SystemRoot\Prefetch" "Prefetch Directory" -Recurse
        }
    }
    "chkWinUpdate" = @{
        Name = "Windows Update Download Cache"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Stopping update services and purging Windows Update cache..." "RUN"
            Stop-Service -Name wuauserv,bits,cryptSvc -Force -ErrorAction SilentlyContinue
            Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\Download" "Update Downloads" -Recurse
            Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\PostRebootEventCache.V2" "WU Post-Reboot Cache" -Recurse
            Start-Service -Name cryptSvc,bits,wuauserv -ErrorAction SilentlyContinue
            Log-Gui "Windows Update services restarted" "OK"
        }
    }
    "chkRecycleBin" = @{
        Name = "Empty Recycle Bin (All Drives)"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Emptying Recycle Bin on all drives..." "RUN"
            try {
                Clear-RecycleBin -Force -ErrorAction Stop
                Log-Gui "Recycle Bin purged successfully" "OK"
                $script:totalCleaned++
            } catch {
                Log-Gui "Recycle Bin already empty or in use" "SKIP"
            }
        }
    }
    "chkThumbIcons" = @{
        Name = "Thumbnail & Icon Database Caches"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Cleaning thumbnail and icon database files..." "RUN"
            foreach ($p in (Get-UserProfiles)) {
                $exp = Join-Path $p.FullName "AppData\Local\Microsoft\Windows\Explorer"
                if (Test-Path -LiteralPath $exp) {
                    Get-ChildItem -LiteralPath $exp -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Get-ChildItem -LiteralPath $exp -Filter "iconcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Log-Gui "Thumb/Icon cache for $($p.Name)" "OK"
                    $script:totalCleaned++
                }
                Clean-SingleFile (Join-Path $p.FullName "AppData\Local\IconCache.db") "IconCache.db ($($p.Name))"
            }
        }
    }
    "chkFontCache" = @{
        Name = "Windows Font Cache"
        Category = "Caches"
        Default = $false
        Action = {
            Log-Gui "Cleaning font cache services..." "RUN"
            Stop-Service -Name FontCache,FontCache3.0.0.0 -Force -ErrorAction SilentlyContinue
            Clean-FolderContents "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache" "Font Cache files" -Recurse
            Clean-SingleFile "$env:SystemRoot\System32\FNTCACHE.DAT" "FNTCACHE.DAT"
            Start-Service -Name FontCache -ErrorAction SilentlyContinue
        }
    }
    "chkInstallerCache" = @{
        Name = "Orphaned Installer Patch Cache"
        Category = "Caches"
        Default = $true
        Action = {
            Log-Gui "Cleaning Windows Installer patch cache..." "RUN"
            Clean-FolderContents ($env:SystemRoot + '\Installer\$PatchCache$\Managed') "Installer Patch Cache" -Recurse
        }
    }

    # -- App & Hardware Caches --
    "chkGpuShaders" = @{
        Name = "GPU Shaders (NVIDIA, AMD, Intel, DirectX)"
        Category = "Apps"
        Default = $true
        Action = {
            Log-Gui "Purging GPU DirectX, OpenGL, and Vulkan shader caches..." "RUN"
            Clean-FolderContents "$env:LOCALAPPDATA\NVIDIA\DXCache" "NVIDIA DX Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\NVIDIA\GLCache" "NVIDIA GL Cache" -Recurse
            Clean-FolderContents "$env:ProgramData\NVIDIA Corporation\NV_Cache" "NVIDIA NV_Cache" -Recurse
            Clean-FolderContents "$env:TEMP\NVIDIA Corporation\NV_Cache" "NVIDIA Temp Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\AMD\DxCache" "AMD DirectX Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\AMD\GLCache" "AMD OpenGL Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\AMD\VkCache" "AMD Vulkan Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Intel\ShaderCache" "Intel Shader Cache" -Recurse
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\D3DSCache") "D3DSCache ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\LocalLow\Intel\ShaderCache") "Intel Shader ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache") "NVIDIA Driver DXCache ($($p.Name))" -Recurse
            }
        }
    }
    "chkOfficeTeams" = @{
        Name = "Office, Teams, OneDrive & Steam Diagnostic Logs"
        Category = "Apps"
        Default = $true
        Action = {
            Log-Gui "Cleaning Office, Teams, OneDrive, and Steam logs..." "RUN"
            Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache" "Office File Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\Office\OTele" "Office Telemetry" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization\Logs" "Delivery Optimization Logs" -Recurse
            Clean-FolderContents "$env:ProgramFiles (x86)\Steam\logs" "Steam Logs" -Recurse
            Clean-FolderContents "${env:ProgramFiles}\Steam\logs" "Steam Logs (x64)" -Recurse
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\OneDrive\logs") "OneDrive Logs ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Teams\logs") "Teams Logs ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Teams\watchdog") "Teams Watchdog ($($p.Name))" -Recurse
            }
        }
    }
    "chkDevCaches" = @{
        Name = "Developer Tool Caches (pip, npm, NuGet, Yarn)"
        Category = "Apps"
        Default = $false
        Action = {
            Log-Gui "Cleaning developer package and runtime caches..." "RUN"
            Clean-FolderContents "$env:LOCALAPPDATA\NuGet\v3-cache" "NuGet v3 Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\NuGet\plugins-cache" "NuGet Plugins" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\pip\cache" "Python pip Cache" -Recurse
            Clean-FolderContents "$env:APPDATA\npm-cache" "npm Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Yarn\Cache" "Yarn Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Sun\Java\Deployment\cache" "Java Deployment Cache" -Recurse
            Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\VisualStudio\Packages\_Instances" "VS Packages Cache" -Recurse
            Clean-FolderContents "$env:TEMP\VSFeedbackIntelliCodeLogs" "VS IntelliCode Logs" -Recurse
        }
    }
    "chkDnsCache" = @{
        Name = "Flush Windows DNS Resolver Cache"
        Category = "Apps"
        Default = $true
        Action = {
            Log-Gui "Flushing DNS Client cache..." "RUN"
            try {
                Clear-DnsClientCache
                Log-Gui "DNS cache flushed successfully" "OK"
                $script:totalCleaned++
            } catch {
                Log-Gui "DNS cache flush: $_" "ERR"
            }
        }
    }
    "chkRecentFiles" = @{
        Name = "Recent Files History & Jump Lists"
        Category = "Apps"
        Default = $false
        Action = {
            Log-Gui "Clearing Explorer Recent Files and Jump Lists..." "RUN"
            foreach ($p in (Get-UserProfiles)) {
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent") "Recent Items ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations") "Auto JumpLists ($($p.Name))" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations") "Custom JumpLists ($($p.Name))" -Recurse
            }
        }
    }
    "chkAiConversations" = @{
        Name = "AI Conversations & CLI History (Antigravity, Cursor, Claude, ChatGPT)"
        Category = "Apps"
        Default = $false
        Action = {
            Log-Gui "Cleaning AI conversations, CLI transcripts, and assistant caches..." "RUN"
            foreach ($p in (Get-UserProfiles)) {
                # Antigravity CLI brain conversations, transcripts and scratch directories
                $agyBrain = Join-Path $p.FullName ".gemini\antigravity-cli\brain"
                Clean-FolderContents $agyBrain "Antigravity CLI Conversation Transcripts (brain)" -Recurse
                
                # Antigravity CLI execution logs
                $agyLogs = Join-Path $p.FullName ".gemini\antigravity-cli\logs"
                Clean-FolderContents $agyLogs "Antigravity CLI Logs" -Recurse

                # Gemini cache
                $geminiCache = Join-Path $p.FullName ".gemini\cache"
                Clean-FolderContents $geminiCache "Gemini CLI Cache" -Recurse

                # Aider CLI chat and input histories
                Clean-SingleFile (Join-Path $p.FullName ".aider.chat.history.md") "Aider Chat History"
                Clean-SingleFile (Join-Path $p.FullName ".aider.input.history") "Aider Input History"

                # Continue extension chat sessions and index
                Clean-FolderContents (Join-Path $p.FullName ".continue\sessions") "Continue Extension Sessions" -Recurse
                Clean-FolderContents (Join-Path $p.FullName ".continue\index") "Continue Code Index" -Recurse

                # Ollama service and app logs
                Clean-FolderContents (Join-Path $p.FullName ".ollama\logs") "Ollama Service Logs" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Ollama\logs") "Ollama App Logs" -Recurse

                # Cursor AI IDE workspace storage and logs
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Cursor\logs") "Cursor AI Logs" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Cursor\User\workspaceStorage") "Cursor AI Workspace Sessions" -Recurse

                # Claude Desktop logs and cache
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Claude\logs") "Claude Desktop Logs" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Claude\Cache") "Claude Desktop Cache" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Claude\Code Cache") "Claude Code Cache" -Recurse

                # ChatGPT Desktop logs and cache
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\ChatGPT\Cache") "ChatGPT Desktop Cache" -Recurse
                Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\ChatGPT\logs") "ChatGPT Desktop Logs" -Recurse

                # GitHub Copilot logs and cache
                Clean-FolderContents (Join-Path $p.FullName "AppData\Local\github-copilot") "GitHub Copilot Cache" -Recurse
                Clean-FolderContents (Join-Path $p.FullName ".copilot\logs") "Copilot CLI Logs" -Recurse
            }
        }
    }
    "chkOperationTraces" = @{
        Name = "Remove All Activity Traces (PowerShell History, RunMRU, UserAssist)"
        Category = "Apps"
        Default = $false
        Action = {
            Log-Gui "Purging all operational activity traces, command histories, and MRU caches..." "RUN"

            # 1. PowerShell ConsoleHost_history.txt for all user profiles
            foreach ($p in (Get-UserProfiles)) {
                $psHistory = Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
                Clean-SingleFile $psHistory "PowerShell Command History ($($p.Name))"
            }
            try {
                [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
            } catch {}
            try {
                Clear-History -ErrorAction SilentlyContinue
            } catch {}

            # 2. Windows Run Dialog History (RunMRU)
            try {
                $runMruKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
                if (Test-Path $runMruKey) {
                    $props = (Get-ItemProperty -Path $runMruKey).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                    foreach ($prop in $props) {
                        Remove-ItemProperty -Path $runMruKey -Name $prop.Name -Force -ErrorAction SilentlyContinue
                    }
                    Log-Gui "Windows Run dialog history (RunMRU) cleared" "OK"
                    $script:totalCleaned++
                }
            } catch {
                Log-Gui "RunMRU clearing: $_" "ERR"
            }

            # 3. Explorer TypedPaths (Address bar dropdown history)
            try {
                $typedPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
                if (Test-Path $typedPathsKey) {
                    $props = (Get-ItemProperty -Path $typedPathsKey).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                    foreach ($prop in $props) {
                        Remove-ItemProperty -Path $typedPathsKey -Name $prop.Name -Force -ErrorAction SilentlyContinue
                    }
                    Log-Gui "Explorer Address Bar Typed Paths cleared" "OK"
                    $script:totalCleaned++
                }
            } catch {
                Log-Gui "TypedPaths clearing: $_" "ERR"
            }

            # 4. UserAssist (tracks recently executed programs and GUI launch counts)
            try {
                $userAssistKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
                if (Test-Path $userAssistKey) {
                    Get-ChildItem -Path $userAssistKey -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                        $subProps = (Get-ItemProperty -Path $_.PSPath).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                        foreach ($sp in $subProps) {
                            Remove-ItemProperty -Path $_.PSPath -Name $sp.Name -Force -ErrorAction SilentlyContinue
                        }
                    }
                    Log-Gui "Windows UserAssist program execution traces cleared" "OK"
                    $script:totalCleaned++
                }
            } catch {
                Log-Gui "UserAssist clearing: $_" "ERR"
            }

            # 5. Connected Devices Platform (Activity History / Timeline)
            foreach ($p in (Get-UserProfiles)) {
                $cdpPath = Join-Path $p.FullName "AppData\Local\ConnectedDevicesPlatform"
                Clean-FolderContents $cdpPath "Activity History (ConnectedDevicesPlatform: $($p.Name))" -Recurse
            }

            # 6. Windows Clipboard History
            try {
                [System.Windows.Clipboard]::Clear()
                Log-Gui "Windows Clipboard history purged" "OK"
                $script:totalCleaned++
            } catch {
                Log-Gui "Clipboard clear: $_" "SKIP"
            }

            # 7. Purge previous cleanup tool logs (except the currently active log file)
            try {
                if (Test-Path -LiteralPath $script:LogDir) {
                    $oldLogs = Get-ChildItem -LiteralPath $script:LogDir -Filter "*.log" -Force -ErrorAction SilentlyContinue |
                        Where-Object { -not $script:CurrentLogPath -or $_.FullName -ne $script:CurrentLogPath }
                    if ($oldLogs) {
                        $oldCount = $oldLogs.Count
                        $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
                        Log-Gui "Purged $oldCount previous cleanup session logs from disk" "OK"
                        $script:totalCleaned++
                    }
                }
            } catch {
                Log-Gui "Old logs purge: $_" "SKIP"
            }
        }
    }
    "chkCleanMgr" = @{
        Name = "Automated Windows Disk Cleanup (cleanmgr /sagerun)"
        Category = "Apps"
        Default = $true
        Action = {
            Log-Gui "Invoking native Windows Disk Cleanup..." "RUN"
            try {
                $volKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                if (Test-Path $volKey) {
                    foreach ($k in (Get-ChildItem $volKey -ErrorAction SilentlyContinue)) {
                        if ($k.PSChildName -match 'Internet|Temporary Internet') { continue }
                        Set-ItemProperty -Path $k.PSPath -Name "StateFlags1000" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                    }
                    $proc = Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:1000" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                    if ($proc) {
                        $timeoutSeconds = 45
                        $elapsed = 0
                        while (-not $proc.HasExited -and $elapsed -lt $timeoutSeconds) {
                            Start-Sleep -Milliseconds 500
                            $elapsed += 0.5
                            Pump-WpfEvents
                        }
                        if ($proc.HasExited) {
                            Log-Gui "Native Disk Cleanup completed" "OK"
                        } else {
                            Log-Gui "Native Disk Cleanup continuing in background" "OK"
                        }
                        $script:totalCleaned++
                    }
                }
            } catch {
                Log-Gui "Disk Cleanup: $_" "SKIP"
            }
        }
    }
}

# -- 5. Build Clean WPF User Interface (Pure standard text, no icons) ----------
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WinSweep - Windows System & Privacy Cleaner" Height="820" Width="1000"
    MinHeight="680" MinWidth="880"
    WindowStartupLocation="CenterScreen"
    Background="#0F172A" Foreground="#F8FAFC"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Standard CheckBox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <!-- Standard Button Style -->
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Quick Action Buttons -->
            <RowDefinition Height="*"/>    <!-- Category Cards -->
            <RowDefinition Height="165"/>  <!-- Live Log Console -->
            <RowDefinition Height="Auto"/> <!-- Bottom Status & Run Bar -->
        </Grid.RowDefinitions>

        <!-- 1. Header -->
        <Border Grid.Row="0" Background="#1E293B" CornerRadius="6" Padding="16,12" Margin="0,0,0,12" BorderBrush="#334155" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="WINSWEEP" FontSize="19" FontWeight="Bold" Foreground="#38BDF8"/>
                        <Border Background="#0284C7" CornerRadius="3" Margin="10,2,0,2" Padding="6,1">
                            <TextBlock Text="v3.3" FontSize="11" FontWeight="Bold" Foreground="White"/>
                        </Border>
                    </StackPanel>
                    <TextBlock Text="Clean Windows logs, event viewer, antivirus traces, temp files and prefetch cache."
                               Foreground="#94A3B8" FontSize="12" Margin="0,3,0,0"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#064E3B" CornerRadius="4" Padding="10,6" BorderBrush="#059669" BorderThickness="1">
                    <TextBlock Text="[SAFE] Browser Data Untouched" Foreground="#6EE7B7" FontWeight="Bold" FontSize="12"/>
                </Border>
            </Grid>
        </Border>

        <!-- 2. Preset & Filter Bar -->
        <Border Grid.Row="1" Background="#182234" CornerRadius="5" Padding="10,8" Margin="0,0,0,12" BorderBrush="#2A384F" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="PRESETS:" FontWeight="Bold" FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center" Margin="4,0,12,0"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button Name="btnPresetAll" Content="Select All" Margin="0,0,8,0" Background="#2563EB" BorderBrush="#3B82F6"/>
                    <Button Name="btnPresetNone" Content="Deselect All" Margin="0,0,8,0"/>
                    <Button Name="btnPresetRecommended" Content="Recommended (Safe)" Margin="0,0,8,0" Background="#0D9488" BorderBrush="#14B8A6"/>
                    <Button Name="btnPresetSecurityOnly" Content="Antivirus Logs Only" Margin="0,0,8,0" Background="#4F46E5" BorderBrush="#6366F1"/>
                    <Button Name="btnPresetTempOnly" Content="Temp and Caches Only" Margin="0,0,8,0"/>
                    <Button Name="btnPresetPrivacyOnly" Content="Privacy and Traces Only" Margin="0,0,8,0" Background="#7C3AED" BorderBrush="#8B5CF6"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- 3. Category Columns with Checkboxes -->
        <Grid Grid.Row="2" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- LEFT COLUMN: Security & System -->
            <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,6,0">
                <StackPanel>
                    <!-- Card 1: Antivirus & Security -->
                    <Border Background="#1E293B" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#334155" BorderThickness="1">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="[SECURITY] ANTIVIRUS AND SECURITY LOGS" FontWeight="Bold" FontSize="13" Foreground="#F43F5E"/>
                                <CheckBox Name="chkGroupSecurity" Content="Select Group" HorizontalAlignment="Right" FontSize="11" Foreground="#94A3B8"/>
                            </DockPanel>
                            <Separator Background="#334155" Margin="0,0,0,8"/>
                            <CheckBox Name="chkKaspersky" Content="Kaspersky Lab (Logs, Traces, Dumps, Reports)"/>
                            <CheckBox Name="chkDefender" Content="Windows Defender (Scan History and Quarantine)"/>
                            <CheckBox Name="chkEset" Content="ESET / NOD32 Antivirus Logs"/>
                            <CheckBox Name="chkAvastAvg" Content="Avast and AVG Logs and Chest Cache"/>
                            <CheckBox Name="chkBitdefender" Content="Bitdefender Profile Logs and Dumps"/>
                            <CheckBox Name="chkNorton" Content="Norton and Symantec SEP Logs"/>
                            <CheckBox Name="chkMcafee" Content="McAfee Protection Logs and WebAdvisor"/>
                            <CheckBox Name="chkOtherAv" Content="Malwarebytes, Sophos, Trend Micro, CrowdStrike"/>
                        </StackPanel>
                    </Border>

                    <!-- Card 2: Windows System Logs -->
                    <Border Background="#1E293B" CornerRadius="6" Padding="14" BorderBrush="#334155" BorderThickness="1">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="[SYSTEM] WINDOWS SYSTEM AND EVENT LOGS" FontWeight="Bold" FontSize="13" Foreground="#38BDF8"/>
                                <CheckBox Name="chkGroupSystem" Content="Select Group" HorizontalAlignment="Right" FontSize="11" Foreground="#94A3B8"/>
                            </DockPanel>
                            <Separator Background="#334155" Margin="0,0,0,8"/>
                            <CheckBox Name="chkEventLogs" Content="Windows Event Logs (System, App, Security)"/>
                            <CheckBox Name="chkWinLogs" Content="Setup and Servicing Logs (Panther, CBS, DISM)"/>
                            <CheckBox Name="chkCrashDumps" Content="Crash Dumps and WER Error Reports"/>
                            <CheckBox Name="chkDeliveryOpt" Content="Delivery Optimization and Windows.old residues"/>
                            <CheckBox Name="chkSearchLogs" Content="Windows Search Gather Logs"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- RIGHT COLUMN: Caches & Apps -->
            <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" Margin="6,0,0,0">
                <StackPanel>
                    <!-- Card 3: System Caches & Temp -->
                    <Border Background="#1E293B" CornerRadius="6" Padding="14" Margin="0,0,0,10" BorderBrush="#334155" BorderThickness="1">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="[CACHES] TEMPORARY FILES AND CACHES" FontWeight="Bold" FontSize="13" Foreground="#F59E0B"/>
                                <CheckBox Name="chkGroupCaches" Content="Select Group" HorizontalAlignment="Right" FontSize="11" Foreground="#94A3B8"/>
                            </DockPanel>
                            <Separator Background="#334155" Margin="0,0,0,8"/>
                            <CheckBox Name="chkTempFiles" Content="System and User Temp Files (%TEMP%)"/>
                            <CheckBox Name="chkPrefetch" Content="Windows Prefetch Cache"/>
                            <CheckBox Name="chkWinUpdate" Content="Windows Update Download Cache"/>
                            <CheckBox Name="chkRecycleBin" Content="Empty Recycle Bin (All Drives)"/>
                            <CheckBox Name="chkThumbIcons" Content="Thumbnail and Icon Database Caches"/>
                            <CheckBox Name="chkFontCache" Content="Windows Font Cache (Restarts service)"/>
                            <CheckBox Name="chkInstallerCache" Content="Orphaned Installer Patch Cache"/>
                        </StackPanel>
                    </Border>

                    <!-- Card 4: Hardware & App Caches -->
                    <Border Background="#1E293B" CornerRadius="6" Padding="14" BorderBrush="#334155" BorderThickness="1">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="[APPS] HARDWARE, APPS AND ACTIVITY TRACES" FontWeight="Bold" FontSize="13" Foreground="#A855F7"/>
                                <CheckBox Name="chkGroupApps" Content="Select Group" HorizontalAlignment="Right" FontSize="11" Foreground="#94A3B8"/>
                            </DockPanel>
                            <Separator Background="#334155" Margin="0,0,0,8"/>
                            <CheckBox Name="chkAiConversations" Content="AI Conversations and CLI Logs (Antigravity, Cursor, Claude, ChatGPT)"/>
                            <CheckBox Name="chkOperationTraces" Content="Remove All Activity Traces (PowerShell History, RunMRU, UserAssist)"/>
                            <CheckBox Name="chkRecentFiles" Content="Recent Files History and Jump Lists"/>
                            <CheckBox Name="chkGpuShaders" Content="GPU Shaders (NVIDIA, AMD, Intel, DirectX)"/>
                            <CheckBox Name="chkOfficeTeams" Content="Office, Teams, OneDrive and Steam Logs"/>
                            <CheckBox Name="chkDevCaches" Content="Developer Caches (pip, npm, NuGet, Yarn)"/>
                            <CheckBox Name="chkDnsCache" Content="Flush Windows DNS Resolver Cache"/>
                            <CheckBox Name="chkCleanMgr" Content="Automated Disk Cleanup (cleanmgr)"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>
        </Grid>

        <!-- 4. Live Output Log Console -->
        <Border Grid.Row="3" Background="#0A0F1D" CornerRadius="5" BorderBrush="#1E293B" BorderThickness="1" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border Background="#111827" Padding="10,4" CornerRadius="5,5,0,0">
                    <DockPanel>
                        <TextBlock Text="LIVE EXECUTION LOG" FontSize="11" FontWeight="Bold" Foreground="#64748B" VerticalAlignment="Center"/>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                            <Button Name="btnViewCurrentLog" Content="View Log File" FontSize="10" Padding="8,2" Margin="0,0,6,0"/>
                            <Button Name="btnOpenLogsFolder" Content="Open Logs Folder" FontSize="10" Padding="8,2" Margin="0,0,6,0"/>
                            <Button Name="btnClearLog" Content="Clear Console" FontSize="10" Padding="8,2"/>
                        </StackPanel>
                    </DockPanel>
                </Border>
                <TextBox Name="txtLog" Grid.Row="1" Background="#0A0F1D" Foreground="#A7F3D0"
                         FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                         BorderThickness="0" Padding="8" AcceptsReturn="True" TextWrapping="Wrap"/>
            </Grid>
        </Border>

        <!-- 5. Bottom Action Bar -->
        <Border Grid.Row="4" Background="#1E293B" CornerRadius="6" Padding="14,10" BorderBrush="#334155" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel VerticalAlignment="Center">
                    <TextBlock Name="lblStatus" Text="Ready. Choose items above and click 'RUN SELECTED CLEANUP'."
                               Foreground="#38BDF8" FontWeight="SemiBold" FontSize="13"/>
                    <StackPanel Orientation="Horizontal" Margin="0,3,0,0">
                        <TextBlock Text="Space Freed: " Foreground="#94A3B8" FontSize="12"/>
                        <TextBlock Name="lblFreed" Text="0.00 MB" Foreground="#4ADE80" FontWeight="Bold" FontSize="12"/>
                        <TextBlock Text="  |  Items Cleaned: " Foreground="#94A3B8" FontSize="12"/>
                        <TextBlock Name="lblCleaned" Text="0" Foreground="#F8FAFC" FontWeight="Bold" FontSize="12"/>
                    </StackPanel>
                </StackPanel>

                <Button Name="btnRun" Grid.Column="1" Content="RUN SELECTED CLEANUP"
                        Background="#16A34A" BorderBrush="#22C55E" Foreground="White"
                        FontSize="13" FontWeight="Bold" Padding="20,10" Margin="0,0,10,0"/>

                <Button Name="btnExit" Grid.Column="2" Content="Close"
                        Background="#334155" BorderBrush="#475569" Foreground="#CBD5E1"
                        FontSize="13" Padding="16,10"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# -- 6. Load Window from XAML --------------------------------------------------
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Map UI Controls
$txtLog                 = $window.FindName("txtLog")
$lblStatus              = $window.FindName("lblStatus")
$lblFreed               = $window.FindName("lblFreed")
$lblCleaned             = $window.FindName("lblCleaned")
$btnRun                 = $window.FindName("btnRun")
$btnExit                = $window.FindName("btnExit")
$btnClearLog            = $window.FindName("btnClearLog")
$btnViewCurrentLog      = $window.FindName("btnViewCurrentLog")
$btnOpenLogsFolder      = $window.FindName("btnOpenLogsFolder")

$btnPresetAll           = $window.FindName("btnPresetAll")
$btnPresetNone          = $window.FindName("btnPresetNone")
$btnPresetRecommended   = $window.FindName("btnPresetRecommended")
$btnPresetSecurityOnly  = $window.FindName("btnPresetSecurityOnly")
$btnPresetTempOnly      = $window.FindName("btnPresetTempOnly")
$btnPresetPrivacyOnly   = $window.FindName("btnPresetPrivacyOnly")

$chkGroupSecurity       = $window.FindName("chkGroupSecurity")
$chkGroupSystem         = $window.FindName("chkGroupSystem")
$chkGroupCaches         = $window.FindName("chkGroupCaches")
$chkGroupApps           = $window.FindName("chkGroupApps")

# Map all task checkboxes and set default states
$chkControls = @{}
foreach ($key in $tasks.Keys) {
    $cb = $window.FindName($key)
    if ($cb) {
        $chkControls[$key] = $cb
        $cb.IsChecked = $tasks[$key].Default
    }
}

# -- 7. Wire Up Events ---------------------------------------------------------

# Helper to set checkbox states by filter
function Set-Checkboxes([scriptblock]$Filter) {
    foreach ($key in $tasks.Keys) {
        if ($chkControls.ContainsKey($key)) {
            $val = & $Filter $key $tasks[$key]
            $chkControls[$key].IsChecked = $val
        }
    }
}

# Presets
$btnPresetAll.Add_Click({
    Set-Checkboxes { $true }
    $chkGroupSecurity.IsChecked = $true
    $chkGroupSystem.IsChecked   = $true
    $chkGroupCaches.IsChecked   = $true
    $chkGroupApps.IsChecked     = $true
})

$btnPresetNone.Add_Click({
    Set-Checkboxes { $false }
    $chkGroupSecurity.IsChecked = $false
    $chkGroupSystem.IsChecked   = $false
    $chkGroupCaches.IsChecked   = $false
    $chkGroupApps.IsChecked     = $false
})

$btnPresetRecommended.Add_Click({
    Set-Checkboxes { param($k, $t) $t.Default }
})

$btnPresetSecurityOnly.Add_Click({
    Set-Checkboxes { param($k, $t) $t.Category -eq 'Security' }
    $chkGroupSecurity.IsChecked = $true
    $chkGroupSystem.IsChecked   = $false
    $chkGroupCaches.IsChecked   = $false
    $chkGroupApps.IsChecked     = $false
})

$btnPresetTempOnly.Add_Click({
    Set-Checkboxes { param($k, $t) $t.Category -eq 'Caches' }
    $chkGroupSecurity.IsChecked = $false
    $chkGroupSystem.IsChecked   = $false
    $chkGroupCaches.IsChecked   = $true
    $chkGroupApps.IsChecked     = $false
})

$btnPresetPrivacyOnly.Add_Click({
    Set-Checkboxes { param($k, $t) $k -in @('chkAiConversations', 'chkOperationTraces', 'chkRecentFiles', 'chkThumbIcons') }
    $chkGroupSecurity.IsChecked = $false
    $chkGroupSystem.IsChecked   = $false
    $chkGroupCaches.IsChecked   = $false
    $chkGroupApps.IsChecked     = $true
})

# Category Group Checkboxes
$chkGroupSecurity.Add_Click({
    $state = [bool]$chkGroupSecurity.IsChecked
    foreach ($k in $tasks.Keys) {
        if ($tasks[$k].Category -eq 'Security') { $chkControls[$k].IsChecked = $state }
    }
})

$chkGroupSystem.Add_Click({
    $state = [bool]$chkGroupSystem.IsChecked
    foreach ($k in $tasks.Keys) {
        if ($tasks[$k].Category -eq 'System') { $chkControls[$k].IsChecked = $state }
    }
})

$chkGroupCaches.Add_Click({
    $state = [bool]$chkGroupCaches.IsChecked
    foreach ($k in $tasks.Keys) {
        if ($tasks[$k].Category -eq 'Caches') { $chkControls[$k].IsChecked = $state }
    }
})

$chkGroupApps.Add_Click({
    $state = [bool]$chkGroupApps.IsChecked
    foreach ($k in $tasks.Keys) {
        if ($tasks[$k].Category -eq 'Apps') { $chkControls[$k].IsChecked = $state }
    }
})

$btnClearLog.Add_Click({
    $txtLog.Clear()
})

$btnOpenLogsFolder.Add_Click({
    if (Test-Path -LiteralPath $script:LogDir) {
        Start-Process explorer.exe -ArgumentList "`"$script:LogDir`""
    }
})

$btnViewCurrentLog.Add_Click({
    if ($script:CurrentLogPath -and (Test-Path -LiteralPath $script:CurrentLogPath)) {
        Start-Process notepad.exe -ArgumentList "`"$script:CurrentLogPath`""
    } else {
        [System.Windows.MessageBox]::Show(
            "No log file has been created yet. Run a cleanup first or open the logs folder.",
            "Log File Notice",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
})

$btnExit.Add_Click({
    $window.Close()
})

# -- 8. Execute Cleanup Action -------------------------------------------------
$btnRun.Add_Click({
    # Identify which tasks are checked
    $selectedTasks = @()
    foreach ($key in $tasks.Keys) {
        if ($chkControls.ContainsKey($key) -and $chkControls[$key].IsChecked) {
            $selectedTasks += $key
        }
    }

    if ($selectedTasks.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "Please check at least one cleanup task before running.",
            "No Items Selected",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        return
    }

    # Initialize log file with timestamp
    $startTime = Get-Date
    $timeFormatted = $startTime.ToString('yyyy-MM-dd_HH-mm-ss')
    $script:CurrentLogPath = Join-Path $script:LogDir "Cleanup_$timeFormatted.log"

    $logHeader = @"
================================================================================
WINSWEEP - DETAILED EXECUTION LOG
================================================================================
Date and Time : $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
Computer      : $env:COMPUTERNAME
User          : $env:USERNAME
Log File      : $script:CurrentLogPath
Safe Guard    : Browser caches, passwords and histories are strictly excluded.
================================================================================

"@
    [System.IO.File]::WriteAllText($script:CurrentLogPath, $logHeader, [System.Text.Encoding]::UTF8)

    # Lock UI controls during cleanup
    $btnRun.IsEnabled = $false
    $btnRun.Content = "Cleaning in progress..."
    $btnRun.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#9333EA")
    $lblStatus.Text = "Running cleanup on $($selectedTasks.Count) selected categories..."
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")

    $script:totalFreed = [long]0
    $script:totalErrors = 0
    $script:totalCleaned = 0

    Log-Gui "==================================================================" "START"
    Log-Gui "Starting cleanup of $($selectedTasks.Count) items at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "START"
    Log-Gui "Target Host: $env:COMPUTERNAME | Current User: $env:USERNAME" "INFO"
    Log-Gui "Log File: $script:CurrentLogPath" "INFO"
    Log-Gui "Browser caches and personal browsing data are STRICTLY EXCLUDED." "INFO"
    Log-Gui "==================================================================" "START"

    # Execute each task
    foreach ($taskKey in $selectedTasks) {
        $task = $tasks[$taskKey]
        $lblStatus.Text = "Processing: $($task.Name)..."
        Pump-WpfEvents
        try {
            & $task.Action
        } catch {
            Log-Gui "Error in $($task.Name): $_" "ERR"
            $script:totalErrors++
        }
        $freedMb = [math]::Round($script:totalFreed / 1MB, 2)
        $lblFreed.Text = "$freedMb MB"
        $lblCleaned.Text = "$($script:totalCleaned)"
        Pump-WpfEvents
    }

    # Memory Garbage Collection at end
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Final summary calculations
    $endTime = Get-Date
    $duration = $endTime - $startTime
    $durationStr = "{0} min {1} sec" -f [int]$duration.TotalMinutes, $duration.Seconds
    $totalMb = [math]::Round($script:totalFreed / 1MB, 2)
    $totalGb = [math]::Round($script:totalFreed / 1GB, 2)

    Log-Gui "==================================================================" "DONE"
    Log-Gui "CLEANUP COMPLETE" "DONE"
    Log-Gui "Total space recovered : $totalMb MB (~$totalGb GB)" "DONE"
    Log-Gui "Operations performed  : $script:totalCleaned" "DONE"
    Log-Gui "Errors/Skipped        : $script:totalErrors" "DONE"
    Log-Gui "Duration              : $durationStr" "DONE"
    Log-Gui "Detailed Log File     : $script:CurrentLogPath" "DONE"
    Log-Gui "==================================================================" "DONE"

    $lblStatus.Text = "Finished! Cleaned $script:totalCleaned items. Total space recovered: $totalMb MB."
    $lblStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#22C55E")
    $lblFreed.Text = "$totalMb MB"

    $btnRun.IsEnabled = $true
    $btnRun.Content = "RUN SELECTED CLEANUP"
    $btnRun.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#16A34A")

    $msgResult = [System.Windows.MessageBox]::Show(
        "Cleanup completed successfully!`n`nTotal Space Freed: $totalMb MB (~$totalGb GB)`nItems Processed: $script:totalCleaned`nDuration: $durationStr`n`nDetailed Log:`n$script:CurrentLogPath`n`nWould you like to open the detailed log file now?",
        "Cleanup Complete",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Information
    )

    if ($msgResult -eq [System.Windows.MessageBoxResult]::Yes) {
        if (Test-Path -LiteralPath $script:CurrentLogPath) {
            Start-Process notepad.exe -ArgumentList "`"$script:CurrentLogPath`""
        }
    }
})

# -- 9. Show Window ------------------------------------------------------------
Log-Gui "Tool ready. Select cleanup options and press 'RUN SELECTED CLEANUP'." "READY"
$window.ShowDialog() | Out-Null
