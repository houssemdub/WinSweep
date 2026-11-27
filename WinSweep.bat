@echo off
setlocal EnableDelayedExpansion

:: Change directory to current script directory
cd /d "%~dp0"

title WinSweep

:: Test administrator privilege using fltmc (standard Windows filter manager utility)
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting Administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: Launch the PowerShell script in Single-Threaded Apartment (STA) mode for WPF
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0WinSweep.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [NOTE] Program closed.
)
