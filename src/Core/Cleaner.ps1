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

function Get-FriendlyDeleteError {
    param($ErrorRecord)
    $msg = if ($ErrorRecord -and $ErrorRecord.Exception) { $ErrorRecord.Exception.Message } else { "$ErrorRecord" }
    if ($msg -match 'being used by another process|sharing violation') { return "Locked / in use by another process" }
    if ($msg -match 'Access to the path.*is denied|UnauthorizedAccess') { return "Access denied (protected or elevated process)" }
    if ($msg -match 'PathTooLong|too long') { return "Path exceeds Windows length limit" }
    if ($msg -match 'read-only') { return "File is read-only or protected" }
    return $msg
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
                $Ctx.TaskFiles += $filesToProcess.Count
                $Ctx.TotalFreed += $freedBytes
                $Ctx.TotalCleaned++
            }
            Write-WinSweepLog "[DRY RUN] $Label - Would free ~$sizeStr ($($filesToProcess.Count) files)" "DRY" $sync $logPath
            return
        }

        # Actual deletion: track per-file success and exact failure reasons
        $actualFreedBytes = [long]0
        $deletedCount     = 0
        $failedInFolder   = 0

        foreach ($f in $filesToProcess) {
            if (Test-CancelRequested -Ctx $Ctx) { return }
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $actualFreedBytes += [long]$f.Length
                $deletedCount++
            } catch {
                $reason = Get-FriendlyDeleteError -ErrorRecord $_
                $failedInFolder++
                if ($Ctx) {
                    $Ctx.TotalErrors++
                    if ($null -ne $Ctx.FailedItems) {
                        [void]$Ctx.FailedItems.Add([pscustomobject]@{
                            Task        = $Label
                            Path        = $f.FullName
                            SizeBytes   = [long]$f.Length
                            SizeDisplay = Format-ByteSize -Bytes $f.Length
                            Reason      = $reason
                        })
                    }
                }
                if ($failedInFolder -le 5) {
                    Write-WinSweepLog "Could not delete $($f.Name): $reason" "WARN" $sync $logPath
                }
            }
        }
        if ($failedInFolder -gt 5) {
            Write-WinSweepLog "$Label`: $($failedInFolder - 5) more locked/failed files (see Report for full list)" "WARN" $sync $logPath
        }

        if (-not $cutoff) {
            # Remove subdirectories deepest-first
            $dirsToProcess | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
                Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        $actualSizeStr = Format-ByteSize -Bytes $actualFreedBytes
        if ($Ctx) {
            $Ctx.TaskBytes += $actualFreedBytes
            $Ctx.TaskFiles += $deletedCount
            $Ctx.TotalFreed += $actualFreedBytes
            $Ctx.TotalCleaned++
        }
        Write-WinSweepLog "$Label - Freed ~$actualSizeStr ($deletedCount/$($filesToProcess.Count) files)" "OK" $sync $logPath
    } catch {
        $reason = Get-FriendlyDeleteError -ErrorRecord $_
        if ($Ctx) {
            $Ctx.TotalErrors++
            if ($null -ne $Ctx.FailedItems) {
                [void]$Ctx.FailedItems.Add([pscustomobject]@{
                    Task        = $Label
                    Path        = $Path
                    SizeBytes   = if ($size) { [long]$size } else { [long]0 }
                    SizeDisplay = if ($size) { Format-ByteSize -Bytes $size } else { "0 B" }
                    Reason      = $reason
                })
            }
        }
        Write-WinSweepLog "$Label failed ($Path): $reason" "ERR" $sync $logPath
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
                $Ctx.TaskFiles += 1
                $Ctx.TotalFreed += $size
                $Ctx.TotalCleaned++
            }
            Write-WinSweepLog "[DRY RUN] $Label - Would free ~$sizeStr" "DRY" $sync $logPath
            return
        }

        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($Ctx) {
            $Ctx.TaskBytes += $size
            $Ctx.TaskFiles += 1
            $Ctx.TotalFreed += $size
            $Ctx.TotalCleaned++
        }
        Write-WinSweepLog "$Label - Freed ~$sizeStr" "OK" $sync $logPath
    } catch {
        $reason = Get-FriendlyDeleteError -ErrorRecord $_
        if ($Ctx) {
            $Ctx.TotalErrors++
            if ($null -ne $Ctx.FailedItems) {
                [void]$Ctx.FailedItems.Add([pscustomobject]@{
                    Task        = $Label
                    Path        = $Path
                    SizeBytes   = if ($size) { [long]$size } else { [long]0 }
                    SizeDisplay = if ($size) { Format-ByteSize -Bytes $size } else { "0 B" }
                    Reason      = $reason
                })
            }
        }
        Write-WinSweepLog "$Label failed ($Path): $reason" "ERR" $sync $logPath
    }
}
