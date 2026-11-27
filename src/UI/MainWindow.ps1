# WinSweep WPF UI Controller

function Start-WinSweepGui {
    param(
        [string]$RootDir,
        [string]$LogDir,
        [hashtable]$Config,
        [System.Collections.Specialized.OrderedDictionary]$Tasks
    )

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

    $xamlPath = Join-Path $RootDir "src\UI\MainWindow.xaml"
    [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $window.Width  = $Config.WindowWidth
    $window.Height = $Config.WindowHeight

    # Map named controls
    $controls = @{}
    foreach ($name in @(
        "lblDriveInfo", "lblAgeBadge", "txtSearch", "lblSearchPlaceholder",
        "btnPresetAll", "btnPresetNone", "btnPresetRecommended", "btnPresetSecurityOnly", "btnPresetGraphicsOnly", "btnPresetPrivacyOnly",
        "pnlLeftColumn", "pnlRightColumn",
        "btnScanModels", "btnSelectAllModels", "btnDeselectAllModels", "btnDeleteModels", "lblModelSummary", "dgModels",
        "txtOlderThanDays", "txtLogRetentionDays", "chkRestorePoint", "btnSaveSettings", "btnScheduleWeekly", "btnRemoveSchedule",
        "lstExclusions", "txtNewExclusion", "btnAddExclusion", "btnRemoveExclusion",
        "lstCustomPaths", "txtNewCustomPath", "btnAddCustomPath", "btnRemoveCustomPath",
        "lstCustomModels", "txtNewCustomModel", "btnAddCustomModel", "btnRemoveCustomModel",
        "cmbLogFilter", "btnCopySummary", "btnViewHtmlReport", "btnExportJson", "btnViewCurrentLog", "btnOpenLogsFolder", "btnClearLog", "txtLog",
        "pbProgress", "lblStatus", "lblFreed", "lblCleaned", "btnScan", "btnRun", "btnCancel", "btnExit"
    )) {
        $controls[$name] = $window.FindName($name)
    }

    # Helper to refresh System Drive info
    $updateDriveInfo = {
        try {
            $sysDrive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
            if ($sysDrive) {
                $freeGB  = [math]::Round($sysDrive.Free / 1GB, 1)
                $totalGB = [math]::Round(($sysDrive.Free + $sysDrive.Used) / 1GB, 1)
                $controls.lblDriveInfo.Text = "Drive $($env:SystemDrive) $freeGB GB free / $totalGB GB"
            }
        } catch {}
    }
    & $updateDriveInfo

    # Build Category Cards Dynamically
    $categoryMeta = [ordered]@{
        "Security" = @{ Title = "[SECURITY] ANTIVIRUS AND SECURITY LOGS"; Color = "#F43F5E"; Col = "Left" }
        "System"   = @{ Title = "[SYSTEM] WINDOWS SYSTEM AND EVENT LOGS"; Color = "#38BDF8"; Col = "Left" }
        "Caches"   = @{ Title = "[CACHES] TEMPORARY FILES AND CACHES"; Color = "#F59E0B"; Col = "Left" }
        "Graphics" = @{ Title = "[GRAPHICS] GPU SHADERS AND MEDIA CACHES"; Color = "#10B981"; Col = "Right" }
        "Apps"     = @{ Title = "[APPS] DESKTOP APPS, DEV TOOLS AND NETWORK"; Color = "#60A5FA"; Col = "Right" }
        "AI"       = @{ Title = "[AI & PRIVACY] AI LOGS, BRAIN AND TRACES"; Color = "#A855F7"; Col = "Right" }
    }

    $chkControls     = @{}
    $groupControls   = @{}
    $sizeLabels      = @{}
    $taskRows        = @{}
    $brushConv       = New-Object System.Windows.Media.BrushConverter

    foreach ($catKey in $categoryMeta.Keys) {
        $meta = $categoryMeta[$catKey]
        $border = New-Object System.Windows.Controls.Border
        $border.Background = $brushConv.ConvertFromString("#1E293B")
        $border.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $border.Padding = New-Object System.Windows.Thickness(12)
        $border.Margin = New-Object System.Windows.Thickness(0,0,0,10)
        $border.BorderBrush = $brushConv.ConvertFromString("#334155")
        $border.BorderThickness = New-Object System.Windows.Thickness(1)

        $stack = New-Object System.Windows.Controls.StackPanel

        $dock = New-Object System.Windows.Controls.DockPanel
        $dock.Margin = New-Object System.Windows.Thickness(0,0,0,6)

        $hdr = New-Object System.Windows.Controls.TextBlock
        $hdr.Text = $meta.Title
        $hdr.FontWeight = "Bold"
        $hdr.FontSize = 12.5
        $hdr.Foreground = $brushConv.ConvertFromString($meta.Color)
        [System.Windows.Controls.DockPanel]::SetDock($hdr, "Left")

        $grpChk = New-Object System.Windows.Controls.CheckBox
        $grpChk.Content = "Select Group"
        $grpChk.FontSize = 11
        $grpChk.Foreground = $brushConv.ConvertFromString("#94A3B8")
        $grpChk.HorizontalAlignment = "Right"
        $grpChk.Tag = $catKey
        $groupControls[$catKey] = $grpChk

        $grpChk.Add_Click({
            param($s, $e)
            $c = $s.Tag
            $st = [bool]$s.IsChecked
            foreach ($k in $Tasks.Keys) {
                if ($Tasks[$k].Category -eq $c -and $chkControls.ContainsKey($k)) {
                    $chkControls[$k].IsChecked = $st
                }
            }
        })

        $dock.Children.Add($hdr) | Out-Null
        $dock.Children.Add($grpChk) | Out-Null
        $stack.Children.Add($dock) | Out-Null

        $sep = New-Object System.Windows.Controls.Separator
        $sep.Background = $brushConv.ConvertFromString("#334155")
        $sep.Margin = New-Object System.Windows.Thickness(0,0,0,6)
        $stack.Children.Add($sep) | Out-Null

        foreach ($taskKey in $Tasks.Keys) {
            $t = $Tasks[$taskKey]
            if ($t.Category -ne $catKey) { continue }

            $rowGrid = New-Object System.Windows.Controls.Grid
            $rowGrid.Margin = New-Object System.Windows.Thickness(0,1,0,1)
            $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = "*"
            $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = "Auto"
            $col3 = New-Object System.Windows.Controls.ColumnDefinition; $col3.Width = "Auto"
            $rowGrid.ColumnDefinitions.Add($col1)
            $rowGrid.ColumnDefinitions.Add($col2)
            $rowGrid.ColumnDefinitions.Add($col3)

            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $t.Name
            $cb.ToolTip = $t.Tooltip
            $isChecked = if ($Config.SelectedTasks.ContainsKey($taskKey)) { $Config.SelectedTasks[$taskKey] } else { $t.Default }
            $cb.IsChecked = [bool]$isChecked
            [System.Windows.Controls.Grid]::SetColumn($cb, 0)

            $riskBadge = New-Object System.Windows.Controls.Border
            $riskBadge.CornerRadius = New-Object System.Windows.CornerRadius(3)
            $riskBadge.Padding = New-Object System.Windows.Thickness(5,1,5,1)
            $riskBadge.Margin = New-Object System.Windows.Thickness(6,2,4,2)
            $riskBadge.VerticalAlignment = "Center"
            $riskColor = switch ($t.Risk) {
                "Safe"     { "#065F46" }
                "Moderate" { "#92400E" }
                "Privacy"  { "#5B21B6" }
                default    { "#334155" }
            }
            $riskBadge.Background = $brushConv.ConvertFromString($riskColor)
            $riskTxt = New-Object System.Windows.Controls.TextBlock
            $riskTxt.Text = $t.Risk.ToUpper()
            $riskTxt.FontSize = 9.5
            $riskTxt.FontWeight = "Bold"
            $riskTxt.Foreground = $brushConv.ConvertFromString("#F8FAFC")
            $riskBadge.Child = $riskTxt
            [System.Windows.Controls.Grid]::SetColumn($riskBadge, 1)

            $szLbl = New-Object System.Windows.Controls.TextBlock
            $szLbl.Text = ""
            $szLbl.FontSize = 11
            $szLbl.Foreground = $brushConv.ConvertFromString("#4ADE80")
            $szLbl.VerticalAlignment = "Center"
            $szLbl.MinWidth = 65
            $szLbl.TextAlignment = "Right"
            [System.Windows.Controls.Grid]::SetColumn($szLbl, 2)

            $rowGrid.Children.Add($cb) | Out-Null
            $rowGrid.Children.Add($riskBadge) | Out-Null
            $rowGrid.Children.Add($szLbl) | Out-Null

            $stack.Children.Add($rowGrid) | Out-Null

            $chkControls[$taskKey] = $cb
            $sizeLabels[$taskKey]  = $szLbl
            $taskRows[$taskKey]    = $rowGrid
        }

        $border.Child = $stack
        if ($meta.Col -eq "Left") {
            $controls.pnlLeftColumn.Children.Add($border) | Out-Null
        } else {
            $controls.pnlRightColumn.Children.Add($border) | Out-Null
        }
    }

    # Search Filter
    $controls.txtSearch.Add_TextChanged({
        $q = $controls.txtSearch.Text.Trim()
        $controls.lblSearchPlaceholder.Visibility = if ([string]::IsNullOrEmpty($q)) { "Visible" } else { "Collapsed" }
        foreach ($k in $Tasks.Keys) {
            $t = $Tasks[$k]
            $match = [string]::IsNullOrEmpty($q) -or ($t.Name -like "*$q*") -or ($t.Tooltip -like "*$q*") -or ($t.Category -like "*$q*")
            $taskRows[$k].Visibility = if ($match) { "Visible" } else { "Collapsed" }
        }
    })

    # Presets
    $setChecks = {
        param([scriptblock]$Pred)
        foreach ($k in $Tasks.Keys) {
            $chkControls[$k].IsChecked = [bool](& $Pred $k $Tasks[$k])
        }
    }
    $controls.btnPresetAll.Add_Click({ & $setChecks { $true } })
    $controls.btnPresetNone.Add_Click({ & $setChecks { $false } })
    $controls.btnPresetRecommended.Add_Click({ & $setChecks { param($k,$t) $t.Default } })
    $controls.btnPresetSecurityOnly.Add_Click({ & $setChecks { param($k,$t) $t.Category -eq "Security" } })
    $controls.btnPresetGraphicsOnly.Add_Click({ & $setChecks { param($k,$t) $t.Category -in @("Graphics", "Caches") } })
    $controls.btnPresetPrivacyOnly.Add_Click({ & $setChecks { param($k,$t) $t.Category -eq "AI" -or $k -in @("chkThumbIcons") } })

    # Log Console State & Filtering
    $allLogEntries = New-Object System.Collections.Generic.List[object]
    $renderLogs = {
        $filterIdx = $controls.cmbLogFilter.SelectedIndex
        $sb = New-Object System.Text.StringBuilder
        foreach ($entry in $allLogEntries) {
            $show = switch ($filterIdx) {
                1 { $entry.Type -in @("OK", "DONE") }
                2 { $entry.Type -eq "DRY" }
                3 { $entry.Type -eq "ERR" }
                4 { $entry.Type -eq "SKIP" }
                default { $true }
            }
            if ($show) { [void]$sb.AppendLine($entry.Text) }
        }
        $controls.txtLog.Text = $sb.ToString()
        $controls.txtLog.ScrollToEnd()
    }
    $controls.cmbLogFilter.Add_SelectionChanged({ & $renderLogs })
    $controls.btnClearLog.Add_Click({ $allLogEntries.Clear(); $controls.txtLog.Clear() })
    $controls.btnCopySummary.Add_Click({
        try { [System.Windows.Clipboard]::SetText($controls.txtLog.Text) } catch {}
    })

    # Populate Settings UI
    $controls.txtOlderThanDays.Text    = "$($Config.OlderThanDays)"
    $controls.txtLogRetentionDays.Text = "$($Config.LogRetentionDays)"
    $controls.chkRestorePoint.IsChecked = [bool]$Config.CreateRestorePoint
    $controls.lblAgeBadge.Text = if ($Config.OlderThanDays -gt 0) { "Age Filter: > $($Config.OlderThanDays) days" } else { "Age Filter: All Files" }

    foreach ($ex in $Config.Exclusions)         { $controls.lstExclusions.Items.Add($ex) | Out-Null }
    foreach ($cp in $Config.CustomCleanupPaths) { $controls.lstCustomPaths.Items.Add($cp) | Out-Null }
    foreach ($cm in $Config.CustomModelPaths)   { $controls.lstCustomModels.Items.Add($cm) | Out-Null }

    $wireListBox = {
        param($txtBox, $listBox, $btnAdd, $btnRem)
        $btnAdd.Add_Click({
            $val = $txtBox.Text.Trim()
            if (-not [string]::IsNullOrWhiteSpace($val) -and -not $listBox.Items.Contains($val)) {
                $listBox.Items.Add($val) | Out-Null
                $txtBox.Clear()
            }
        }.GetNewClosure())
        $btnRem.Add_Click({
            if ($listBox.SelectedItem) { $listBox.Items.Remove($listBox.SelectedItem) }
        }.GetNewClosure())
    }
    & $wireListBox $controls.txtNewExclusion $controls.lstExclusions $controls.btnAddExclusion $controls.btnRemoveExclusion
    & $wireListBox $controls.txtNewCustomPath $controls.lstCustomPaths $controls.btnAddCustomPath $controls.btnRemoveCustomPath
    & $wireListBox $controls.txtNewCustomModel $controls.lstCustomModels $controls.btnAddCustomModel $controls.btnRemoveCustomModel

    $readCurrentConfig = {
        $age = 0; [void][int]::TryParse($controls.txtOlderThanDays.Text, [ref]$age)
        $ret = 30; [void][int]::TryParse($controls.txtLogRetentionDays.Text, [ref]$ret)
        $Config.OlderThanDays      = [math]::Max(0, $age)
        $Config.LogRetentionDays   = [math]::Max(1, $ret)
        $Config.CreateRestorePoint = [bool]$controls.chkRestorePoint.IsChecked
        $Config.Exclusions         = @($controls.lstExclusions.Items)
        $Config.CustomCleanupPaths = @($controls.lstCustomPaths.Items)
        $Config.CustomModelPaths   = @($controls.lstCustomModels.Items)
        $Config.WindowWidth        = [int]$window.Width
        $Config.WindowHeight       = [int]$window.Height
        $sel = @{}
        foreach ($k in $Tasks.Keys) { $sel[$k] = [bool]$chkControls[$k].IsChecked }
        $Config.SelectedTasks = $sel
        $controls.lblAgeBadge.Text = if ($Config.OlderThanDays -gt 0) { "Age Filter: > $($Config.OlderThanDays) days" } else { "Age Filter: All Files" }
        return $Config
    }

    $controls.btnSaveSettings.Add_Click({
        $cfg = & $readCurrentConfig
        Save-WinSweepConfig -RootDir $RootDir -Config $cfg
        [System.Windows.MessageBox]::Show("Settings saved to config.json.", "Settings Saved", "OK", "Information") | Out-Null
    })

    $controls.btnScheduleWeekly.Add_Click({
        try {
            $scriptFile = Join-Path $RootDir "WinSweep.ps1"
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" -NoGui -Preset Recommended -Silent"
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName "WinSweepWeeklyCleanup" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
            [System.Windows.MessageBox]::Show("Registered weekly Sunday 3:00 AM scheduled task 'WinSweepWeeklyCleanup'.", "Task Scheduled", "OK", "Information") | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("Failed to register scheduled task: $_", "Error", "OK", "Error") | Out-Null
        }
    })

    $controls.btnRemoveSchedule.Add_Click({
        try {
            Unregister-ScheduledTask -TaskName "WinSweepWeeklyCleanup" -Confirm:$false -ErrorAction Stop
            [System.Windows.MessageBox]::Show("Removed scheduled task 'WinSweepWeeklyCleanup'.", "Task Removed", "OK", "Information") | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("Scheduled task not found or could not be removed.", "Notice", "OK", "Information") | Out-Null
        }
    })

    # AI Models & Blobs Tab
    $script:ScannedModels = @()
    $controls.btnScanModels.Add_Click({
        $cfg = & $readCurrentConfig
        $controls.lblModelSummary.Text = "Scanning LLM models and blobs..."
        $script:ScannedModels = Get-WinSweepModels -CustomModelPaths $cfg.CustomModelPaths
        $controls.dgModels.ItemsSource = $script:ScannedModels
        $totalBytes = [long]0
        foreach ($m in $script:ScannedModels) { $totalBytes += $m.SizeBytes }
        $controls.lblModelSummary.Text = "Found $($script:ScannedModels.Count) models/blobs totaling $(Format-ByteSize -Bytes $totalBytes)."
    })
    $controls.btnSelectAllModels.Add_Click({
        foreach ($m in $script:ScannedModels) { $m.Selected = $true }
        $controls.dgModels.Items.Refresh()
    })
    $controls.btnDeselectAllModels.Add_Click({
        foreach ($m in $script:ScannedModels) { $m.Selected = $false }
        $controls.dgModels.Items.Refresh()
    })
    $controls.btnDeleteModels.Add_Click({
        $toDel = @($script:ScannedModels | Where-Object { $_.Selected })
        if ($toDel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Select at least one model or blob to delete.", "No Models Selected", "OK", "Warning") | Out-Null
            return
        }
        $bytes = [long]0
        foreach ($m in $toDel) { $bytes += $m.SizeBytes }
        $ans = [System.Windows.MessageBox]::Show("Permanently delete $($toDel.Count) selected model(s)/blob(s) freeing ~$(Format-ByteSize -Bytes $bytes)?", "Confirm Model Deletion", "YesNo", "Warning")
        if ($ans -eq "Yes") {
            $res = Remove-WinSweepModels -ModelsToDelete $toDel
            $allLogEntries.Add([pscustomobject]@{ Type = "OK"; Text = "[$(Get-Date -Format 'HH:mm:ss')] [OK] Deleted $($res.DeletedCount) LLM models/blobs - Freed $(Format-ByteSize -Bytes $res.FreedBytes)" })
            & $renderLogs
            & $updateDriveInfo
            $controls.btnScanModels.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        }
    })

    # Async Multi-Threaded RunspacePool Engine for Scan & Cleanup
    $script:CurrentLogPath    = $null
    $script:LastRunReport     = $null
    $script:LastHtmlReportPath = $null

    $controls.btnOpenLogsFolder.Add_Click({
        if (Test-Path -LiteralPath $LogDir) { Start-Process explorer.exe -ArgumentList "`"$LogDir`"" }
    })
    $controls.btnViewCurrentLog.Add_Click({
        if ($script:CurrentLogPath -and (Test-Path -LiteralPath $script:CurrentLogPath)) {
            Start-Process notepad.exe -ArgumentList "`"$script:CurrentLogPath`""
        } else {
            [System.Windows.MessageBox]::Show("No log file created yet.", "Log Notice", "OK", "Information") | Out-Null
        }
    })
    $controls.btnViewHtmlReport.Add_Click({
        if ($script:LastHtmlReportPath -and (Test-Path -LiteralPath $script:LastHtmlReportPath)) {
            Start-Process $script:LastHtmlReportPath
        } else {
            [System.Windows.MessageBox]::Show("Run a Scan or Cleanup first to generate an HTML report.", "Report Notice", "OK", "Information") | Out-Null
        }
    })
    $controls.btnExportJson.Add_Click({
        if (-not $script:LastRunReport) {
            [System.Windows.MessageBox]::Show("Run a Scan or Cleanup first to export a JSON report.", "Export Notice", "OK", "Information") | Out-Null
            return
        }
        $jsonPath = Join-Path $LogDir ("Report_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + ".json")
        $script:LastRunReport | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
        [System.Windows.MessageBox]::Show("Report exported to:`n$jsonPath", "Export Complete", "OK", "Information") | Out-Null
    })

    $startWorker = {
        param([bool]$IsDryRun)

        $selected = @()
        foreach ($k in $Tasks.Keys) {
            if ($chkControls[$k].IsChecked) { $selected += $k }
        }
        if ($selected.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please check at least one task.", "No Items Selected", "OK", "Warning") | Out-Null
            return
        }

        $cfg = & $readCurrentConfig
        $modeLabel = if ($IsDryRun) { "SCAN" } else { "CLEANUP" }
        $script:CurrentLogPath = Initialize-WinSweepLog -LogDir $LogDir -Mode $modeLabel -RetentionDays $cfg.LogRetentionDays
        $driveFreeBefore = [long]0
        try {
            $sd = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
            if ($sd) { $driveFreeBefore = [long]$sd.Free }
        } catch {}

        if (-not $IsDryRun -and $cfg.CreateRestorePoint) {
            $allLogEntries.Add([pscustomobject]@{ Type = "INFO"; Text = "[$(Get-Date -Format 'HH:mm:ss')] [INFO] Creating System Restore Point..." })
            & $renderLogs
            try { Checkpoint-Computer -Description "WinSweep Pre-Cleanup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue } catch {}
        }

        $controls.btnScan.IsEnabled   = $false
        $controls.btnRun.IsEnabled    = $false
        $controls.btnCancel.IsEnabled = $true
        $controls.pbProgress.Value    = 0
        $controls.pbProgress.Maximum  = $selected.Count
        foreach ($k in $sizeLabels.Keys) { $sizeLabels[$k].Text = "" }

        $threadCount = [math]::Min([math]::Max([Environment]::ProcessorCount, 2), 6)
        $sync = [hashtable]::Synchronized(@{
            LogQueue        = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
            LogLock         = New-Object System.Object
            ResultLock      = New-Object System.Object
            TaskSizes       = [hashtable]::Synchronized(@{})
            TaskResults     = New-Object System.Collections.ArrayList
            FailedItems     = New-Object System.Collections.ArrayList
            CurrentLogPath  = $script:CurrentLogPath
            CancelRequested = $false
            TotalFreed      = [long]0
            TotalCleaned    = 0
            TotalErrors     = 0
            CompletedTasks  = 0
            CurrentTaskName = "Running across $threadCount threads..."
            StartTime       = Get-Date
            ThreadsUsed     = $threadCount
            DriveFreeBefore = $driveFreeBefore
        })

        $pool = [runspacefactory]::CreateRunspacePool(1, $threadCount)
        $pool.ApartmentState = "STA"
        $pool.Open()

        $jobs = New-Object System.Collections.Generic.List[object]
        foreach ($tk in $selected) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript({
                param($RootDir, $LogDir, $TaskKey, $Cfg, $IsDryRun, $Sync)
                if ($Sync.CancelRequested) { return }

                . (Join-Path $RootDir "src\Core\Logger.ps1")
                . (Join-Path $RootDir "src\Core\Cleaner.ps1")
                . (Join-Path $RootDir "src\Tasks\TaskRegistry.ps1")
                $allTasks = Get-WinSweepTasks
                $task = $allTasks[$TaskKey]
                $Sync.CurrentTaskName = $task.Name

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $ctx = @{
                    SyncState          = $Sync
                    DryRun             = $IsDryRun
                    OlderThanDays      = $Cfg.OlderThanDays
                    Exclusions         = $Cfg.Exclusions
                    CustomCleanupPaths = $Cfg.CustomCleanupPaths
                    LogPath            = $Sync.CurrentLogPath
                    LogDir             = $LogDir
                    TotalFreed         = [long]0
                    TotalCleaned       = 0
                    TotalErrors        = 0
                    TaskBytes          = [long]0
                    TaskFiles          = 0
                    FailedItems        = (New-Object System.Collections.ArrayList)
                }

                try {
                    & $task.Action $ctx
                } catch {
                    Write-WinSweepLog "Error in $($task.Name): $_" "ERR" $Sync $Sync.CurrentLogPath
                    $ctx.TotalErrors++
                }
                $sw.Stop()

                $resObj = [pscustomobject]@{
                    TaskKey     = $TaskKey
                    TaskName    = $task.Name
                    Category    = $task.Category
                    Bytes       = [long]$ctx.TaskBytes
                    SizeDisplay = Format-ByteSize -Bytes $ctx.TaskBytes
                    Files       = [int]$ctx.TaskFiles
                    Operations  = [int]$ctx.TotalCleaned
                    Errors      = [int]$ctx.TotalErrors
                    DurationMs  = [int]$sw.ElapsedMilliseconds
                }

                [System.Threading.Monitor]::Enter($Sync.ResultLock)
                try {
                    $Sync.TaskSizes[$TaskKey] = $ctx.TaskBytes
                    $Sync.TotalFreed += $ctx.TotalFreed
                    $Sync.TotalCleaned += $ctx.TotalCleaned
                    $Sync.TotalErrors += $ctx.TotalErrors
                    $Sync.CompletedTasks++
                    [void]$Sync.TaskResults.Add($resObj)
                    foreach ($fi in $ctx.FailedItems) { [void]$Sync.FailedItems.Add($fi) }
                } finally {
                    [System.Threading.Monitor]::Exit($Sync.ResultLock)
                }
            }).AddArgument($RootDir).AddArgument($LogDir).AddArgument($tk).AddArgument($cfg).AddArgument($IsDryRun).AddArgument($sync)

            $handle = $ps.BeginInvoke()
            $jobs.Add(@{ PS = $ps; Handle = $handle })
        }

        $controls.btnCancel.Tag = $sync
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(100)
        $timer.Tag = @{ Sync = $sync; Pool = $pool; Jobs = $jobs; IsDryRun = $IsDryRun; Selected = $selected }
        $timer.Add_Tick({
            param($s, $e)
            $d = $s.Tag
            $sy = $d.Sync

            $added = $false
            while ($sy.LogQueue.Count -gt 0) {
                $item = $sy.LogQueue.Dequeue()
                $allLogEntries.Add($item)
                $added = $true
            }
            if ($added) { & $renderLogs }

            foreach ($tk in @($sy.TaskSizes.Keys)) {
                $b = [long]$sy.TaskSizes[$tk]
                if ($b -gt 0 -and $sizeLabels.ContainsKey($tk)) {
                    $sizeLabels[$tk].Text = "~" + (Format-ByteSize -Bytes $b)
                }
            }

            $controls.pbProgress.Value = $sy.CompletedTasks
            $controls.lblFreed.Text    = Format-ByteSize -Bytes $sy.TotalFreed
            $controls.lblCleaned.Text  = "$($sy.TotalCleaned)"
            $prefix = if ($d.IsDryRun) { "Scanning" } else { "Cleaning" }
            $controls.lblStatus.Text   = "$prefix ($($sy.CompletedTasks)/$($d.Selected.Count)) [$($sy.ThreadsUsed) threads]: $($sy.CurrentTaskName)"

            $allDone = $true
            foreach ($j in $d.Jobs) {
                if (-not $j.Handle.IsCompleted) { $allDone = $false; break }
            }

            if ($allDone) {
                $s.Stop()
                foreach ($j in $d.Jobs) {
                    try { $j.PS.EndInvoke($j.Handle) } catch {}
                    $j.PS.Dispose()
                }
                $d.Pool.Close()
                $d.Pool.Dispose()

                $endTime = Get-Date
                $driveFreeAfter = $sy.DriveFreeBefore
                try {
                    $sd = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
                    if ($sd) { $driveFreeAfter = [long]$sd.Free }
                } catch {}

                $modeStr = if ($d.IsDryRun) { "DRY RUN" } else { "CLEANUP" }
                $report = New-WinSweepReportData -Mode $modeStr -StartTime $sy.StartTime -EndTime $endTime `
                    -ThreadsUsed $sy.ThreadsUsed -DriveFreeBefore $sy.DriveFreeBefore -DriveFreeAfter $driveFreeAfter `
                    -TaskResults @($sy.TaskResults) -FailedItems @($sy.FailedItems)
                $script:LastRunReport = $report

                $summaryText = Format-WinSweepTextSummary -Report $report
                Add-Content -LiteralPath $sy.CurrentLogPath -Value $summaryText -Encoding UTF8 -ErrorAction SilentlyContinue
                $allLogEntries.Add([pscustomobject]@{ Type = "DONE"; Text = $summaryText.Trim() })
                & $renderLogs

                $htmlFile = Join-Path $LogDir ("Report_" + $endTime.ToString('yyyy-MM-dd_HH-mm-ss') + ".html")
                $script:LastHtmlReportPath = Export-WinSweepHtmlReport -Report $report -OutputPath $htmlFile

                $verb = if ($d.IsDryRun) { "Scan complete" } else { "Cleanup complete" }
                $controls.lblStatus.Text = "$verb! $($report.Operations) ops, $($report.TotalDisplay) ($($report.TotalFiles) files) in $($report.Duration) [$($sy.ThreadsUsed) threads]."
                $controls.btnScan.IsEnabled   = $true
                $controls.btnRun.IsEnabled    = $true
                $controls.btnCancel.IsEnabled = $false
                & $updateDriveInfo
            }
        })
        $timer.Start()
    }

    $controls.btnScan.Add_Click({ & $startWorker $true })
    $controls.btnRun.Add_Click({ & $startWorker $false })
    $controls.btnCancel.Add_Click({
        if ($controls.btnCancel.Tag) {
            $controls.btnCancel.Tag.CancelRequested = $true
            $controls.btnCancel.IsEnabled = $false
            $controls.lblStatus.Text = "Cancelling after current operation..."
        }
    })
    $controls.btnExit.Add_Click({ $window.Close() })

    $allLogEntries.Add([pscustomobject]@{ Type = "READY"; Text = "[$(Get-Date -Format 'HH:mm:ss')] [READY] WinSweep v4.0 ready. Use 'SCAN (DRY RUN)' to preview or 'RUN SELECTED CLEANUP'." })
    & $renderLogs

    $window.ShowDialog() | Out-Null
}
