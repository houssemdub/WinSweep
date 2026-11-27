# WinSweep LLM Model & Blob Scanner Module

function Get-DirectoryByteSize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [long]0 }
    $sum = [long]0
    try {
        Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $sum += $_.Length
        }
    } catch {}
    return $sum
}

function Get-WinSweepModels {
    param(
        [string[]]$CustomModelPaths = @()
    )

    $results = New-Object System.Collections.Generic.List[object]
    $profiles = Get-UserProfiles

    foreach ($p in $profiles) {
        $homeDir = $p.FullName

        # 1. Ollama Models (manifests + blobs or direct blob scan)
        $ollamaRoot = Join-Path $homeDir ".ollama\models"
        if (Test-Path -LiteralPath $ollamaRoot) {
            $manifestsDir = Join-Path $ollamaRoot "manifests"
            $blobsDir     = Join-Path $ollamaRoot "blobs"
            $mappedBlobs  = @{}

            if (Test-Path -LiteralPath $manifestsDir) {
                Get-ChildItem -LiteralPath $manifestsDir -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $json = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                        $modelSize = [long]0
                        $blobPaths = New-Object System.Collections.Generic.List[string]

                        if ($json.config -and $json.config.digest) {
                            $d = $json.config.digest -replace ':', '-'
                            $bp = Join-Path $blobsDir $d
                            if (Test-Path -LiteralPath $bp) {
                                $modelSize += (Get-Item -LiteralPath $bp -Force).Length
                                $blobPaths.Add($bp)
                                $mappedBlobs[$d] = $true
                            }
                        }
                        if ($json.layers) {
                            foreach ($layer in $json.layers) {
                                if ($layer.digest) {
                                    $d = $layer.digest -replace ':', '-'
                                    $bp = Join-Path $blobsDir $d
                                    if (Test-Path -LiteralPath $bp) {
                                        $modelSize += (Get-Item -LiteralPath $bp -Force).Length
                                        $blobPaths.Add($bp)
                                        $mappedBlobs[$d] = $true
                                    }
                                }
                            }
                        }

                        $relName = $_.FullName.Substring($manifestsDir.Length).TrimStart('\') -replace '\\', '/'
                        $results.Add([pscustomobject]@{
                            Selected     = $false
                            Provider     = "Ollama"
                            ModelName    = $relName
                            SizeBytes    = $modelSize
                            SizeDisplay  = Format-ByteSize -Bytes $modelSize
                            LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                            PrimaryPath  = $_.FullName
                            ExtraPaths   = @($blobPaths)
                            User         = $p.Name
                        })
                    } catch {}
                }
            }

            # Also surface unreferenced / orphaned blobs in Ollama
            if (Test-Path -LiteralPath $blobsDir) {
                Get-ChildItem -LiteralPath $blobsDir -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $mappedBlobs.ContainsKey($_.Name)) {
                        $results.Add([pscustomobject]@{
                            Selected     = $false
                            Provider     = "Ollama (Orphan/Partial Blob)"
                            ModelName    = $_.Name
                            SizeBytes    = [long]$_.Length
                            SizeDisplay  = Format-ByteSize -Bytes $_.Length
                            LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                            PrimaryPath  = $_.FullName
                            ExtraPaths   = @()
                            User         = $p.Name
                        })
                    }
                }
            }
        }

        # 2. Hugging Face Hub Models
        $hfHub = Join-Path $homeDir ".cache\huggingface\hub"
        if (Test-Path -LiteralPath $hfHub) {
            Get-ChildItem -LiteralPath $hfHub -Directory -Filter "models--*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $sz = Get-DirectoryByteSize -Path $_.FullName
                $pretty = ($_.Name -replace '^models--', '') -replace '--', '/'
                $results.Add([pscustomobject]@{
                    Selected     = $false
                    Provider     = "Hugging Face"
                    ModelName    = $pretty
                    SizeBytes    = $sz
                    SizeDisplay  = Format-ByteSize -Bytes $sz
                    LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                    PrimaryPath  = $_.FullName
                    ExtraPaths   = @()
                    User         = $p.Name
                })
            }
        }

        # 3. LM Studio Models
        foreach ($lmSub in @(".lmstudio\models", ".cache\lm-studio\models")) {
            $lmPath = Join-Path $homeDir $lmSub
            if (Test-Path -LiteralPath $lmPath) {
                Get-ChildItem -LiteralPath $lmPath -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $sz = Get-DirectoryByteSize -Path $_.FullName
                    if ($sz -gt 0) {
                        $results.Add([pscustomobject]@{
                            Selected     = $false
                            Provider     = "LM Studio"
                            ModelName    = $_.Name
                            SizeBytes    = $sz
                            SizeDisplay  = Format-ByteSize -Bytes $sz
                            LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                            PrimaryPath  = $_.FullName
                            ExtraPaths   = @()
                            User         = $p.Name
                        })
                    }
                }
            }
        }

        # 4. GPT4All Models
        $gpt4all = Join-Path $homeDir "AppData\Local\nomic.ai\GPT4All"
        if (Test-Path -LiteralPath $gpt4all) {
            Get-ChildItem -LiteralPath $gpt4all -File -Filter "*.gguf" -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $results.Add([pscustomobject]@{
                    Selected     = $false
                    Provider     = "GPT4All"
                    ModelName    = $_.Name
                    SizeBytes    = [long]$_.Length
                    SizeDisplay  = Format-ByteSize -Bytes $_.Length
                    LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                    PrimaryPath  = $_.FullName
                    ExtraPaths   = @()
                    User         = $p.Name
                })
            }
        }

        # 5. Jan AI Models
        foreach ($janSub in @("jan\models", "AppData\Roaming\Jan\data\models")) {
            $janPath = Join-Path $homeDir $janSub
            if (Test-Path -LiteralPath $janPath) {
                Get-ChildItem -LiteralPath $janPath -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $sz = Get-DirectoryByteSize -Path $_.FullName
                    if ($sz -gt 0) {
                        $results.Add([pscustomobject]@{
                            Selected     = $false
                            Provider     = "Jan AI"
                            ModelName    = $_.Name
                            SizeBytes    = $sz
                            SizeDisplay  = Format-ByteSize -Bytes $sz
                            LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                            PrimaryPath  = $_.FullName
                            ExtraPaths   = @()
                            User         = $p.Name
                        })
                    }
                }
            }
        }
    }

    # 6. User-configured Custom Model Directories (e.g., ComfyUI / Stable Diffusion)
    foreach ($customDir in $CustomModelPaths) {
        if ([string]::IsNullOrWhiteSpace($customDir) -or -not (Test-Path -LiteralPath $customDir)) { continue }
        Get-ChildItem -LiteralPath $customDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSIsContainer) {
                $sz = Get-DirectoryByteSize -Path $_.FullName
            } else {
                $sz = [long]$_.Length
            }
            if ($sz -gt 1MB) {
                $results.Add([pscustomobject]@{
                    Selected     = $false
                    Provider     = "Custom"
                    ModelName    = $_.Name
                    SizeBytes    = $sz
                    SizeDisplay  = Format-ByteSize -Bytes $sz
                    LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd')
                    PrimaryPath  = $_.FullName
                    ExtraPaths   = @()
                    User         = "Custom"
                })
            }
        }
    }

    return @($results | Sort-Object SizeBytes -Descending)
}

function Remove-WinSweepModels {
    param(
        [array]$ModelsToDelete
    )
    $freed = [long]0
    $deletedCount = 0
    foreach ($m in $ModelsToDelete) {
        try {
            if ($m.PrimaryPath -and (Test-Path -LiteralPath $m.PrimaryPath)) {
                Remove-Item -LiteralPath $m.PrimaryPath -Force -Recurse -ErrorAction Stop
            }
            if ($m.ExtraPaths) {
                foreach ($ep in $m.ExtraPaths) {
                    if ($ep -and (Test-Path -LiteralPath $ep)) {
                        Remove-Item -LiteralPath $ep -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            $freed += [long]$m.SizeBytes
            $deletedCount++
        } catch {}
    }
    return [pscustomobject]@{
        DeletedCount = $deletedCount
        FreedBytes   = $freed
    }
}
