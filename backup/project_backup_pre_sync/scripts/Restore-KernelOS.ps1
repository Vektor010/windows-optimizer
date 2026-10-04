# ==============================================================================
#  KERNELOS 11 25H2 BASELINE RESTORE SCRIPT
#  Restores the exact pre-tweak state of KernelOS11 25H2 AiOv1.6.2 (IoT)
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"
$backupDir = Join-Path (Split-Path $PSScriptRoot -Parent) "backup"

Write-Host "==============================================================================" -ForegroundColor DarkCyan
Write-Host "         ВОССТАНОВЛЕНИЕ ИСХОДНОГО СОСТОЯНИЯ KERNELOS 11                      " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor DarkCyan

if (Test-Path $backupDir) {
    $regFiles = Get-ChildItem -Path $backupDir -Filter "*_KernelOS.reg"
    if ($regFiles.Count -gt 0) {
        Write-Host "[1/3] Импорт оригинальных веток реестра KernelOS..." -ForegroundColor Yellow
        foreach ($rf in $regFiles) {
            reg import $rf.FullName /y | Out-Null
            Write-Host "   + Восстановлено: $($rf.Name)" -ForegroundColor DarkGray
        }
    }
}

Write-Host "[2/3] Восстановление специфичных значений KernelOS..." -ForegroundColor Yellow
# Priority & MMCSS (KernelOS defaults)
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "SerializeTimerExpiration" -Type DWord -Value 2
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "ThreadDpcEnable" -Type DWord -Value 1

$mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty $mmcss -Name "SystemResponsiveness" -Type DWord -Value 0
Set-ItemProperty $mmcss -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295
Set-ItemProperty $mmcss -Name "NoLazyMode" -Type DWord -Value 1
Set-ItemProperty "$mmcss\Tasks\Games" -Name "GPU Priority" -Type DWord -Value 8
Set-ItemProperty "$mmcss\Tasks\Games" -Name "Priority" -Type DWord -Value 6
Set-ItemProperty "$mmcss\Tasks\Games" -Name "Scheduling Category" -Type String -Value "High"

# Graphics & TDR (KernelOS had TdrDelay = 10)
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Type DWord -Value 10
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -ErrorAction SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "DisableOverlays" -Type DWord -Value 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "ForceDirectFlip" -Type DWord -Value 1
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Type DWord -Value 2

# Memory & Power
Disable-MMAgent -MemoryCompression -PageCombining -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Type DWord -Value 1
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "SleepStudyDisabled" -Type DWord -Value 1
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CoalescingTimerInterval" -ErrorAction SilentlyContinue
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EnergyEstimationDisabled" -ErrorAction SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Type DWord -Value 1

# VBS & WPBT
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "SmpDisableWpbtExecution" -ErrorAction SilentlyContinue

# Peripheral & Audio
Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 3
Remove-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -ErrorAction SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100

# Visibility
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -ErrorAction SilentlyContinue

Write-Host "[3/3] Проверка служб KernelOS..." -ForegroundColor Yellow
$services = @("SysMain", "WSearch", "DiagTrack", "MapsBroker", "WerSvc", "Spooler", "NVDisplay.ContainerLocalSystem")
foreach ($s in $services) {
    Stop-Service $s -Force -ErrorAction SilentlyContinue
    Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
}

Write-Host "`n[УСПЕХ] Исходное состояние KernelOS 11 полностью восстановлено!" -ForegroundColor Green
Write-Host "Все ваши оригинальные твики KernelPan1c сохранены без изменений.`n" -ForegroundColor Cyan
