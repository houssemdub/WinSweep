# WinSweep Core Cleaner Engine

function Get-UserProfiles {
    Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
}

function Format-ByteSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Test-IsProtectedRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $true }
    $trimmed = $Path.TrimEnd('\', '/')
    # Never allow scanning/deleting a drive root (e.g. C:, C:\) or Windows/ProgramFiles/Users root itself
    if ($trimmed -match '^[a-zA-Z]:$') { return $true }
    $protected = @(
        $env:SystemRoot.TrimEnd('\'),
        $env:ProgramFiles.TrimEnd('\'),
        "${env:ProgramFiles(x86)}".TrimEnd('\'),
        $env:ProgramData.TrimEnd('\'),
        "$env:SystemDrive\Users"
    )
    foreach ($p in $protected) {
        if ($p -and ($trimmed -ieq $p)) { return $true }
    }
    return $false
}

function Test-IsExcludedPath {
    param(
        [string]$TargetPath,
        [string[]]$Exclusions
    )
    if (-not $Exclusions -or $Exclusions.Count -eq 0) { return $false }
    foreach ($ex in $Exclusions) {
        if ([string]::IsNullOrWhiteSpace($ex)) { continue }
        $normEx = $ex.Trim()
        if ($TargetPath -ieq $normEx -or $TargetPath -like "$normEx\*" -or $TargetPath -like "*$normEx*") {
            return $true
        }
    }
    return $false
}

function Test-CancelRequested {
    param([hashtable]$Ctx)
    if ($Ctx -and $Ctx.SyncState -and $Ctx.SyncState.CancelRequested) {
        return $true
    }
    return $false
}

function Clean-FolderContents {
    param(
        [string]$Path,
        [string]$Label,
        [string]$Filter = '*',
        [switch]$Recurse,
        [hashtable]$Ctx = $null
    )

    if (Test-CancelRequested -Ctx $Ctx) { return }

    $sync    = if ($Ctx) { $Ctx.SyncState } else { $null }
    $dryRun  = if ($Ctx) { [bool]$Ctx.DryRun } else { $false }
    $ageDays = if ($Ctx) { [int]$Ctx.OlderThanDays } else { 0 }
    $excls   = if ($Ctx) { $Ctx.Exclusions } else { @() }
    $logPath = if ($Ctx) { $Ctx.LogPath } else { $null }

    if (Test-IsProtectedRoot -Path $Path) {
        Write-WinSweepLog "$Label (Refusing protected root directory: $Path)" "SKIP" $sync $logPath
        return
    }

    if (Test-IsExcludedPath -TargetPath $Path -Exclusions $excls) {
        Write-WinSweepLog "$Label (Excluded by user rule: $Path)" "SKIP" $sync $logPath
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WinSweepLog "$Label (Path not found: $Path)" "SKIP" $sync $logPath
        return
    }

    try {
        $items = if ($Recurse) {
            Get-ChildItem -LiteralPath $Path -Filter $Filter -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem -LiteralPath $Path -Filter $Filter -Force -ErrorAction SilentlyContinue
        }

        if (-not $items -or $items.Count -eq 0) {
            Write-WinSweepLog "$Label (0 items)" "SKIP" $sync $logPath
            return
        }

        # Filter out excluded items and apply age filter to files
        $cutoff = if ($ageDays -gt 0) { (Get-Date).AddDays(-$ageDays) } else { $null }
        $filesToProcess = New-Object System.Collections.Generic.List[object]
        $dirsToProcess  = New-Object System.Collections.Generic.List[object]
        $freedBytes     = [long]0

        foreach ($item in $items) {
            if (Test-IsExcludedPath -TargetPath $item.FullName -Exclusions $excls) { continue }
            if ($item.PSIsContainer) {
                $dirsToProcess.Add($item)
            } else {
                if ($cutoff -and $item.LastWriteTime -gt $cutoff) { continue }
                $freedBytes += $item.Length
                $filesToProcess.Add($item)
            }
        }

        if ($filesToProcess.Count -eq 0 -and ($cutoff -or $dirsToProcess.Count -eq 0)) {
            Write-WinSweepLog "$Label (0 matching items)" "SKIP" $sync $logPath
            return
        }

        $sizeStr = Format-ByteSize -Bytes $freedBytes
        if ($dryRun) {
            if ($Ctx) {
                $Ctx.TaskBytes += $freedBytes
                $Ctx.TotalFreed += $freedBytes
                $Ctx.TotalCleaned++
            }
            Write-WinSweepLog "[DRY RUN] $Label - Would free ~$sizeStr ($($filesToProcess.Count) files)" "DRY" $sync $logPath
            return
        }

        # Actual deletion: delete files first, then empty dirs if no age cutoff
        foreach ($f in $filesToProcess) {
            if (Test-CancelRequested -Ctx $Ctx) { return }
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        }
        if (-not $cutoff) {
            # Remove subdirectories deepest-first
            $dirsToProcess | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        if ($Ctx) {
            $Ctx.TaskBytes += $freedBytes
            $Ctx.TotalFreed += $freedBytes
            $Ctx.TotalCleaned++
        }
        Write-WinSweepLog "$Label - Freed ~$sizeStr ($($filesToProcess.Count) files)" "OK" $sync $logPath
    } catch {
        if ($Ctx) { $Ctx.TotalErrors++ }
        Write-WinSweepLog "$Label failed: $_" "ERR" $sync $logPath
    }
}

function Clean-SingleFile {
    param(
        [string]$Path,
        [string]$Label,
        [hashtable]$Ctx = $null
    )

    if (Test-CancelRequested -Ctx $Ctx) { return }

    $sync    = if ($Ctx) { $Ctx.SyncState } else { $null }
    $dryRun  = if ($Ctx) { [bool]$Ctx.DryRun } else { $false }
    $ageDays = if ($Ctx) { [int]$Ctx.OlderThanDays } else { 0 }
    $excls   = if ($Ctx) { $Ctx.Exclusions } else { @() }
    $logPath = if ($Ctx) { $Ctx.LogPath } else { $null }

    if (Test-IsExcludedPath -TargetPath $Path -Exclusions $excls) {
        Write-WinSweepLog "$Label (Excluded by user rule)" "SKIP" $sync $logPath
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WinSweepLog "$Label (File not found)" "SKIP" $sync $logPath
        return
    }

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($ageDays -gt 0 -and $item.LastWriteTime -gt (Get-Date).AddDays(-$ageDays)) {
            Write-WinSweepLog "$Label (Skipped due to age filter < $ageDays days)" "SKIP" $sync $logPath
            return
        }

        $size = [long]$item.Length
        $sizeStr = Format-ByteSize -Bytes $size

        if ($dryRun) {
            if ($Ctx) {
                $Ctx.TaskBytes += $size
                $Ctx.TotalFreed += $size
                $Ctx.TotalCleaned++
            }
            Write-WinSweepLog "[DRY RUN] $Label - Would free ~$sizeStr" "DRY" $sync $logPath
            return
        }

        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($Ctx) {
            $Ctx.TaskBytes += $size
            $Ctx.TotalFreed += $size
            $Ctx.TotalCleaned++
        }
        Write-WinSweepLog "$Label - Freed ~$sizeStr" "OK" $sync $logPath
    } catch {
        if ($Ctx) { $Ctx.TotalErrors++ }
        Write-WinSweepLog "$Label failed: $_" "ERR" $sync $logPath
    }
}
