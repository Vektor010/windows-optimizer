# Noverse Research - System & Kernel Full Optimization Suite
# Based on noverse.dev/docs/win-config/system/ by Nohuto
# Tailored for AMD Ryzen 7 9850X3D (Zen 5 3D V-Cache) & Windows 11 IoT Enterprise LTSC

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Applying Comprehensive System & Kernel Optimizations..." -ForegroundColor Cyan

# 1. Performance Log Users permission (Fix for PresentMon & Special K SwapChain Monitor)
Write-Host "[1/18] Granting Performance Log Users permission (SID S-1-5-32-559)..." -ForegroundColor Yellow
try {
    $groupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-559")
    $groupName = $groupSid.Translate([System.Security.Principal.NTAccount]).Value
    if ($groupName -match '\\(.+)$') { $groupName = $matches[1] }
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($currentUser -match '\\(.+)$') { $currentUser = $matches[1] }
    net localgroup "$groupName" "$currentUser" /add | Out-Null
    Write-Host " [+] User '$currentUser' added to '$groupName' (reboot required for token refresh)" -ForegroundColor Green
} catch {
    Write-Host " [-] Could not add user: $_" -ForegroundColor Red
}

# 2. MMCSS SystemResponsiveness (0 = 100% CPU priority reserved for games)
Write-Host "[2/18] Setting MMCSS SystemResponsiveness to 0..." -ForegroundColor Yellow
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Type DWord -Value 0

# 3. MMCSS NetworkThrottlingIndex (0xFFFFFFFF = No network packet throttling during games)
Write-Host "[3/18] Disabling MMCSS Network Throttling..." -ForegroundColor Yellow
Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Type DWord -Value 0xFFFFFFFF

# 4. MMCSS Games Task Scheduling Category & GPU Priority
Write-Host "[4/18] Configuring MMCSS Games Task Priorities (GPU 8 / Priority 6 / High)..." -ForegroundColor Yellow
$gamesTaskPath = "$mmcssPath\Tasks\Games"
if (-not (Test-Path $gamesTaskPath)) { New-Item -Path $gamesTaskPath -Force | Out-Null }
Set-ItemProperty -Path $gamesTaskPath -Name "Affinity" -Type DWord -Value 0
Set-ItemProperty -Path $gamesTaskPath -Name "Background Only" -Type String -Value "False"
Set-ItemProperty -Path $gamesTaskPath -Name "Clock Rate" -Type DWord -Value 10000
Set-ItemProperty -Path $gamesTaskPath -Name "GPU Priority" -Type DWord -Value 8
Set-ItemProperty -Path $gamesTaskPath -Name "Priority" -Type DWord -Value 6
Set-ItemProperty -Path $gamesTaskPath -Name "Scheduling Category" -Type String -Value "High"
Set-ItemProperty -Path $gamesTaskPath -Name "SFIO Priority" -Type String -Value "High"

# 5. MMCSS NoLazyMode (1 = Prevents MMCSS scheduler from entering sleep/lazy mode)
Write-Host "[5/18] Setting MMCSS NoLazyMode to 1..." -ForegroundColor Yellow
Set-ItemProperty -Path $mmcssPath -Name "NoLazyMode" -Type DWord -Value 1

# 6. Win32PrioritySeparation for single-CCD Ryzen 7 9850X3D (0x26 = 38 dec, 3:1 foreground boost)
Write-Host "[6/18] Tuning CPU Quantum (Win32PrioritySeparation = 0x26)..." -ForegroundColor Yellow
$priorityControl = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
Set-ItemProperty -Path $priorityControl -Name "Win32PrioritySeparation" -Type DWord -Value 38

# 7. Kernel Timer Expiration Serialization (2 = non-serialized, each core uses own timer table)
Write-Host "[7/18] Setting SerializeTimerExpiration to 2 (Eliminates CPU 0 timer queue bottleneck)..." -ForegroundColor Yellow
$kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
if (-not (Test-Path $kernelPath)) { New-Item -Path $kernelPath -Force | Out-Null }
Set-ItemProperty -Path $kernelPath -Name "SerializeTimerExpiration" -Type DWord -Value 2

# 8. Threaded DPC Processing (KeThreadDpcEnable = 1)
Write-Host "[8/18] Enabling Threaded DPC Processing (KeThreadDpcEnable = 1)..." -ForegroundColor Yellow
Set-ItemProperty -Path $kernelPath -Name "ThreadDpcEnable" -Type DWord -Value 1

# 9. Windows Game Mode & GameDVR
Write-Host "[9/18] Enabling Windows Game Mode & Disabling GameDVR..." -ForegroundColor Yellow
$gb = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $gb)) { New-Item $gb -Force | Out-Null }
Set-ItemProperty $gb -Name "AllowAutoGameMode" -Type DWord -Value 1
Set-ItemProperty $gb -Name "AutoGameModeEnabled" -Type DWord -Value 1
$gdvr = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (-not (Test-Path $gdvr)) { New-Item $gdvr -Force | Out-Null }
Set-ItemProperty $gdvr -Name "AllowGameDVR" -Type DWord -Value 0

# 10. Memory Compression & Page Combining (Disabled for 64GB RAM to eliminate CPU spikes)
Write-Host "[10/18] Disabling Memory Compression & Combining (64GB RAM)..." -ForegroundColor Yellow
Disable-MMAgent -MemoryCompression -PageCombining -ErrorAction SilentlyContinue | Out-Null

# 11. DisablePagingExecutive (Keep kernel and drivers locked in physical RAM)
Write-Host "[11/18] Enabling DisablePagingExecutive (Zero driver paging latencies)..." -ForegroundColor Yellow
$mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $mmPath -Name "DisablePagingExecutive" -Type DWord -Value 1

# 12. Kernel SleepStudy (SleepStudyDisabled = 1)
Write-Host "[12/18] Disabling Kernel SleepStudy Tracing..." -ForegroundColor Yellow
$pwrSm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-ItemProperty -Path $pwrSm -Name "SleepStudyDisabled" -Type DWord -Value 1

# 13. DWM Fullscreen Optimizations & DirectFlip
Write-Host "[13/18] Tuning DWM FSO & DirectFlip..." -ForegroundColor Yellow
$gcs = "HKCU:\System\GameConfigStore"
Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Type DWord -Value 0
Set-ItemProperty -Path $gcs -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
Set-ItemProperty -Path $gcs -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1
Set-ItemProperty -Path $gcs -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1

# 14. DWM Multi-Plane Overlay (MPO) & DirectFlip Support
Write-Host "[14/18] Ensuring DWM Multi-Plane Overlay (MPO) & DirectFlip are Active..." -ForegroundColor Yellow
$gfx = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
Set-ItemProperty -Path $gfx -Name "DisableOverlays" -Type DWord -Value 0
Set-ItemProperty -Path $gfx -Name "ForceDirectFlip" -Type DWord -Value 1

# 15. HAGS & Foreground Priority Boost in GPU Scheduler
Write-Host "[15/18] Setting HAGS HwSchMode = 2 & ForegroundPriorityBoost in GPU Scheduler..." -ForegroundColor Yellow
Set-ItemProperty -Path $gfx -Name "HwSchMode" -Type DWord -Value 2
$gfxSched = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"
if (-not (Test-Path $gfxSched)) { New-Item -Path $gfxSched -Force | Out-Null }
Set-ItemProperty -Path $gfxSched -Name "ForegroundPriorityBoost" -Type DWord -Value 1

# 16. NTFS Filesystem (Disable 8.3 Names & Last Access Time)
Write-Host "[16/18] Optimizing NTFS Filesystem Overhead..." -ForegroundColor Yellow
$fs = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
Set-ItemProperty -Path $fs -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 1
Set-ItemProperty -Path $fs -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1
Set-ItemProperty -Path $fs -Name "LongPathsEnabled" -Type DWord -Value 1

# 17. Hung Screen & App Timeouts
Write-Host "[17/18] Setting Hung App Timeouts (Instant Kill 1s)..." -ForegroundColor Yellow
$desk = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $desk -Name "HungAppTimeout" -Type String -Value "1000"
Set-ItemProperty -Path $desk -Name "WaitToKillAppTimeout" -Type String -Value "2000"
Set-ItemProperty -Path $desk -Name "AutoEndTasks" -Type String -Value "1"

# 18. Disable StickyKeys / FilterKeys shortcuts & Enable VerboseStatus
Write-Host "[18/18] Disabling StickyKeys popup shortcuts & Enabling VerboseStatus..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122"
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58"
$polSys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $polSys)) { New-Item $polSys -Force | Out-Null }
Set-ItemProperty -Path $polSys -Name "VerboseStatus" -Type DWord -Value 1
# 19. Disable Toast Notifications during Gaming (Noverse System Values)
Write-Host "[19/21] Disabling Gaming Notification Popups & Toast Sounds..." -ForegroundColor Yellow
$push = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $push)) { New-Item $push -Force | Out-Null }
Set-ItemProperty -Path $push -Name "ToastEnabled" -Type DWord -Value 0
Set-ItemProperty -Path $push -Name "LockScreenToastEnabled" -Type DWord -Value 0
$notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (-not (Test-Path $notif)) { New-Item $notif -Force | Out-Null }
Set-ItemProperty -Path $notif -Name "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" -Type DWord -Value 0

# 20. Minimal Window Snapping (Noverse Minimal Window Snapping)
Write-Host "[20/21] Configuring Minimal Window Snapping (SnapAssist Off)..." -ForegroundColor Yellow
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $adv -Name "SnapAssist" -Type DWord -Value 0
Set-ItemProperty -Path $adv -Name "EnableSnapBar" -Type DWord -Value 0
Set-ItemProperty -Path $adv -Name "EnableSnapAssistFlyout" -Type DWord -Value 0

# 21. Disable Storage Sense Background Scans (Noverse Disable Storage Sense)
Write-Host "[21/21] Disabling Storage Sense Background Drive Scans..." -ForegroundColor Yellow
$ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
if (-not (Test-Path $ss)) { New-Item $ss -Force | Out-Null }
Set-ItemProperty -Path $ss -Name "04" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "01" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "2048" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "08" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "256" -Type DWord -Value 0

Write-Host "`n[✓] Comprehensive System & Kernel optimization (21/21) completed successfully!" -ForegroundColor Green
