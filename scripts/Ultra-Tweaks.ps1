﻿# ==============================================================================
# NOVA CORE (ULTRA TWEAKS)
# ==============================================================================
# Описание: Самые агрессивные, но безопасные твики для максимальной производительности
# и очистки Windows от слежки, ИИ и UWP-мусора. Никакого мусора, только чистая производительность.
# ==============================================================================

Write-Host ">>> Применение эксклюзивных твиков NOVA CORE..." -ForegroundColor Cyan

# 1. Отключение Windows AI (Recall & Copilot)
$aiPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
if (-not (Test-Path $aiPath)) { New-Item -Path $aiPath -Force | Out-Null }
Set-ItemProperty $aiPath -Name "DisableAIDataAnalysis" -Type DWord -Value 1
Set-ItemProperty $aiPath -Name "AllowRecallEnablement" -Type DWord -Value 0

$copilotPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (-not (Test-Path $copilotPath)) { New-Item -Path $copilotPath -Force | Out-Null }
Set-ItemProperty $copilotPath -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
$copilotAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $copilotAdv)) { New-Item -Path $copilotAdv -Force | Out-Null }
Set-ItemProperty $copilotAdv -Name "ShowCopilotButton" -Type DWord -Value 0
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue


Get-AppxPackage *Microsoft.Windows.Ai.Copilot.Provider* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

# 2. Возврат Классического Блокнота (Удаление UWP)
Get-AppxPackage *Microsoft.WindowsNotepad* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

# 3. Возврат Классического Просмотра Фотографий (Windows Photo Viewer)
$photoReg = "HKCR:\Applications\photoviewer.dll\shell\open"
if (-not (Test-Path $photoReg)) { New-Item -Path $photoReg -Force | Out-Null }
Set-ItemProperty "$photoReg" -Name "MuiVerb" -Value "@photoviewer.dll,-3043"
New-Item -Path "$photoReg\command" -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty "$photoReg\command" -Name "(Default)" -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"

$extensions = @(".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tif", ".tiff")
foreach ($ext in $extensions) {
    $assocPath = "HKCR:\PhotoViewer.FileAssoc.Tiff\DefaultIcon"
    if (-not (Test-Path $assocPath)) { New-Item -Path $assocPath -Force | Out-Null }
}

# 4. Возврат Классического Windows Media Player (Удаление UWP Zune)
Get-AppxPackage *Microsoft.ZuneVideo* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.ZuneMusic* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

# 5. Классическое контекстное меню (Windows 11)
$ctx = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (-not (Test-Path $ctx)) {
    New-Item -Path $ctx -Force | Out-Null
    Set-ItemProperty -Path $ctx -Name "(Default)" -Value ""
}

# 6. Оптимизация таймеров (BCD)
bcdedit /set disabledynamictick yes | Out-Null
bcdedit /set useplatformclock no | Out-Null

# 7. Отключение фоновых UWP (глобально)
$bgApps = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
if (-not (Test-Path $bgApps)) { New-Item -Path $bgApps -Force | Out-Null }
Set-ItemProperty $bgApps -Name "GlobalUserDisabled" -Value 1

# 8. Тотальная блокировка телеметрии
$telemetry = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $telemetry)) { New-Item -Path $telemetry -Force | Out-Null }
Set-ItemProperty $telemetry -Name "AllowTelemetry" -Value 0
Disable-Service -Name "DiagTrack" -ErrorAction SilentlyContinue

Write-Host "[OK] Эксклюзивные твики NOVA CORE успешно интегрированы!" -ForegroundColor Green

Write-Host 'Удаление UWP Калькулятора (Возврат к классическому)...' -ForegroundColor Cyan
Get-AppxPackage *Microsoft.WindowsCalculator* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
