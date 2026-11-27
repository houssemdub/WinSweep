# WinSweep

A lightweight, zero-dependency Windows system cleanup and privacy utility built with PowerShell and WPF.

WinSweep provides a dark-themed interactive GUI to clear Windows system logs, antivirus logs, temporary caches, GPU shader caches, developer package caches, AI assistant/CLI transcripts, and Windows activity traces — **while strictly leaving all browser data (caches, passwords, and history) untouched.**

![WinSweep GUI](assets/screenshot.png)

## Features

- **Zero Dependencies**: Pure PowerShell + WPF (`PresentationFramework`) with a Batch launcher (`WinSweep.bat`).
- **Auto-Elevation**: Automatically requests Administrator privileges and launches in STA mode for WPF.
- **Browser-Safe by Design**: Browser caches, passwords, cookies, and browsing histories are never touched.
- **One-Click Presets**:
  - `Select All` / `Deselect All`
  - `Recommended (Safe)` — selects safe system, security, and cache cleanups by default
  - `Antivirus Logs Only`
  - `Temp and Caches Only`
  - `Privacy and Traces Only`
- **Live Execution Console & Timestamped Logs**: Real-time log output with space-recovered and items-cleaned counters, plus full UTF-8 log files saved in `Logs/Cleanup_YYYY-MM-DD_HH-mm-ss.log`.

## Cleanup Categories

### 1. Security (Antivirus & Security Logs)
- **Kaspersky Lab**: `.log`, `.rpt`, `.trace`, `.dmp` files and user AppData logs
- **Windows Defender**: Scan history, support logs, quarantine cache, LocalCopy, NIS logs
- **ESET / NOD32**: Security, NOD32, and RemoteAdministrator Agent logs
- **Avast & AVG**: Logs, reports, and Avast quarantine chest
- **Bitdefender**: Profile logs and dump folders
- **Norton & Symantec SEP**: Product and endpoint protection logs
- **McAfee**: DesktopProtection, Endpoint Security, Agent, and WebAdvisor logs
- **Other Security Suites**: Malwarebytes, Sophos, Trend Micro, F-Secure, Comodo, Panda, G Data, Webroot, CrowdStrike logs

### 2. System (Windows System & Event Logs)
- **Windows Event Logs**: Clears active event logs via `EventLogSession` and archived `.evtx` files
- **Diagnostic & Setup Logs**: `Windows\Logs`, `Panther`, driver `.log` files in `inf`, `System32\LogFiles`, WMI logs, `debug`, `LiveKernelReports`, WinSAT, Windows Update DataStore logs, SleepStudy, `CBS.log`, `dism.log`, IIS logs
- **Crash Dumps & WER**: User/system `CrashDumps`, `Minidump`, `MEMORY.DMP`, and Windows Error Reporting (WER)
- **Delivery Optimization & `Windows.old`**: Delivery Optimization cache, `Windows.old`, root setup `.log` files, RetailDemo
- **Windows Search Gather Logs**: Stops `WSearch`, cleans gather logs, and restarts the service

### 3. Caches (Temporary Files & Caches)
- **System & User Temp Files**: `%TEMP%`, `Windows\Temp`, `SystemTemp`, `LocalService`/`NetworkService` temp, and all user profile temp folders
- **Windows Prefetch Cache**: `Windows\Prefetch`
- **Windows Update Download Cache**: Stops `wuauserv`/`bits`/`cryptSvc`, clears `SoftwareDistribution\Download` and `PostRebootEventCache.V2`, restarts services
- **Recycle Bin**: Empties the Recycle Bin across all drives (`Clear-RecycleBin`)
- **Thumbnail & Icon Caches**: `thumbcache_*.db`, `iconcache_*.db`, and `IconCache.db`
- **Windows Font Cache** *(unchecked by default)*: Restarts `FontCache` and clears font cache files / `FNTCACHE.DAT`
- **Orphaned Installer Patch Cache**: `Windows\Installer\$PatchCache$\Managed`

### 4. Apps (Hardware, Apps & Activity Traces)
- **AI Conversations & CLI History** *(unchecked by default)*: Antigravity CLI (`brain` & `logs`), Gemini CLI cache, Aider history, Continue sessions/index, Ollama logs, Cursor logs/workspaceStorage, Claude Desktop logs/cache, ChatGPT Desktop logs/cache, GitHub Copilot cache/logs
- **Activity Traces** *(unchecked by default)*: PowerShell `ConsoleHost_history.txt` & PSReadLine history, Windows `RunMRU`, Explorer `TypedPaths`, `UserAssist`, `ConnectedDevicesPlatform`, Clipboard history, and previous WinSweep session logs
- **Recent Files & Jump Lists** *(unchecked by default)*: Explorer Recent items, `AutomaticDestinations`, `CustomDestinations`
- **GPU Shaders**: NVIDIA (`DXCache`, `GLCache`, `NV_Cache`), AMD (`DxCache`, `GLCache`, `VkCache`), Intel (`ShaderCache`), Direct3D (`D3DSCache`)
- **Office, Teams, OneDrive & Steam**: Office File Cache & Telemetry, Delivery Optimization user logs, Steam logs, OneDrive & Teams logs
- **Developer Caches** *(unchecked by default)*: NuGet, pip, npm, Yarn, Java Deployment Cache, Visual Studio package/IntelliCode caches
- **DNS Resolver Cache**: Flushes Windows DNS cache (`Clear-DnsClientCache`)
- **Automated Disk Cleanup**: Runs native `cleanmgr.exe /sagerun:1000` (excluding Internet/Temporary Internet caches)

## Usage

1. Double-click **`WinSweep.bat`** (it will automatically prompt for Administrator elevation).
2. Or run directly from an elevated PowerShell prompt:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\WinSweep.ps1
   ```
3. Choose a preset or toggle individual checkboxes, then click **RUN SELECTED CLEANUP**.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1+ (built into Windows)
- Administrator privileges (handled automatically by the launcher)

## Project Structure

- `WinSweep.bat` — Elevation wrapper that launches the GUI in STA mode
- `WinSweep.ps1` — Main PowerShell + WPF application and cleanup tasks
- `Logs/` — Directory where timestamped execution logs are saved (ignored by Git)
