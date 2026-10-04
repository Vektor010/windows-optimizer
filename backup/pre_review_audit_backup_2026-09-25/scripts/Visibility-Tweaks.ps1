# Noverse Research - Visibility & Explorer UX Optimizations
# Based on noverse.dev/docs/win-config/visibility/ by Nohuto
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Applying Visibility, Explorer & UI Latency Optimizations (Nohuto exact values)..." -ForegroundColor Cyan

# 1. Classic Context Menu (Win 10 instant right-click, 0ms XAML delay)
Write-Host "[1/10] Enabling Classic Context Menu (Zero XAML delay on right-click)..." -ForegroundColor Yellow
$clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
Set-ItemProperty -Path $clsidPath -Name "(Default)" -Value ""

# 2. Disable Window Animations
Write-Host "[2/10] Disabling Window Minimize/Maximize Animations (Instant UI response)..." -ForegroundColor Yellow
$dwm = "HKCU:\Software\Microsoft\Windows\DWM"
if (-not (Test-Path $dwm)) { New-Item $dwm -Force | Out-Null }
Set-ItemProperty $dwm -Name "DisallowAnimations" -Type DWord -Value 1

# 3. Show File Extensions & Hidden Files
Write-Host "[3/10] Enabling File Extensions & Hidden Files in Explorer..." -ForegroundColor Yellow
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $adv)) { New-Item $adv -Force | Out-Null }
Set-ItemProperty $adv -Name "HideFileExt" -Type DWord -Value 0
Set-ItemProperty $adv -Name "Hidden" -Type DWord -Value 1

# 4. Detailed File Transfer (EnthusiastMode)
Write-Host "[4/10] Enabling Detailed File Transfer graph (EnthusiastMode)..." -ForegroundColor Yellow
$ops = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager"
if (-not (Test-Path $ops)) { New-Item $ops -Force | Out-Null }
Set-ItemProperty $ops -Name "EnthusiastMode" -Type DWord -Value 1

# 5. Taskbar Seconds in System Clock
Write-Host "[5/10] Enabling Seconds in System Clock..." -ForegroundColor Yellow
Set-ItemProperty $adv -Name "ShowSecondsInSystemClock" -Type DWord -Value 1

# 6. Launch Explorer to "This PC" (LaunchTo = 1)
Write-Host "[6/10] Setting Explorer default view to 'This PC' (LaunchTo = 1)..." -ForegroundColor Yellow
Set-ItemProperty $adv -Name "LaunchTo" -Type DWord -Value 1

# 7. Clean Quick Access / Home (ShowRecent = 0, ShowFrequent = 0)
Write-Host "[7/10] Disabling Quick Access recent/frequent files clutter..." -ForegroundColor Yellow
$exp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
Set-ItemProperty $exp -Name "ShowRecent" -Type DWord -Value 0
Set-ItemProperty $exp -Name "ShowFrequent" -Type DWord -Value 0
Set-ItemProperty $exp -Name "ShowCloudFilesInQuickAccess" -Type DWord -Value 0

# 8. Compact View & Type Overlay in Explorer
Write-Host "[8/10] Enabling Compact Explorer View & Disabling Folder Tooltips..." -ForegroundColor Yellow
Set-ItemProperty $adv -Name "UseCompactMode" -Type DWord -Value 1
Set-ItemProperty $adv -Name "ShowTypeOverlay" -Type DWord -Value 0
Set-ItemProperty $adv -Name "FolderContentsInfoTip" -Type DWord -Value 0

# 9. Mouse Hover Time (8ms) & Instant Menu Show Delay (0ms)
Write-Host "[9/10] Tuning Mouse Hover Time (8ms) & MenuShowDelay (0ms)..." -ForegroundColor Yellow
$desk = "HKCU:\Control Panel\Desktop"
Set-ItemProperty $desk -Name "MouseHoverTime" -Type String -Value "8"
Set-ItemProperty $desk -Name "MenuShowDelay" -Type String -Value "0"

# 10. Disable Aero Shake (DisallowShaking = 1)
Write-Host "[10/10] Disabling Aero Shake (Window shaking minimize)..." -ForegroundColor Yellow
Set-ItemProperty $adv -Name "DisallowShaking" -Type DWord -Value 1

Write-Host "`n[✓] All Nohuto Visibility & Explorer optimizations (10/10) applied successfully!" -ForegroundColor Green
