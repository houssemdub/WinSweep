# WinSweep Task Registry
# Categories: Security, System, Caches, Graphics, Apps, AI

function Get-WinSweepTasks {
    return [ordered]@{
        # ======================================================================
        # SECURITY (Antivirus & Security Logs)
        # ======================================================================
        "chkKaspersky" = @{
            Name     = "Kaspersky Lab (Logs, Traces, Dumps, Reports)"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans .log, .rpt, .trace, .dmp files in ProgramData\Kaspersky Lab and user AppData."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Kaspersky Lab logs, reports, traces, and crash dumps..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .log files" -Filter "*.log" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .rpt files" -Filter "*.rpt" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .trace files" -Filter "*.trace" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Kaspersky Lab" "Kaspersky .dmp files" -Filter "*.dmp" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Kaspersky Lab") "Kaspersky User Logs: $($p.Name)" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkDefender" = @{
            Name     = "Windows Defender (Scan History & Quarantine Cache)"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Windows Defender scan history, support logs, quarantine cache, LocalCopy, and NIS logs."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Windows Defender scan history & support logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Scans\History" "Defender Scan History" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Support" "Defender Support Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Quarantine" "Defender Quarantine Cache" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\LocalCopy" "Defender LocalCopy" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows Defender\Network Inspection System\Support" "Defender NIS Logs" -Recurse -Ctx $Ctx
            }
        }
        "chkEset" = @{
            Name     = "ESET / NOD32 Antivirus Logs"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans ESET Security, NOD32, and RemoteAdministrator Agent logs."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning ESET logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\ESET\ESET Security\Logs" "ESET Security Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\ESET\ESET NOD32 Antivirus\Logs" "ESET NOD32 Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\ESET\RemoteAdministrator\Agent\Logs" "ESET RA Logs" -Recurse -Ctx $Ctx
            }
        }
        "chkAvastAvg" = @{
            Name     = "Avast & AVG Logs, Reports & Chest Cache"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Avast and AVG log/report folders and Avast chest cache."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Avast and AVG logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\log" "Avast Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\report" "Avast Reports" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\AVAST Software\Avast\chest" "Avast Quarantine Chest" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\AVG\Antivirus\log" "AVG Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\AVG\Antivirus\report" "AVG Reports" -Recurse -Ctx $Ctx
            }
        }
        "chkBitdefender" = @{
            Name     = "Bitdefender Profile Logs & Dumps"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Bitdefender Desktop Profiles\Logs and DumpFolder."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Bitdefender logs and dumps..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\Bitdefender\Desktop\Profiles\Logs" "Bitdefender Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Bitdefender\DumpFolder" "Bitdefender Dumps" -Recurse -Ctx $Ctx
            }
        }
        "chkNorton" = @{
            Name     = "Norton & Symantec SEP Logs"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Norton and Symantec Endpoint Protection log directories."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Norton and Symantec logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\Norton\Logs" "Norton Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Logs" "Symantec SEP Logs" -Recurse -Ctx $Ctx
            }
        }
        "chkMcafee" = @{
            Name     = "McAfee Protection Logs & WebAdvisor"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans McAfee DesktopProtection, Endpoint Security, Agent, and WebAdvisor logs."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning McAfee logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\McAfee\DesktopProtection\Logs" "McAfee DP Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\McAfee\Endpoint Security\Logs" "McAfee ES Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\McAfee\Agent\Logs" "McAfee Agent Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:LOCALAPPDATA\McAfee\WebAdvisor\Logs" "McAfee WebAdvisor" -Recurse -Ctx $Ctx
            }
        }
        "chkOtherAv" = @{
            Name     = "Malwarebytes, Sophos, Trend Micro, CrowdStrike"
            Category = "Security"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans logs from Malwarebytes, Sophos, Trend Micro, F-Secure, Comodo, Panda, G Data, Webroot, and CrowdStrike."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning other security suites logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\Malwarebytes\MBAMService\Logs" "Malwarebytes Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Malwarebytes\MBAMService\ScanResults" "Malwarebytes Scans" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Sophos\Sophos Anti-Virus\logs" "Sophos AV Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Sophos\Endpoint Defense\Logs" "Sophos Endpoint" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Trend Micro\Logs" "Trend Micro Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Trend Micro\AMSP\log" "Trend Micro AMSP" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\F-Secure\Log" "F-Secure Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Comodo\Firewall Pro\Logs" "Comodo Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Panda Security\Logs" "Panda Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\G Data\Logs" "G Data Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\WRData\Logs" "Webroot Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\System32\drivers\CrowdStrike\Logs" "CrowdStrike Logs" -Recurse -Ctx $Ctx
            }
        }

        # ======================================================================
        # SYSTEM (Windows System & Event Logs)
        # ======================================================================
        "chkEventLogs" = @{
            Name     = "Windows Event Logs (System, App, Security)"
            Category = "System"
            Risk     = "Moderate"
            Default  = $true
            Tooltip  = "Clears active Windows Event Viewer channels via EventLogSession and archived .evtx logs."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Clearing Windows Event Logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                if ($Ctx.DryRun) {
                    $evLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
                    $cnt = if ($evLogs) { $evLogs.Count } else { 0 }
                    Write-WinSweepLog "[DRY RUN] Would clear $cnt active Windows Event logs" "DRY" $Ctx.SyncState $Ctx.LogPath
                } else {
                    try {
                        $evLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
                        $count = 0
                        foreach ($lg in $evLogs) {
                            try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($lg.LogName); $count++ } catch {}
                        }
                        Write-WinSweepLog "Cleared $count active Windows Event logs" "OK" $Ctx.SyncState $Ctx.LogPath
                        $Ctx.TotalCleaned++
                    } catch {
                        Write-WinSweepLog "Event log clearing: $_" "ERR" $Ctx.SyncState $Ctx.LogPath
                    }
                }
                Clean-FolderContents "$env:SystemRoot\System32\winevt\Logs" "Archived .evtx log files" -Filter "*.evtx" -Recurse -Ctx $Ctx
            }
        }
        "chkWinLogs" = @{
            Name     = "Diagnostic & Setup Logs (Panther, CBS, DISM, WMI)"
            Category = "System"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Windows\Logs, Panther, driver inf .log files, System32\LogFiles, WMI, debug, LiveKernelReports, SleepStudy, CBS/DISM, IIS."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Windows diagnostic and setup logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:SystemRoot\Logs" "Windows\Logs directory" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\Panther" "Panther setup logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\inf" "Driver install logs (.log)" -Filter "*.log" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\System32\LogFiles" "System32 LogFiles" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\System32\wbem\Logs" "WMI Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\debug" "Windows debug logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\LiveKernelReports" "Live Kernel Reports" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\Performance\WinSAT\DataStore" "WinSAT DataStore" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\DataStore\Logs" "Windows Update DataStore Logs" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\System32\SleepStudy" "SleepStudy diagnostics" -Recurse -Ctx $Ctx
                Clean-SingleFile "$env:SystemRoot\Logs\CBS\CBS.log" "CBS servicing log" -Ctx $Ctx
                Clean-SingleFile "$env:SystemRoot\Logs\DISM\dism.log" "DISM servicing log" -Ctx $Ctx
                Clean-FolderContents "$env:SystemDrive\inetpub\logs\LogFiles" "IIS Web Logs" -Recurse -Ctx $Ctx
            }
        }
        "chkCrashDumps" = @{
            Name     = "Crash Dumps & WER Error Reports"
            Category = "System"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans User/System CrashDumps, Minidump, MEMORY.DMP, and Windows Error Reporting (WER)."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning memory dumps and WER crash reports..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:LOCALAPPDATA\CrashDumps" "User Crash Dumps" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\Minidump" "System Minidumps" -Recurse -Ctx $Ctx
                Clean-SingleFile "$env:SystemRoot\MEMORY.DMP" "Full Memory Dump (MEMORY.DMP)" -Ctx $Ctx
                Clean-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\WER" "User WER reports" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\Microsoft\Windows\WER" "System WER reports" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\System32\config\systemprofile\AppData\Local\CrashDumps" "System Profile Dumps" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\CrashDumps") "CrashDumps: $($p.Name)" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\Windows\WER") "WER: $($p.Name)" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkDeliveryOpt" = @{
            Name     = "Delivery Optimization & Windows.old Residue"
            Category = "System"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Delivery Optimization cache, Windows.old, root setup .log files, and RetailDemo."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Delivery Optimization and previous installation backups..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization Cache" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemDrive\Windows.old" "Windows.old archive directory" -Recurse -Ctx $Ctx

                $rootLogs = Get-ChildItem -Path "$env:SystemDrive\*.log" -Force -ErrorAction SilentlyContinue
                if ($rootLogs -and $rootLogs.Count -gt 0) {
                    foreach ($f in $rootLogs) {
                        Clean-SingleFile $f.FullName "Root setup log: $($f.Name)" -Ctx $Ctx
                    }
                } else {
                    Write-WinSweepLog "Root setup logs: None found in $env:SystemDrive\" "SKIP" $Ctx.SyncState $Ctx.LogPath
                }

                Clean-FolderContents "$env:SystemRoot\System32\config\systemprofile\AppData\Local\Microsoft\Windows\RetailDemo" "Retail Demo Offline" -Recurse -Ctx $Ctx
            }
        }
        "chkSearchLogs" = @{
            Name     = "Windows Search Gather Logs"
            Category = "System"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Temporarily stops WSearch, cleans GatherLogs, and restarts WSearch."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Windows Search gather logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                if (-not $Ctx.DryRun) { Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue }
                Clean-FolderContents "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\GatherLogs" "Search Gather Logs" -Recurse -Ctx $Ctx
                if (-not $Ctx.DryRun) { Start-Service -Name WSearch -ErrorAction SilentlyContinue }
            }
        }
        "chkDismCleanup" = @{
            Name     = "DISM Component Store Cleanup (WinSxS)"
            Category = "System"
            Risk     = "Moderate"
            Default  = $false
            Tooltip  = "Runs Dism.exe /Online /Cleanup-Image /StartComponentCleanup to purge superseded Windows Update components. May take several minutes."
            Action   = {
                param([hashtable]$Ctx)
                if ($Ctx.DryRun) {
                    Write-WinSweepLog "[DRY RUN] Would run Dism.exe /Online /Cleanup-Image /StartComponentCleanup" "DRY" $Ctx.SyncState $Ctx.LogPath
                    return
                }
                Write-WinSweepLog "Running DISM StartComponentCleanup (may take a few minutes)..." "RUN" $Ctx.SyncState $Ctx.LogPath
                try {
                    $proc = Start-Process -FilePath "$env:SystemRoot\System32\Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -PassThru -ErrorAction Stop
                    while (-not $proc.HasExited) {
                        if (Test-CancelRequested -Ctx $Ctx) {
                            try { $proc.Kill() } catch {}
                            Write-WinSweepLog "DISM cleanup cancelled by user" "WARN" $Ctx.SyncState $Ctx.LogPath
                            return
                        }
                        Start-Sleep -Milliseconds 500
                    }
                    Write-WinSweepLog "DISM Component Store cleanup completed (ExitCode: $($proc.ExitCode))" "OK" $Ctx.SyncState $Ctx.LogPath
                    $Ctx.TotalCleaned++
                } catch {
                    Write-WinSweepLog "DISM cleanup failed: $_" "ERR" $Ctx.SyncState $Ctx.LogPath
                    $Ctx.TotalErrors++
                }
            }
        }

        # ======================================================================
        # CACHES (Temporary Files & Windows Caches)
        # ======================================================================
        "chkTempFiles" = @{
            Name     = "System & User Temp Files (%TEMP%)"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans %TEMP%, Windows\Temp, SystemTemp, LocalService/NetworkService Temp, and all user profile Temp folders."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning all user and system Temp folders..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents $env:TEMP "User Temp ($env:TEMP)" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\Temp" "System Temp ($env:SystemRoot\Temp)" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\SystemTemp" "SystemTemp" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:LOCALAPPDATA\Temp" "Local AppData Temp" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\Temp" "LocalService Temp" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Temp" "NetworkService Temp" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Temp") "Temp: $($p.Name)" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkPrefetch" = @{
            Name     = "Windows Prefetch Cache"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Windows\Prefetch execution cache."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Windows Prefetch execution cache..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:SystemRoot\Prefetch" "Prefetch Directory" -Recurse -Ctx $Ctx
            }
        }
        "chkWinUpdate" = @{
            Name     = "Windows Update Download Cache"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Stops wuauserv/bits/cryptSvc, cleans SoftwareDistribution\Download and PostRebootEventCache.V2, then restarts services."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Purging Windows Update download cache..." "RUN" $Ctx.SyncState $Ctx.LogPath
                if (-not $Ctx.DryRun) { Stop-Service -Name wuauserv,bits,cryptSvc -Force -ErrorAction SilentlyContinue }
                Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\Download" "Update Downloads" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:SystemRoot\SoftwareDistribution\PostRebootEventCache.V2" "WU Post-Reboot Cache" -Recurse -Ctx $Ctx
                if (-not $Ctx.DryRun) {
                    Start-Service -Name cryptSvc,bits,wuauserv -ErrorAction SilentlyContinue
                    Write-WinSweepLog "Windows Update services restarted" "OK" $Ctx.SyncState $Ctx.LogPath
                }
            }
        }
        "chkRecycleBin" = @{
            Name     = "Empty Recycle Bin (All Drives)"
            Category = "Caches"
            Risk     = "Moderate"
            Default  = $true
            Tooltip  = "Empties the Windows Recycle Bin across all fixed drives."
            Action   = {
                param([hashtable]$Ctx)
                if ($Ctx.DryRun) {
                    Write-WinSweepLog "[DRY RUN] Would empty Recycle Bin on all drives" "DRY" $Ctx.SyncState $Ctx.LogPath
                    return
                }
                Write-WinSweepLog "Emptying Recycle Bin on all drives..." "RUN" $Ctx.SyncState $Ctx.LogPath
                try {
                    Clear-RecycleBin -Force -ErrorAction Stop
                    Write-WinSweepLog "Recycle Bin purged successfully" "OK" $Ctx.SyncState $Ctx.LogPath
                    $Ctx.TotalCleaned++
                } catch {
                    Write-WinSweepLog "Recycle Bin already empty or in use" "SKIP" $Ctx.SyncState $Ctx.LogPath
                }
            }
        }
        "chkThumbIcons" = @{
            Name     = "Thumbnail & Icon Database Caches"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans thumbcache_*.db, iconcache_*.db, and IconCache.db for all user profiles."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning thumbnail and icon database files..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    $exp = Join-Path $p.FullName "AppData\Local\Microsoft\Windows\Explorer"
                    Clean-FolderContents $exp "Thumbnails ($($p.Name))" -Filter "thumbcache_*.db" -Ctx $Ctx
                    Clean-FolderContents $exp "IconCache DB ($($p.Name))" -Filter "iconcache_*.db" -Ctx $Ctx
                    Clean-SingleFile (Join-Path $p.FullName "AppData\Local\IconCache.db") "IconCache.db ($($p.Name))" -Ctx $Ctx
                }
            }
        }
        "chkFontCache" = @{
            Name     = "Windows Font Cache (Restarts service)"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $false
            Tooltip  = "Stops FontCache services, cleans FontCache files and FNTCACHE.DAT, then restarts FontCache."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning font cache services..." "RUN" $Ctx.SyncState $Ctx.LogPath
                if (-not $Ctx.DryRun) { Stop-Service -Name FontCache,FontCache3.0.0.0 -Force -ErrorAction SilentlyContinue }
                Clean-FolderContents "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache" "Font Cache files" -Recurse -Ctx $Ctx
                Clean-SingleFile "$env:SystemRoot\System32\FNTCACHE.DAT" "FNTCACHE.DAT" -Ctx $Ctx
                if (-not $Ctx.DryRun) { Start-Service -Name FontCache -ErrorAction SilentlyContinue }
            }
        }
        "chkInstallerCache" = @{
            Name     = "Orphaned Installer Patch Cache"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Windows\Installer\`$PatchCache`$\Managed."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Windows Installer patch cache..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents ($env:SystemRoot + '\Installer\$PatchCache$\Managed') "Installer Patch Cache" -Recurse -Ctx $Ctx
            }
        }
        "chkStoreCache" = @{
            Name     = "Microsoft Store & UWP LocalCache Residue"
            Category = "Caches"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Microsoft Store LocalCache temp files."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Microsoft Store LocalCache..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    $storeCache = Join-Path $p.FullName "AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
                    Clean-FolderContents $storeCache "MS Store Cache ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }

        # ======================================================================
        # GRAPHICS (GPU Shaders, Game Engines & Creative Media Caches)
        # ======================================================================
        "chkGpuShaders" = @{
            Name     = "GPU Driver Shaders (NVIDIA, AMD, Intel, DirectX, Vulkan)"
            Category = "Graphics"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans NVIDIA (DXCache, GLCache, NV_Cache, OptixCache, Downloader), AMD (DxCache, GLCache, VkCache, DxcCache, CN), Intel ShaderCache, DirectX Shader Cache, D3DSCache, and Vulkan cache."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Purging GPU DirectX, OpenGL, Vulkan, and OptiX shader caches..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:ProgramData\NVIDIA Corporation\NV_Cache" "NVIDIA NV_Cache" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:ProgramData\NVIDIA Corporation\Downloader" "NVIDIA Driver Downloader" -Recurse -Ctx $Ctx
                Clean-FolderContents "$env:TEMP\NVIDIA Corporation\NV_Cache" "NVIDIA Temp Cache" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\NVIDIA\DXCache") "NVIDIA DXCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\NVIDIA\GLCache") "NVIDIA GLCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\NVIDIA\OptixCache") "NVIDIA OptixCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache") "NVIDIA Driver DXCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\AMD\DxCache") "AMD DxCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\AMD\GLCache") "AMD GLCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\AMD\VkCache") "AMD VkCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\AMD\DxcCache") "AMD DxcCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\AMD\CN") "AMD Radeon CN Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Intel\ShaderCache") "Intel ShaderCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\LocalLow\Intel\ShaderCache") "Intel Low ShaderCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\D3DSCache") "Direct3D D3DSCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\DirectX Shader Cache") "Windows DirectX Shader Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\vulkan") "Vulkan Pipeline Cache ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkGameEngineShaders" = @{
            Name     = "3D & Game Shader Caches (Steam, Unreal, Unity, Blender)"
            Category = "Graphics"
            Risk     = "Moderate"
            Default  = $false
            Tooltip  = "Cleans Steam shadercache, Unreal Engine DerivedDataCache, Unity cache, and Blender cache. Games/editors will rebuild shaders on next launch."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning 3D engine and Steam shader caches..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "${env:ProgramFiles(x86)}\Steam\steamapps\shadercache" "Steam Shader Cache (x86)" -Recurse -Ctx $Ctx
                Clean-FolderContents "${env:ProgramFiles}\Steam\steamapps\shadercache" "Steam Shader Cache (x64)" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\UnrealEngine\Common\DerivedDataCache") "Unreal Engine DDC ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Unity\cache") "Unity Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    $blenderDir = Join-Path $p.FullName "AppData\Roaming\Blender Foundation\Blender"
                    if (Test-Path -LiteralPath $blenderDir) {
                        Get-ChildItem -LiteralPath $blenderDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            Clean-FolderContents (Join-Path $_.FullName "cache") "Blender $($_.Name) Cache ($($p.Name))" -Recurse -Ctx $Ctx
                        }
                    }
                }
            }
        }
        "chkCreativeMediaCache" = @{
            Name     = "Creative Media Caches (Adobe Media Cache, DaVinci Resolve)"
            Category = "Graphics"
            Risk     = "Moderate"
            Default  = $false
            Tooltip  = "Cleans Adobe Media Cache / Media Cache Files / Peak Files and DaVinci Resolve CacheClip."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Adobe & DaVinci Resolve media caches..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Adobe\Common\Media Cache") "Adobe Media Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Adobe\Common\Media Cache Files") "Adobe Media Cache Files ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Adobe\Common\Peak Files") "Adobe Peak Files ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "Videos\CacheClip") "DaVinci Resolve CacheClip ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }

        # ======================================================================
        # APPS (Desktop Apps, Dev Tools & Windows Utilities)
        # ======================================================================
        "chkOfficeTeams" = @{
            Name     = "Office, Teams, OneDrive & Steam Logs"
            Category = "Apps"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Cleans Office File Cache & OTele, Delivery Optimization user logs, Steam logs, OneDrive logs, and Teams logs/watchdog."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning Office, Teams, OneDrive, and Steam logs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "${env:ProgramFiles(x86)}\Steam\logs" "Steam Logs (x86)" -Recurse -Ctx $Ctx
                Clean-FolderContents "${env:ProgramFiles}\Steam\logs" "Steam Logs (x64)" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\Office\16.0\OfficeFileCache") "Office File Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\Office\OTele") "Office Telemetry ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs") "DO User Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\OneDrive\logs") "OneDrive Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Teams\logs") "Teams Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Teams\watchdog") "Teams Watchdog ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkDesktopApps" = @{
            Name     = "Desktop Apps & Gaming Launchers (Discord, Spotify, Epic, Riot)"
            Category = "Apps"
            Risk     = "Safe"
            Default  = $false
            Tooltip  = "Cleans Discord, Spotify, Slack, OBS logs, and Epic Games / Riot / Battle.net / EA web caches & logs (never game saves)."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning desktop app and launcher caches..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\discord\Cache") "Discord Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\discord\Code Cache") "Discord Code Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\discord\GPUCache") "Discord GPUCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Spotify\Storage") "Spotify Storage Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Slack\Cache") "Slack Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\obs-studio\logs") "OBS Studio Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\EpicGamesLauncher\Saved\webcache") "Epic Games WebCache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\EpicGamesLauncher\Saved\Logs") "Epic Games Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Riot Games\Riot Client\Logs") "Riot Client Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Battle.net\Logs") "Battle.net Logs ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkDevCaches" = @{
            Name     = "Developer Caches (pip, uv, npm, NuGet, Yarn, Gradle, Cargo)"
            Category = "Apps"
            Risk     = "Moderate"
            Default  = $false
            Tooltip  = "Cleans NuGet, pip, uv, npm, Yarn, Java Deployment, VS Packages/IntelliCode, Gradle caches, and Cargo registry cache."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning developer package and runtime caches..." "RUN" $Ctx.SyncState $Ctx.LogPath
                Clean-FolderContents "$env:TEMP\VSFeedbackIntelliCodeLogs" "VS IntelliCode Logs" -Recurse -Ctx $Ctx
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\NuGet\v3-cache") "NuGet v3 Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\NuGet\plugins-cache") "NuGet Plugins ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\pip\cache") "Python pip Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\uv\cache") "Python uv Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\npm-cache") "npm Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Yarn\Cache") "Yarn Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Sun\Java\Deployment\cache") "Java Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\Microsoft\VisualStudio\Packages\_Instances") "VS Packages ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName ".gradle\caches") "Gradle Caches ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName ".cargo\registry\cache") "Cargo Registry Cache ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkDnsCache" = @{
            Name     = "Flush Windows DNS Resolver Cache"
            Category = "Apps"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Runs Clear-DnsClientCache to flush local DNS entries."
            Action   = {
                param([hashtable]$Ctx)
                if ($Ctx.DryRun) {
                    Write-WinSweepLog "[DRY RUN] Would flush Windows DNS Client cache" "DRY" $Ctx.SyncState $Ctx.LogPath
                    return
                }
                Write-WinSweepLog "Flushing DNS Client cache..." "RUN" $Ctx.SyncState $Ctx.LogPath
                try {
                    Clear-DnsClientCache
                    Write-WinSweepLog "DNS cache flushed successfully" "OK" $Ctx.SyncState $Ctx.LogPath
                    $Ctx.TotalCleaned++
                } catch {
                    Write-WinSweepLog "DNS cache flush: $_" "ERR" $Ctx.SyncState $Ctx.LogPath
                }
            }
        }
        "chkCleanMgr" = @{
            Name     = "Automated Disk Cleanup (cleanmgr /sagerun)"
            Category = "Apps"
            Risk     = "Safe"
            Default  = $false
            Tooltip  = "Opt-in native Windows Disk Cleanup (cleanmgr.exe /sagerun:1000) with slow/redundant handlers (User file history, Update Cleanup, Internet caches) disabled."
            Action   = {
                param([hashtable]$Ctx)
                if ($Ctx.DryRun) {
                    Write-WinSweepLog "[DRY RUN] Would invoke fast cleanmgr.exe /sagerun:1000 (slow handlers skipped)" "DRY" $Ctx.SyncState $Ctx.LogPath
                    return
                }
                Write-WinSweepLog "Invoking fast native Windows Disk Cleanup..." "RUN" $Ctx.SyncState $Ctx.LogPath
                try {
                    $volKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                    $skipPattern = 'Internet|Temporary Internet|User file history|Update Cleanup|Previous Installations|Compress old files|Windows Defender|BranchCache|Content Indexer'
                    if (Test-Path $volKey) {
                        foreach ($k in (Get-ChildItem $volKey -ErrorAction SilentlyContinue)) {
                            $flag = if ($k.PSChildName -match $skipPattern) { 0 } else { 2 }
                            Set-ItemProperty -Path $k.PSPath -Name "StateFlags1000" -Value $flag -Type DWord -ErrorAction SilentlyContinue
                        }
                        $proc = Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:1000" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                        if ($proc) {
                            $timeoutSeconds = 30
                            $elapsed = 0
                            while (-not $proc.HasExited -and $elapsed -lt $timeoutSeconds) {
                                if (Test-CancelRequested -Ctx $Ctx) { break }
                                Start-Sleep -Milliseconds 500
                                $elapsed += 0.5
                            }
                            if ($proc.HasExited) {
                                Write-WinSweepLog "Native Disk Cleanup completed" "OK" $Ctx.SyncState $Ctx.LogPath
                            } else {
                                Write-WinSweepLog "Native Disk Cleanup continuing in background" "OK" $Ctx.SyncState $Ctx.LogPath
                            }
                            $Ctx.TotalCleaned++
                        }
                    }
                } catch {
                    Write-WinSweepLog "Disk Cleanup: $_" "SKIP" $Ctx.SyncState $Ctx.LogPath
                }
            }
        }

        # ======================================================================
        # AI & PRIVACY (AI Runtime Caches, AI Logs, AI Brain/Transcripts, Traces)
        # ======================================================================
        "chkAiRuntimeCaches" = @{
            Name     = "AI Runtime & Partial Blob Caches (Ollama partials, HF locks, Torch)"
            Category = "AI"
            Risk     = "Safe"
            Default  = $true
            Tooltip  = "Safely cleans incomplete Ollama *-partial blobs, Hugging Face .locks/*.incomplete, PyTorch hub checkpoints, Whisper, and ONNX Runtime caches without touching intact models."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning AI runtime temp caches and incomplete model blobs..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    $h = $p.FullName
                    Clean-FolderContents (Join-Path $h ".ollama\models\blobs") "Ollama Partial Blobs ($($p.Name))" -Filter "*-partial" -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".cache\huggingface\hub\.locks") "Hugging Face Locks ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".cache\huggingface\hub") "Hugging Face Incomplete Blobs ($($p.Name))" -Filter "*.incomplete" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".cache\torch\hub") "PyTorch Hub Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".cache\whisper") "Whisper Model Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Local\onnxruntime") "ONNX Runtime Cache ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkAiLogsOnly" = @{
            Name     = "AI Assistant Logs & App Caches (Preserves Brain & Chats)"
            Category = "AI"
            Risk     = "Safe"
            Default  = $false
            Tooltip  = "Cleans logs and Electron caches for Antigravity, Gemini, Ollama, Cursor, Claude Desktop, ChatGPT, Copilot, Claude Code debug, Codex logs, Windsurf logs, and Zed logs without deleting conversations."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning AI assistant logs and caches (preserving conversations/brain)..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    $h = $p.FullName
                    Clean-FolderContents (Join-Path $h ".gemini\antigravity-cli\logs") "Antigravity CLI Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".gemini\cache") "Gemini CLI Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".gemini\tmp") "Gemini CLI Temp ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".ollama\logs") "Ollama Service Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Local\Ollama\logs") "Ollama App Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Cursor\logs") "Cursor AI Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Claude\logs") "Claude Desktop Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Claude\Cache") "Claude Desktop Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Claude\Code Cache") "Claude Code Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\ChatGPT\Cache") "ChatGPT Desktop Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\ChatGPT\logs") "ChatGPT Desktop Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Local\github-copilot") "GitHub Copilot Cache ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".copilot\logs") "Copilot CLI Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".claude\debug") "Claude Code Debug Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".claude\shell-snapshots") "Claude Code Shell Snapshots ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".codex\log") "OpenAI Codex Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Windsurf\logs") "Windsurf Logs ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Local\Zed\logs") "Zed Logs ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkAiConversations" = @{
            Name     = "AI Conversations, Brain & Agent Transcripts"
            Category = "AI"
            Risk     = "Privacy"
            Default  = $false
            Tooltip  = "Deletes AI chat transcripts, agent brain/scratch, and session storage (Antigravity brain, Claude Code projects, Codex sessions, Windsurf memories, Cursor/Windsurf workspaceStorage, Cline/Roo, Copilot chatSessions, Aider, Continue, LM Studio, Jan, Zed). Preserves .gemini skills/plugins/rules."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Cleaning AI conversations, brain directories, and agent transcripts..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    $h = $p.FullName
                    # Antigravity brain (skills/plugins/rules in .gemini\config are untouched)
                    Clean-FolderContents (Join-Path $h ".gemini\antigravity-cli\brain") "Antigravity CLI Brain ($($p.Name))" -Recurse -Ctx $Ctx

                    # Claude Code transcripts & file-history
                    Clean-FolderContents (Join-Path $h ".claude\projects") "Claude Code Projects/Transcripts ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".claude\file-history") "Claude Code File History ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".claude\todos") "Claude Code Todos ($($p.Name))" -Recurse -Ctx $Ctx

                    # OpenAI Codex CLI sessions
                    Clean-FolderContents (Join-Path $h ".codex\sessions") "Codex CLI Sessions ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-SingleFile (Join-Path $h ".codex\history.jsonl") "Codex CLI History ($($p.Name))" -Ctx $Ctx

                    # Aider & Continue
                    Clean-SingleFile (Join-Path $h ".aider.chat.history.md") "Aider Chat History ($($p.Name))" -Ctx $Ctx
                    Clean-SingleFile (Join-Path $h ".aider.input.history") "Aider Input History ($($p.Name))" -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".continue\sessions") "Continue Sessions ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".continue\index") "Continue Code Index ($($p.Name))" -Recurse -Ctx $Ctx

                    # Cursor, Windsurf, VS Code AI Extensions
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Cursor\User\workspaceStorage") "Cursor Workspace Sessions ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h ".codeium\windsurf\memories") "Windsurf Memories ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Windsurf\User\workspaceStorage") "Windsurf Workspace Sessions ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Code\User\globalStorage\saoudrizwan.claude-dev") "Cline Extension Storage ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline") "Roo Code Extension Storage ($($p.Name))" -Recurse -Ctx $Ctx

                    $vsCodeWs = Join-Path $h "AppData\Roaming\Code\User\workspaceStorage"
                    if (Test-Path -LiteralPath $vsCodeWs) {
                        Get-ChildItem -LiteralPath $vsCodeWs -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                            $cs = Join-Path $_.FullName "chatSessions"
                            if (Test-Path -LiteralPath $cs) {
                                Clean-FolderContents $cs "VS Code Copilot Chat ($($p.Name))" -Recurse -Ctx $Ctx
                            }
                        }
                    }

                    # LM Studio, Jan, Zed
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\LM Studio\conversations") "LM Studio Conversations ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Roaming\Jan\data\threads") "Jan AI Threads ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $h "AppData\Local\Zed\conversations") "Zed AI Conversations ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkRecentFiles" = @{
            Name     = "Recent Files History & Jump Lists"
            Category = "AI"
            Risk     = "Privacy"
            Default  = $false
            Tooltip  = "Cleans Explorer Recent items, AutomaticDestinations, and CustomDestinations jump lists."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Clearing Explorer Recent Files and Jump Lists..." "RUN" $Ctx.SyncState $Ctx.LogPath
                foreach ($p in (Get-UserProfiles)) {
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent") "Recent Items ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations") "Auto JumpLists ($($p.Name))" -Recurse -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations") "Custom JumpLists ($($p.Name))" -Recurse -Ctx $Ctx
                }
            }
        }
        "chkOperationTraces" = @{
            Name     = "Windows Activity Traces (PS History, RunMRU, UserAssist, Clipboard)"
            Category = "AI"
            Risk     = "Privacy"
            Default  = $false
            Tooltip  = "Purges PowerShell ConsoleHost_history.txt, RunMRU, TypedPaths, UserAssist, ConnectedDevicesPlatform, Clipboard, and previous WinSweep logs."
            Action   = {
                param([hashtable]$Ctx)
                Write-WinSweepLog "Purging operational activity traces, command histories, and MRU caches..." "RUN" $Ctx.SyncState $Ctx.LogPath

                foreach ($p in (Get-UserProfiles)) {
                    $psHistory = Join-Path $p.FullName "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
                    Clean-SingleFile $psHistory "PowerShell Command History ($($p.Name))" -Ctx $Ctx
                    Clean-FolderContents (Join-Path $p.FullName "AppData\Local\ConnectedDevicesPlatform") "Activity History ($($p.Name))" -Recurse -Ctx $Ctx
                }

                if ($Ctx.DryRun) {
                    Write-WinSweepLog "[DRY RUN] Would clear PSReadLine history, RunMRU, TypedPaths, UserAssist, and Clipboard" "DRY" $Ctx.SyncState $Ctx.LogPath
                    return
                }

                try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch {}
                try { Clear-History -ErrorAction SilentlyContinue } catch {}

                foreach ($regDef in @(
                    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"; Label = "Windows Run dialog history (RunMRU)" },
                    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"; Label = "Explorer Address Bar Typed Paths" }
                )) {
                    try {
                        if (Test-Path $regDef.Path) {
                            $props = (Get-ItemProperty -Path $regDef.Path).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                            foreach ($prop in $props) {
                                Remove-ItemProperty -Path $regDef.Path -Name $prop.Name -Force -ErrorAction SilentlyContinue
                            }
                            Write-WinSweepLog "$($regDef.Label) cleared" "OK" $Ctx.SyncState $Ctx.LogPath
                            $Ctx.TotalCleaned++
                        }
                    } catch {
                        Write-WinSweepLog "$($regDef.Label): $_" "ERR" $Ctx.SyncState $Ctx.LogPath
                    }
                }

                try {
                    $userAssistKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
                    if (Test-Path $userAssistKey) {
                        Get-ChildItem -Path $userAssistKey -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                            $subProps = (Get-ItemProperty -Path $_.PSPath).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                            foreach ($sp in $subProps) {
                                Remove-ItemProperty -Path $_.PSPath -Name $sp.Name -Force -ErrorAction SilentlyContinue
                            }
                        }
                        Write-WinSweepLog "Windows UserAssist program execution traces cleared" "OK" $Ctx.SyncState $Ctx.LogPath
                        $Ctx.TotalCleaned++
                    }
                } catch {
                    Write-WinSweepLog "UserAssist clearing: $_" "ERR" $Ctx.SyncState $Ctx.LogPath
                }

                try {
                    [System.Windows.Clipboard]::Clear()
                    Write-WinSweepLog "Windows Clipboard history purged" "OK" $Ctx.SyncState $Ctx.LogPath
                    $Ctx.TotalCleaned++
                } catch {}

                if ($Ctx.LogDir -and (Test-Path -LiteralPath $Ctx.LogDir)) {
                    $oldLogs = Get-ChildItem -LiteralPath $Ctx.LogDir -Filter "*.log" -Force -ErrorAction SilentlyContinue |
                        Where-Object { -not $Ctx.LogPath -or $_.FullName -ne $Ctx.LogPath }
                    if ($oldLogs) {
                        $oldCount = $oldLogs.Count
                        $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
                        Write-WinSweepLog "Purged $oldCount previous cleanup session logs" "OK" $Ctx.SyncState $Ctx.LogPath
                        $Ctx.TotalCleaned++
                    }
                }
            }
        }

        # ======================================================================
        # CUSTOM USER PATHS
        # ======================================================================
        "chkCustomPaths" = @{
            Name     = "Custom Cleanup Folders (Configured in Settings)"
            Category = "Caches"
            Risk     = "Moderate"
            Default  = $false
            Tooltip  = "Cleans user-defined custom folders configured in the Settings & Automation tab."
            Action   = {
                param([hashtable]$Ctx)
                $customs = $Ctx.CustomCleanupPaths
                if (-not $customs -or $customs.Count -eq 0) {
                    Write-WinSweepLog "Custom Cleanup Folders (none configured in Settings)" "SKIP" $Ctx.SyncState $Ctx.LogPath
                    return
                }
                foreach ($cp in $customs) {
                    Clean-FolderContents $cp "Custom Path: $cp" -Recurse -Ctx $Ctx
                }
            }
        }
    }
}
