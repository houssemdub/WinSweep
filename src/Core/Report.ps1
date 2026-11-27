# WinSweep Organized Report Generator (Text Summary + HTML Report)

function New-WinSweepReportData {
    param(
        [string]$Mode,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [int]$ThreadsUsed,
        [long]$DriveFreeBefore,
        [long]$DriveFreeAfter,
        [array]$TaskResults
    )

    $duration = $EndTime - $StartTime
    $durStr = "{0}m {1}.{2}s" -f [int]$duration.TotalMinutes, $duration.Seconds, [math]::Floor($duration.Milliseconds / 100)

    $totalBytes  = [long]0
    $totalFiles  = 0
    $totalOps    = 0
    $totalErrors = 0
    $byCategory  = @{}

    foreach ($r in $TaskResults) {
        $totalBytes  += [long]$r.Bytes
        $totalFiles  += [int]$r.Files
        $totalOps    += [int]$r.Operations
        $totalErrors += [int]$r.Errors

        if (-not $byCategory.ContainsKey($r.Category)) {
            $byCategory[$r.Category] = @{
                Category   = $r.Category
                Bytes      = [long]0
                Files      = 0
                Operations = 0
                Tasks      = 0
            }
        }
        $byCategory[$r.Category].Bytes      += [long]$r.Bytes
        $byCategory[$r.Category].Files      += [int]$r.Files
        $byCategory[$r.Category].Operations += [int]$r.Operations
        $byCategory[$r.Category].Tasks++
    }

    $catSummary = @($byCategory.Values | ForEach-Object {
        [pscustomobject]@{
            Category    = $_.Category
            Bytes       = $_.Bytes
            SizeDisplay = Format-ByteSize -Bytes $_.Bytes
            Files       = $_.Files
            Operations  = $_.Operations
            Tasks       = $_.Tasks
        }
    } | Sort-Object Bytes -Descending)

    $topTasks = @($TaskResults | Where-Object { $_.Bytes -gt 0 } | Sort-Object Bytes -Descending | Select-Object -First 10)

    return [pscustomobject]@{
        Mode               = $Mode
        Timestamp          = $EndTime.ToString("yyyy-MM-dd HH:mm:ss")
        Computer           = $env:COMPUTERNAME
        User               = $env:USERNAME
        Duration           = $durStr
        ThreadsUsed        = $ThreadsUsed
        DriveFreeBefore    = $DriveFreeBefore
        DriveFreeAfter     = $DriveFreeAfter
        DriveBeforeDisplay = Format-ByteSize -Bytes $DriveFreeBefore
        DriveAfterDisplay  = Format-ByteSize -Bytes $DriveFreeAfter
        TotalBytes         = $totalBytes
        TotalDisplay       = Format-ByteSize -Bytes $totalBytes
        TotalFiles         = $totalFiles
        Operations         = $totalOps
        Errors             = $totalErrors
        CategoryBreakdown  = $catSummary
        TopRecoveries      = $topTasks
        TaskResults        = @($TaskResults)
    }
}

function Format-WinSweepTextSummary {
    param([pscustomobject]$Report)

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("================================================================================")
    [void]$sb.AppendLine("WINSWEEP v4.0 - ORGANIZED EXECUTION SUMMARY ($($Report.Mode))")
    [void]$sb.AppendLine("================================================================================")
    [void]$sb.AppendLine(("Timestamp      : {0}" -f $Report.Timestamp))
    [void]$sb.AppendLine(("Duration       : {0} ({1} worker threads)" -f $Report.Duration, $Report.ThreadsUsed))
    [void]$sb.AppendLine(("Total Space    : {0} ({1:N0} files, {2} operations)" -f $Report.TotalDisplay, $Report.TotalFiles, $Report.Operations))
    [void]$sb.AppendLine(("Drive {0} Free  : {1} -> {2}" -f $env:SystemDrive, $Report.DriveBeforeDisplay, $Report.DriveAfterDisplay))
    [void]$sb.AppendLine(("Errors         : {0}" -f $Report.Errors))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("-- CATEGORY BREAKDOWN ----------------------------------------------------------")
    foreach ($c in $Report.CategoryBreakdown) {
        [void]$sb.AppendLine(("  {0,-12} | {1,11} | {2,7:N0} files | {3} tasks" -f $c.Category, $c.SizeDisplay, $c.Files, $c.Tasks))
    }
    if ($Report.TopRecoveries -and $Report.TopRecoveries.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("-- TOP SPACE RECOVERIES --------------------------------------------------------")
        foreach ($t in $Report.TopRecoveries) {
            [void]$sb.AppendLine(("  {0,11} | {1,-10} | {2} ({3:N0} files, {4} ms)" -f $t.SizeDisplay, $t.Category, $t.TaskName, $t.Files, $t.DurationMs))
        }
    }
    [void]$sb.AppendLine("================================================================================")
    return $sb.ToString()
}

function Export-WinSweepHtmlReport {
    param(
        [pscustomobject]$Report,
        [string]$OutputPath
    )

    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    $esc = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

    $catRows = New-Object System.Text.StringBuilder
    $maxCat = [long]1
    foreach ($c in $Report.CategoryBreakdown) { if ($c.Bytes -gt $maxCat) { $maxCat = $c.Bytes } }
    foreach ($c in $Report.CategoryBreakdown) {
        $pct = [math]::Round(($c.Bytes / $maxCat) * 100, 1)
        [void]$catRows.AppendLine("<tr><td>$(& $esc $c.Category)</td><td><strong>$(& $esc $c.SizeDisplay)</strong></td><td>$($c.Files)</td><td><div class='bar-bg'><div class='bar-fill' style='width:${pct}%'></div></div></td></tr>")
    }

    $taskRows = New-Object System.Text.StringBuilder
    foreach ($t in ($Report.TaskResults | Sort-Object Bytes -Descending)) {
        $badgeCls = if ($t.Errors -gt 0) { "err" } elseif ($t.Bytes -gt 0) { "ok" } else { "skip" }
        $statusTxt = if ($t.Errors -gt 0) { "ERR" } elseif ($t.Bytes -gt 0) { $Report.Mode } else { "SKIP" }
        [void]$taskRows.AppendLine("<tr><td><span class='badge $badgeCls'>$statusTxt</span></td><td>$(& $esc $t.Category)</td><td>$(& $esc $t.TaskName)</td><td><strong>$(& $esc $t.SizeDisplay)</strong></td><td>$($t.Files)</td><td>$($t.DurationMs) ms</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>WinSweep Report - $($Report.Timestamp)</title>
<style>
  body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0F172A; color: #F8FAFC; margin: 0; padding: 28px; }
  .wrap { max-width: 1120px; margin: 0 auto; }
  h1 { color: #38BDF8; margin: 0 0 4px; font-size: 24px; }
  .sub { color: #94A3B8; font-size: 13px; margin-bottom: 20px; }
  .cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 22px; }
  .card { background: #1E293B; border: 1px solid #334155; border-radius: 8px; padding: 14px 16px; }
  .card .k { color: #94A3B8; font-size: 11px; text-transform: uppercase; letter-spacing: .5px; }
  .card .v { font-size: 22px; font-weight: 700; color: #4ADE80; margin-top: 4px; }
  .card .v.blue { color: #38BDF8; }
  .panel { background: #1E293B; border: 1px solid #334155; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
  h2 { font-size: 14px; color: #38BDF8; text-transform: uppercase; letter-spacing: .5px; margin: 0 0 12px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #334155; }
  th { color: #94A3B8; font-size: 11px; text-transform: uppercase; }
  .bar-bg { background: #0F172A; height: 8px; border-radius: 4px; width: 180px; overflow: hidden; }
  .bar-fill { background: linear-gradient(90deg, #38BDF8, #4ADE80); height: 100%; }
  .badge { padding: 2px 7px; border-radius: 4px; font-size: 10px; font-weight: 700; }
  .badge.ok { background: #065F46; color: #6EE7B7; }
  .badge.skip { background: #334155; color: #CBD5E1; }
  .badge.err { background: #7F1D1D; color: #FCA5A5; }
</style>
</head>
<body>
<div class="wrap">
  <h1>WINSWEEP v4.0 EXECUTION REPORT ($($Report.Mode))</h1>
  <div class="sub">Host: $(& $esc $Report.Computer) | User: $(& $esc $Report.User) | Date: $(& $esc $Report.Timestamp) | Threads: $($Report.ThreadsUsed)</div>

  <div class="cards">
    <div class="card"><div class="k">Space Freed / Recoverable</div><div class="v">$(& $esc $Report.TotalDisplay)</div></div>
    <div class="card"><div class="k">Files Processed</div><div class="v blue">$($Report.TotalFiles)</div></div>
    <div class="card"><div class="k">Duration</div><div class="v blue">$(& $esc $Report.Duration)</div></div>
    <div class="card"><div class="k">Drive $($env:SystemDrive) Free</div><div class="v">$(& $esc $Report.DriveAfterDisplay)</div></div>
  </div>

  <div class="panel">
    <h2>Category Breakdown</h2>
    <table>
      <thead><tr><th>Category</th><th>Space</th><th>Files</th><th>Distribution</th></tr></thead>
      <tbody>$($catRows.ToString())</tbody>
    </table>
  </div>

  <div class="panel">
    <h2>Task Details (Sorted by Size)</h2>
    <table>
      <thead><tr><th>Status</th><th>Category</th><th>Task</th><th>Space</th><th>Files</th><th>Time</th></tr></thead>
      <tbody>$($taskRows.ToString())</tbody>
    </table>
  </div>
</div>
</body>
</html>
"@
    [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
    return $OutputPath
}
