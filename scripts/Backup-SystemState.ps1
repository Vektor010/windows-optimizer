#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Создаёт комплексный динамический снимок состояния системы (System State Snapshot)
#    в каталоге backup/snapshots/<SnapshotName>/:
#    1) Выполняет физический экспорт ключевых веток системного и пользовательского
#       реестра в формате .reg файлов (reg export) для гарантированного ручного
#       или аварийного импорта.
#    2) Формирует детальный структурированный снимок реестровых параметров всех модулей
#       оптимизации с типами данных и значениями в файл snapshot_baseline.json.
#    3) Фиксирует текущий статус и режим автозапуска ключевых системных служб (Services).
#    4) Обновляет указатель на последний снимок (backup/snapshots/LATEST.txt).
#
# 2. ЗАЧЕМ:
#    Обеспечивает универсальную многоуровневую страховку перед внесением любых
#    изменений на любом ПК (чистая Windows, сборки, сторонние конфигурации).
#    Позволяет откатить систему через Restore-SystemState.ps1 как целиком, так
#    и по отдельным компонентам.
#
# 3. ПОСЛЕДСТВИЯ:
#    Безопасный режим чтения (Read-Only). Не изменяет системные параметры. Создаёт
#    новую изолированную папку снимка с датой и именем компьютера.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Требуются права Администратора
#    для экспорта системных веток HKLM и опроса параметров служб.
#    Полная поддержка Windows PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Для восстановления состояния системы по созданному снимку используется парный
#    скрипт Restore-SystemState.ps1. Для удаления конкретного снимка достаточно
#    удалить соответствующую папку в backup/snapshots/.
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
    [string]$SnapshotName = '',

    [Parameter()]
    [string]$SnapshotsDir,

    [Parameter()]
    [switch]$NoRegExport,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'

if (-not $Quiet) {
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "       СОЗДАНИЕ УНИВЕРСАЛЬНОГО РЕЗЕРВНОГО СНИМКА (SYSTEM SNAPSHOT)            " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
}

$dateStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$computer = $env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($SnapshotName)) {
    $SnapshotName = "${computer}_${dateStamp}"
}

$baseDir = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SnapshotsDir)) {
    $snapshotsBase = Join-Path (Join-Path $baseDir 'backup') 'snapshots'
} elseif ([System.IO.Path]::IsPathRooted($SnapshotsDir)) {
    $snapshotsBase = $SnapshotsDir
} else {
    $snapshotsBase = [System.IO.Path]::Combine($baseDir, $SnapshotsDir)
}

$currentSnapshotDir = Join-Path $snapshotsBase $SnapshotName

if (-not (Test-Path -LiteralPath $currentSnapshotDir)) {
    [System.IO.Directory]::CreateDirectory($currentSnapshotDir) | Out-Null
}

# ------------------------------------------------------------------------------
# 1. Физический экспорт ключевых веток реестра (.reg)
# ------------------------------------------------------------------------------
if (-not $NoRegExport) {
    if (-not $Quiet) {
        Write-Host "[1/3] Экспорт ключевых веток реестра (reg export)..." -ForegroundColor Yellow
    }

    $regPaths = @(
        @{ Name = "PriorityControl";       Path = "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" },
        @{ Name = "MMCSS";                 Path = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" },
        @{ Name = "KernelSessionManager";  Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" },
        @{ Name = "GraphicsDrivers";       Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" },
        @{ Name = "PowerControl";          Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power" },
        @{ Name = "MouseKbdClass";         Path = "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" },
        @{ Name = "KbdClass";              Path = "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" },
        @{ Name = "TcpipParameters";       Path = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" },
        @{ Name = "Desktop";               Path = "HKCU\Control Panel\Desktop" },
        @{ Name = "Mouse";                 Path = "HKCU\Control Panel\Mouse" },
        @{ Name = "DWM";                   Path = "HKCU\Software\Microsoft\Windows\DWM" },
        @{ Name = "PoliciesExplorer";      Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" },
        @{ Name = "GameBar";               Path = "HKCU\Software\Microsoft\GameBar" },
        @{ Name = "AudioMultimedia";       Path = "HKCU\Software\Microsoft\Multimedia\Audio" }
    )

    foreach ($rp in $regPaths) {
        $outFile = Join-Path $currentSnapshotDir "$($rp.Name).reg"
        $psPath = "Registry::$($rp.Path -replace '^HKLM\\', 'HKEY_LOCAL_MACHINE\' -replace '^HKCU\\', 'HKEY_CURRENT_USER\')"
        if (Test-Path -LiteralPath $psPath) {
            reg export "$($rp.Path)" "$outFile" /y 2>$null | Out-Null
        }
    }
} else {
    if (-not $Quiet) {
        Write-Host "[1/3] Пропуск экспорта .reg файлов (NoRegExport)..." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 2. Сканирование точных параметров и типов данных всех модулей
# ------------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Host "[2/3] Сканирование точных параметров и типов данных..." -ForegroundColor Yellow
}

$trackedParameters = @(
    # System, PriorityControl & MMCSS
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NoLazyMode" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Affinity" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Background Only" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Clock Rate" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Scheduling Category" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "SFIO Priority" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "SerializeTimerExpiration" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "ThreadDpcEnable" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Name = "MaintenanceDisabled" },

    # GameDVR & GameBar
    @{ Key = "HKCU:\Software\Microsoft\GameBar"; Name = "AllowAutoGameMode" },
    @{ Key = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled" },
    @{ Key = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled" },
    @{ Key = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode" },
    @{ Key = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode" },
    @{ Key = "HKCU:\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible" },

    # Memory & Power
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "DisablePagingExecutive" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; Name = "SleepStudyDisabled" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name = "CoalescingTimerInterval" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name = "EnergyEstimationDisabled" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; Name = "PowerThrottlingOff" },

    # Graphics & DWM
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "DisableOverlays" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "ForceDirectFlip" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDelay" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDdiDelay" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"; Name = "ForegroundPriorityBoost" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "DisallowAnimations" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM"; Name = "DisallowAnimations" },

    # FileSystem
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "NtfsDisable8dot3NameCreation" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "NtfsDisableLastAccessUpdate" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "LongPathsEnabled" },

    # Desktop, Timeouts & Accessibility
    @{ Key = "HKCU:\Control Panel\Desktop"; Name = "HungAppTimeout" },
    @{ Key = "HKCU:\Control Panel\Desktop"; Name = "WaitToKillAppTimeout" },
    @{ Key = "HKCU:\Control Panel\Desktop"; Name = "AutoEndTasks" },
    @{ Key = "HKCU:\Control Panel\Desktop"; Name = "MouseHoverTime" },
    @{ Key = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay" },
    @{ Key = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconSpacing" },
    @{ Key = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconVerticalSpacing" },
    @{ Key = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "IconTitleWrap" },
    @{ Key = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate" },
    @{ Key = "HKCU:\Control Panel\International"; Name = "sShortTime" },
    @{ Key = "HKCU:\Control Panel\International"; Name = "sShortDate" },
    @{ Key = "HKCU:\Control Panel\Accessibility\StickyKeys"; Name = "Flags" },
    @{ Key = "HKCU:\Control Panel\Accessibility\Keyboard Response"; Name = "Flags" },
    @{ Key = "HKCU:\Control Panel\Accessibility\ToggleKeys"; Name = "Flags" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "VerboseStatus" },

    # Notifications & Explorer
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "ToastEnabled" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; Name = "LockScreenToastEnabled" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarEndTask" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "SnapAssist" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapBar" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapAssistFlyout" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableTaskGroups" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "HideFileExt" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Hidden" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowSecondsInSystemClock" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowTypeOverlay" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "FolderContentsInfoTip" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowSyncProviderNotifications" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DisallowShaking" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowRecent" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowFrequent" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowCloudFilesInQuickAccess" },
    @{ Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "SettingsPageVisibility" },
    @{ Key = "HKCU:\Software\Policies\Microsoft\Windows\Personalization"; Name = "NoLockScreen" },

    # Security & WPBT
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"; Name = "EnableVirtualizationBasedSecurity" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; Name = "DisableWpbtExecution" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"; Name = "SmartScreenEnabled" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableSmartScreen" },

    # Privacy, Telemetry, WER & Recall
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name = "QueueReporting" },
    @{ Key = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry" },
    @{ Key = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowSearchToUseLocation" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb" },
    @{ Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\ConnectedDevicesPlatform"; Name = "EnableCdp" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds" },

    # Network
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DisableTaskOffload" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DefaultTTL" },
    @{ Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"; Name = "EnableMulticast" },

    # Peripherals & Audio
    @{ Key = "HKCU:\Software\Microsoft\Multimedia\Audio"; Name = "UserDuckingPreference" },
    @{ Key = "HKCU:\Control Panel\Mouse"; Name = "RawMouseThrottleEnabled" },
    @{ Key = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed" },
    @{ Key = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold1" },
    @{ Key = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold2" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"; Name = "MouseDataQueueSize" },
    @{ Key = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"; Name = "KeyboardDataQueueSize" }
)

$parametersList = [System.Collections.Generic.List[object]]::new($trackedParameters.Count)

foreach ($param in $trackedParameters) {
    $exists = $false
    $val = $null
    $valKind = $null

    if (Test-Path -LiteralPath $param.Key) {
        $regItem = Get-Item -LiteralPath $param.Key -ErrorAction SilentlyContinue
        if ($regItem.Property -contains $param.Name) {
            $exists = $true
            $val = (Get-ItemProperty -LiteralPath $param.Key -Name $param.Name -ErrorAction SilentlyContinue).$($param.Name)
            $valKind = $regItem.GetValueKind($param.Name).ToString()
        }
    }

    $parametersList.Add([ordered]@{
        "Key"       = $param.Key
        "Name"      = $param.Name
        "Exists"    = $exists
        "Value"     = $val
        "ValueKind" = $valKind
    })
}

# ------------------------------------------------------------------------------
# 3. Фиксация состояния служб Windows
# ------------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Host "[3/3] Фиксация состояния служб Windows..." -ForegroundColor Yellow
}

$trackedServices = @(
    "SysMain", "WSearch", "DiagTrack", "MapsBroker", "WerSvc", "Spooler",
    "DoSvc", "wuauserv", "bthserv", "XblAuthManager", "XblGameSave", "XboxNetApiSvc",
    "LGHUBUpdaterService", "NVDisplay.ContainerLocalSystem", "NvTelemetryContainer"
)

$servicesList = [System.Collections.Generic.List[object]]::new($trackedServices.Count)

foreach ($sName in $trackedServices) {
    $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($svc) {
        $startMode = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$sName'" -ErrorAction SilentlyContinue).StartMode
        $servicesList.Add([ordered]@{
            "Name"      = $sName
            "Exists"    = $true
            "Status"    = $svc.Status.ToString()
            "StartMode" = $startMode
        })
    } else {
        $servicesList.Add([ordered]@{
            "Name"      = $sName
            "Exists"    = $false
            "Status"    = $null
            "StartMode" = $null
        })
    }
}

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$snapshotData = [pscustomobject][ordered]@{
    "Metadata"   = [ordered]@{
        "ComputerName" = $env:COMPUTERNAME
        "UserName"     = $env:USERNAME
        "Created"      = (Get-Date).ToString("o")
        "OSVersion"    = if ($os) { $os.Caption } else { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName }
        "Build"        = if ($os) { $os.BuildNumber } else { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber }
    }
    "Parameters" = $parametersList.ToArray()
    "Services"   = $servicesList.ToArray()
}

$jsonPath = Join-Path $currentSnapshotDir "snapshot_baseline.json"
$json = $snapshotData | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonPath, $json, [System.Text.Encoding]::UTF8)

# Обновление указателя на последний созданный снимок
$latestLink = Join-Path $snapshotsBase "LATEST.txt"
[System.IO.File]::WriteAllText($latestLink, $SnapshotName, [System.Text.Encoding]::UTF8)

if (-not $Quiet) {
    Write-Host "`n[✓] Резервный снимок системы успешно создан!" -ForegroundColor Green
    Write-Host "Папка снимка: $currentSnapshotDir" -ForegroundColor Cyan
    Write-Host "Имя снимка:   $SnapshotName`n" -ForegroundColor Yellow
}

if ($PassThru) {
    return $snapshotData
}
