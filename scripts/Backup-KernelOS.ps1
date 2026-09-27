#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Создаёт высокоточный эталонный снимок (Baseline Snapshot) системного реестра
#    Windows до применения твиков оптимизации и сохраняет его в файл формата JSON
#    (по умолчанию: backup/kernelos_baseline.json).
#    Фиксирует точное состояние каждого ключа и параметра:
#    - EXISTS: параметр существует (сохраняется точное значение и тип данных REG_DWORD,
#      REG_SZ, REG_BINARY, REG_QWORD, REG_MULTI_SZ).
#    - VALUE_NOT_EXISTS: раздел реестра существует, но параметр отсутствует.
#    - NOT_EXISTS: раздел реестра отсутствует полностью.
#
# 2. ЗАЧЕМ:
#    Служит абсолютной точкой отсчёта («нулевым километром») для гарантированного
#    100% безопасного и побитового отката системы к заводскому состоянию через
#    Restore-KernelOS.ps1. Исключает любые догадки о том, какие значения были до твиков.
#
# 3. ПОСЛЕДСТВИЯ:
#    Безопасный режим чтения (Read-Only). Не производит изменений в реестре или
#    системных файлах. Создаёт/обновляет файл снимка JSON с кодировкой UTF-8.
#    Встроена защита от случайной перезаписи: если эталонный снимок уже существует,
#    скрипт блокирует перезапись для защиты первоначальной точки отсчёта (требуется -Force).
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Требуются права Администратора
#    для чтения системных веток HKLM:\SYSTEM и HKLM:\SOFTWARE.
#    Полная поддержка Windows PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Для восстановления параметров из созданного снимка используется парный скрипт
#    Restore-KernelOS.ps1. Для удаления файла снимка достаточно удалить файл .json.
#
# 6. ИСТОЧНИК:
#    Архитектурный стандарт проекта Optimizer / KernelOS:
#    Gaming & System Optimizer Reference
#    https://github.com/system-optimizer
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$OutputPath,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'

$baseDir = Split-Path $PSScriptRoot -Parent
$backupDir = Join-Path $baseDir 'backup'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $jsonPath = Join-Path $backupDir 'kernelos_baseline.json'
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $jsonPath = $OutputPath
} else {
    $jsonPath = [System.IO.Path]::Combine($baseDir, $OutputPath)
}

$targetDir = [System.IO.Path]::GetDirectoryName($jsonPath)
if (-not [string]::IsNullOrWhiteSpace($targetDir) -and -not (Test-Path -LiteralPath $targetDir)) {
    [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
}

# ------------------------------------------------------------------------------
# Защита от повторной перезаписи: не перезаписывать существующий бэкап без -Force
# ------------------------------------------------------------------------------
if ((Test-Path -LiteralPath $jsonPath) -and -not $Force) {
    if (-not $Quiet) {
        Write-Host "[!] Бэкап '$jsonPath' уже существует!" -ForegroundColor Yellow
        Write-Host "    Перезапись заблокирована для защиты исходной точки отсчёта." -ForegroundColor DarkYellow
        Write-Host "    Используйте -Force, если вы осознанно хотите пересоздать эталон." -ForegroundColor DarkGray
    }
    return
}

if (-not $Quiet) {
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "      СНЯТИЕ ФАКТИЧЕСКОГО СНИМКА СИСТЕМЫ (KERNELOS BASELINE)                 " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
}

# Полный список реестровых параметров всех модулей оптимизации Optimizer
$trackedRegistry = @(
    # System, PriorityControl & MMCSS
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NoLazyMode" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Affinity" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Background Only" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Clock Rate" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Scheduling Category" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "SFIO Priority" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "SerializeTimerExpiration" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "ThreadDpcEnable" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Name = "MaintenanceDisabled" },

    # GameDVR & GameBar
    @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AllowAutoGameMode" },
    @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled" },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled" },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode" },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode" },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible" },

    # Memory & Power
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "DisablePagingExecutive" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; Name = "SleepStudyDisabled" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name = "CoalescingTimerInterval" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name = "EnergyEstimationDisabled" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; Name = "PowerThrottlingOff" },

    # Graphics & DWM
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "DisableOverlays" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "ForceDirectFlip" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDelay" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDdiDelay" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"; Name = "ForegroundPriorityBoost" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "DisallowAnimations" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM"; Name = "DisallowAnimations" },

    # FileSystem
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "NtfsDisable8dot3NameCreation" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "NtfsDisableLastAccessUpdate" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "LongPathsEnabled" },

    # Desktop, Timeouts & Accessibility
    @{ Path = "HKCU:\Control Panel\Desktop"; Name = "HungAppTimeout" },
    @{ Path = "HKCU:\Control Panel\Desktop"; Name = "WaitToKillAppTimeout" },
    @{ Path = "HKCU:\Control Panel\Desktop"; Name = "AutoEndTasks" },
    @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MouseHoverTime" },
    @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay" },
    @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconSpacing" },
    @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconVerticalSpacing" },
    @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconTitleWrap" },
    @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate" },
    @{ Path = "HKCU:\Control Panel\International"; Name = "sShortTime" },
    @{ Path = "HKCU:\Control Panel\International"; Name = "sShortDate" },
    @{ Path = "HKCU:\Control Panel\Accessibility\StickyKeys"; Name = "Flags" },
    @{ Path = "HKCU:\Control Panel\Accessibility\Keyboard Response"; Name = "Flags" },
    @{ Path = "HKCU:\Control Panel\Accessibility\ToggleKeys"; Name = "Flags" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "VerboseStatus" },

    # Notifications & Explorer
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "ToastEnabled" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "LockScreenToastEnabled" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarEndTask" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "SnapAssist" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapBar" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapAssistFlyout" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableTaskGroups" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "HideFileExt" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Hidden" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowSecondsInSystemClock" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowTypeOverlay" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "FolderContentsInfoTip" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowSyncProviderNotifications" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DisallowShaking" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowRecent" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowFrequent" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowCloudFilesInQuickAccess" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "SettingsPageVisibility" },
    @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\Personalization"; Name = "NoLockScreen" },

    # Security & WPBT
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"; Name = "EnableVirtualizationBasedSecurity" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; Name = "DisableWpbtExecution" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"; Name = "SmartScreenEnabled" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableSmartScreen" },

    # Privacy, Telemetry, WER & Recall
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name = "QueueReporting" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry" },
    @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowSearchToUseLocation" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\ConnectedDevicesPlatform"; Name = "EnableCdp" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds" },

    # Network
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DisableTaskOffload" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DefaultTTL" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"; Name = "EnableMulticast" },

    # Peripherals & Audio
    @{ Path = "HKCU:\Software\Microsoft\Multimedia\Audio"; Name = "UserDuckingPreference" },
    @{ Path = "HKCU:\Control Panel\Mouse"; Name = "RawMouseThrottleEnabled" },
    @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed" },
    @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold1" },
    @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold2" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"; Name = "MouseDataQueueSize" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"; Name = "KeyboardDataQueueSize" }
)

if (-not $Quiet) {
    Write-Host "Сканирование $($trackedRegistry.Count) параметров реестра..." -ForegroundColor Yellow
}

$tweaksList = [System.Collections.Generic.List[object]]::new($trackedRegistry.Count)
$countExists = 0
$countValueNotExists = 0
$countNotExists = 0

foreach ($item in $trackedRegistry) {
    $p = $item.Path
    $n = $item.Name

    if (-not (Test-Path -LiteralPath $p)) {
        $tweaksList.Add([ordered]@{
            "path"          = $p
            "name"          = $n
            "originalState" = "NOT_EXISTS"
            "originalValue" = $null
            "originalType"  = $null
        })
        $countNotExists++
    } else {
        $regKey = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
        if ($regKey.Property -contains $n) {
            $val = (Get-ItemProperty -LiteralPath $p -Name $n -ErrorAction SilentlyContinue).$n
            $valKind = $regKey.GetValueKind($n).ToString()
            $tweaksList.Add([ordered]@{
                "path"          = $p
                "name"          = $n
                "originalState" = "EXISTS"
                "originalValue" = $val
                "originalType"  = $valKind
            })
            $countExists++
        } else {
            $tweaksList.Add([ordered]@{
                "path"          = $p
                "name"          = $n
                "originalState" = "VALUE_NOT_EXISTS"
                "originalValue" = $null
                "originalType"  = $null
            })
            $countValueNotExists++
        }
    }
}

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$output = [pscustomobject][ordered]@{
    "timestamp"    = (Get-Date).ToString("o")
    "computerName" = $env:COMPUTERNAME
    "osCaption"    = if ($os) { $os.Caption } else { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName }
    "osBuild"      = if ($os) { $os.BuildNumber } else { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber }
    "stats"        = [ordered]@{
        "total"           = $trackedRegistry.Count
        "exists"          = $countExists
        "valueNotExists"  = $countValueNotExists
        "notExists"       = $countNotExists
    }
    "tweaks"       = $tweaksList.ToArray()
}

$json = $output | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonPath, $json, [System.Text.Encoding]::UTF8)

if (-not $Quiet) {
    Write-Host "`n[✓] Снимок успешно сохранён в: $jsonPath" -ForegroundColor Green
    Write-Host "    - Существующих параметров (EXISTS):           $countExists" -ForegroundColor Cyan
    Write-Host "    - Параметров без значения (VALUE_NOT_EXISTS):   $countValueNotExists" -ForegroundColor Yellow
    Write-Host "    - Отсутствующих веток (NOT_EXISTS):           $countNotExists`n" -ForegroundColor DarkGray
}

if ($PassThru) {
    return $output
}
