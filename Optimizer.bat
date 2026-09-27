@echo off
cd /d "%~dp0"

:: Check for Administrator privileges using fltmc (independent of Server service)
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Optimizer.ps1\"\"' -Verb RunAs"
    exit /b
)

:: Run Optimizer directly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimizer.ps1"
if %errorlevel% neq 0 pause
