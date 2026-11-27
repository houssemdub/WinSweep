# WinSweep Automated Test Suite
$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot

$passed = 0
$failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "=== 1. PowerShell Syntax Validation ===" -ForegroundColor Cyan
$psFiles = Get-ChildItem -Path $rootDir -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notlike "*\Logs\*" }
foreach ($f in $psFiles) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    Assert-True ($errs.Count -eq 0) "Syntax valid: $($f.Name)"
}

Write-Host "=== 2. XAML Parsing Validation ===" -ForegroundColor Cyan
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$xamlPath = Join-Path $rootDir "src\UI\MainWindow.xaml"
try {
    [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $win = [Windows.Markup.XamlReader]::Load($reader)
    Assert-True ($null -ne $win) "MainWindow.xaml loads cleanly"
    $win.Close()
} catch {
    Assert-True $false "MainWindow.xaml failed to load: $_"
}

Write-Host "=== 3. Core Modules & Task Registry ===" -ForegroundColor Cyan
. (Join-Path $rootDir "src\Core\Config.ps1")
. (Join-Path $rootDir "src\Core\Logger.ps1")
. (Join-Path $rootDir "src\Core\Cleaner.ps1")
. (Join-Path $rootDir "src\Core\ModelScanner.ps1")
. (Join-Path $rootDir "src\Core\Report.ps1")
. (Join-Path $rootDir "src\Tasks\TaskRegistry.ps1")

$tasks = Get-WinSweepTasks
Assert-True ($tasks.Count -ge 28) "TaskRegistry loaded $($tasks.Count) tasks"
Assert-True ($tasks.Contains("chkGpuShaders") -and $tasks.Contains("chkGameEngineShaders") -and $tasks.Contains("chkAiRuntimeCaches") -and $tasks.Contains("chkAiConversations")) "New Graphics & AI tasks present"
Assert-True (-not $tasks["chkCleanMgr"].Default) "chkCleanMgr is opt-in (Default = false)"

Write-Host "=== 4. Safety Guards & Exclusions ===" -ForegroundColor Cyan
Assert-True (Test-IsProtectedRoot "C:\") "Protects C:\"
Assert-True (Test-IsProtectedRoot $env:SystemRoot) "Protects Windows root"
Assert-True (-not (Test-IsProtectedRoot "C:\Temp\MyCache")) "Allows normal subfolder"
Assert-True (Test-IsExcludedPath "C:\Users\Test\keep\file.log" @("C:\Users\Test\keep")) "Exclusion matches subfolder"
Assert-True (-not (Test-IsExcludedPath "C:\Users\Test\other\file.log" @("C:\Users\Test\keep"))) "Non-excluded path allowed"

Write-Host "=== 5. Config Roundtrip ===" -ForegroundColor Cyan
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("WinSweepTest_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    $cfg = Get-DefaultWinSweepConfig
    $cfg.OlderThanDays = 7
    $cfg.Exclusions = @("C:\KeepMe")
    Save-WinSweepConfig -RootDir $sandbox -Config $cfg
    $loaded = Load-WinSweepConfig -RootDir $sandbox
    Assert-True ($loaded.OlderThanDays -eq 7) "Config OlderThanDays persisted"
    Assert-True ($loaded.Exclusions -contains "C:\KeepMe") "Config Exclusions persisted"

    Write-Host "=== 6. Dry-Run & Age Filter Sandbox ===" -ForegroundColor Cyan
    $targetDir = Join-Path $sandbox "CacheTarget"
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $oldFile = Join-Path $targetDir "old.log"
    $newFile = Join-Path $targetDir "new.log"
    [System.IO.File]::WriteAllBytes($oldFile, (New-Object byte[] 2048))
    [System.IO.File]::WriteAllBytes($newFile, (New-Object byte[] 1024))
    (Get-Item $oldFile).LastWriteTime = (Get-Date).AddDays(-10)

    # Dry run with age filter 5 days -> should count only old.log (2048 bytes) and delete nothing
    $ctxDry = @{ DryRun = $true; OlderThanDays = 5; Exclusions = @(); TotalFreed = [long]0; TotalCleaned = 0; TotalErrors = 0; TaskBytes = [long]0 }
    Clean-FolderContents -Path $targetDir -Label "Sandbox DryRun" -Recurse -Ctx $ctxDry
    Assert-True ($ctxDry.TotalFreed -eq 2048) "DryRun counted exact 2048 bytes for old file"
    Assert-True ((Test-Path $oldFile) -and (Test-Path $newFile)) "DryRun deleted nothing"

    # Actual run with age filter 5 days -> deletes old.log, keeps new.log
    $ctxReal = @{ DryRun = $false; OlderThanDays = 5; Exclusions = @(); TotalFreed = [long]0; TotalCleaned = 0; TotalErrors = 0; TaskBytes = [long]0 }
    Clean-FolderContents -Path $targetDir -Label "Sandbox Real" -Recurse -Ctx $ctxReal
    Assert-True ($ctxReal.TotalFreed -eq 2048) "Actual run freed 2048 bytes"
    Assert-True ((-not (Test-Path $oldFile)) -and (Test-Path $newFile)) "Age filter deleted old file and preserved recent file"

    Write-Host "=== 7. Custom Model Scanner ===" -ForegroundColor Cyan
    $modelDir = Join-Path $sandbox "Models"
    New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
    $fakeModel = Join-Path $modelDir "test-model.gguf"
    [System.IO.File]::WriteAllBytes($fakeModel, (New-Object byte[] (2MB)))
    $found = @(Get-WinSweepModels -CustomModelPaths @($modelDir) | Where-Object { $_.Provider -eq "Custom" })
    Assert-True ($found.Count -eq 1 -and $found[0].ModelName -eq "test-model.gguf") "ModelScanner detected custom 2MB model"

    Write-Host "=== 8. Organized Text & HTML Report Generation ===" -ForegroundColor Cyan
    $now = Get-Date
    $rep = New-WinSweepReportData -Mode "DRY RUN" -StartTime $now.AddSeconds(-2) -EndTime $now -ThreadsUsed 4 `
        -DriveFreeBefore 100GB -DriveFreeAfter 102GB -TaskResults @(
            [pscustomobject]@{ TaskKey="chkGpuShaders"; TaskName="GPU Shaders"; Category="Graphics"; Bytes=[long]2GB; SizeDisplay="2.00 GB"; Files=120; Operations=1; Errors=0; DurationMs=340 }
        )
    $txtRep = Format-WinSweepTextSummary -Report $rep
    $htmlOut = Join-Path $sandbox "test_report.html"
    [void](Export-WinSweepHtmlReport -Report $rep -OutputPath $htmlOut)
    Assert-True ($txtRep -match "CATEGORY BREAKDOWN" -and $txtRep -match "TOP SPACE RECOVERIES") "Text report contains organized sections"
    Assert-True ((Test-Path $htmlOut) -and ((Get-Content $htmlOut -Raw) -match "WINSWEEP v4.0 EXECUTION REPORT")) "HTML report generated cleanly"
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nTest Summary: $passed passed, $failed failed" -ForegroundColor Cyan
if ($failed -gt 0) { exit 1 }
exit 0
