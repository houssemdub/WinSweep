# WinSweep Core Configuration Module

function Get-DefaultWinSweepConfig {
    return @{
        Version               = "4.0"
        OlderThanDays         = 0
        LogRetentionDays      = 30
        CreateRestorePoint    = $false
        Exclusions            = @()
        CustomCleanupPaths    = @()
        CustomModelPaths      = @()
        SelectedTasks         = @{}
        WindowWidth           = 1080
        WindowHeight          = 860
    }
}

function Get-WinSweepConfigPath {
    param([string]$RootDir)
    return (Join-Path $RootDir "config.json")
}

function Load-WinSweepConfig {
    param([string]$RootDir)
    $config = Get-DefaultWinSweepConfig
    $path = Get-WinSweepConfigPath -RootDir $RootDir
    if (-not (Test-Path -LiteralPath $path)) {
        return $config
    }

    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $config }
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop

        if ($null -ne $parsed.OlderThanDays)      { $config.OlderThanDays = [int]$parsed.OlderThanDays }
        if ($null -ne $parsed.LogRetentionDays)   { $config.LogRetentionDays = [int]$parsed.LogRetentionDays }
        if ($null -ne $parsed.CreateRestorePoint) { $config.CreateRestorePoint = [bool]$parsed.CreateRestorePoint }
        if ($null -ne $parsed.WindowWidth -and $parsed.WindowWidth -ge 880)   { $config.WindowWidth = [int]$parsed.WindowWidth }
        if ($null -ne $parsed.WindowHeight -and $parsed.WindowHeight -ge 680) { $config.WindowHeight = [int]$parsed.WindowHeight }

        if ($null -ne $parsed.Exclusions) {
            $config.Exclusions = @($parsed.Exclusions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($null -ne $parsed.CustomCleanupPaths) {
            $config.CustomCleanupPaths = @($parsed.CustomCleanupPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($null -ne $parsed.CustomModelPaths) {
            $config.CustomModelPaths = @($parsed.CustomModelPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($null -ne $parsed.SelectedTasks) {
            $sel = @{}
            foreach ($prop in $parsed.SelectedTasks.PSObject.Properties) {
                $sel[$prop.Name] = [bool]$prop.Value
            }
            $config.SelectedTasks = $sel
        }
    } catch {
        # Fallback to defaults if config.json is corrupted
    }
    return $config
}

function Save-WinSweepConfig {
    param(
        [string]$RootDir,
        [hashtable]$Config
    )
    $path = Get-WinSweepConfigPath -RootDir $RootDir
    $json = $Config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
}
