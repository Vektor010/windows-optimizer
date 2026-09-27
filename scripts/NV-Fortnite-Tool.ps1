<#
================================================================================
Имя твика:              Оптимизация Fortnite (NV-Fortnite-Tool)
Что делает:             1. Настраивает GameUserSettings.ini:
                           - Принудительный полноэкранный режим (FullscreenMode=0).
                           - Отключение вертикальной синхронизации (bUseVSync=False).
                           - Отключение динамического разрешения (bUseDynamicResolution=False).
                           - Отключение размытия (bMotionBlur=False), травы (bShowGrass=False),
                             Nanite (bUseNanite=False) и трассировки лучей (bRayTracing=False).
                           - Включение NVIDIA Reflex Low Latency (LatencyTweak2: 0=Off, 1=On, 2=On+Boost)
                             и режима минимальной задержки ввода (LowInputLatencyModeIsEnabled=True).
                           - Настройка соревновательного разрешения, гаммы и лимита FPS.
                           - Переключение RHI (DX11 / DX12) и режима производительности (MeshQuality=0).
                        2. Настраивает Engine.ini (пресет параметров Unreal Engine 5):
                           - Сохранение видимости парашютов и дельтапланов в воздухе (r.ViewDistanceScale=1.0, r.DetailMode=1).
                           - Отключение пост-обработки, Bloom, глубин резкости, Ambient Occlusion.
                           - Минимизация разрешения и дистанции теней (r.Shadow.CSM.MaxCascades=1, r.Shadow.MaxResolution=4).
                           - Отключение Nanite (r.Nanite=0), Lumen (r.Lumen.HardwareRaytracing=0) и VRS.
                           - Оптимизация пула стриминга текстур (r.TextureStreaming=1, r.Streaming.PoolSize=1024).
                           - Установка атрибута Read-Only для защиты от перезаписи игрой.
                        3. Очистка и Trim Game (Debloat):
                           - Удаление логов, кэшей и отчётов об ошибках из Saved и EpicGamesLauncher.
                           - Удаление отладочных библиотек (dbghelp*), модулей Discord, SpeechGraphics, NVIDIA NGX.
                           - Удаление неиспользуемых компонентов (Splash, CEF3, Legal, Movies, Plugins, MaterialX).
                           - Опциональная очистка текстур высокого разрешения (pakchunk*optional*, pakchunk*ondemand*).
                        4. Автозавершение лаунчера (Launcher Termination):
                           - Создание оптимизированного загрузчика и ярлыка на Рабочем столе.
                           - Автоматическая выгрузка процесса EpicGamesLauncher сразу после старта игры.
                        5. Сетевая политика QoS:
                           - Приоритезация сетевого трафика (DSCP 46) для FortniteClient-Win64-Shipping.exe.
                        6. Функция отката (Restore):
                           - Восстановление оригинальных GameUserSettings.ini и Engine.ini из бэкапов (.backup).
                           - Удаление ярлыка лаунчера и правила QoS.
Зачем нужно:            Минимизирует задержки рендеринга движка Unreal Engine 5 (input lag), устраняет микрофризы
                        из-за тяжелых эффектов и Nanite/Lumen, освобождает оперативную память и процессор от лаунчера Epic Games,
                        гарантирует приоритетную передачу сетевых пакетов на роутере.
Значение по умолчанию:  Стандартные пресеты графики с Nanite/Lumen, Epic Games Launcher постоянно работает в фоне,
                        сетевой приоритет QoS отсутствует.
Значение после твика:   Соревновательные настройки графики и движка UE5, лаунчер закрывается при старте,
                        сетевые пакеты имеют приоритет DSCP 46.
Источник:               Официальное руководство Gaming & System Optimizer и репозиторий github.com/system-optimizer
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Settings", "Engine", "Debloat", "Launcher", "QoS", "Restore", "Status")]
    [string]$Action = "Status",

    [Parameter(ParameterSetName = "Settings")]
    [switch]$Settings,

    [Parameter(ParameterSetName = "Engine")]
    [switch]$Engine,

    [Parameter(ParameterSetName = "Debloat")]
    [switch]$Debloat,

    [Parameter(ParameterSetName = "Launcher")]
    [switch]$Launcher,

    [Parameter(ParameterSetName = "QoS")]
    [switch]$QoS,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore,

    [Parameter()]
    [string]$FortnitePath = "",

    [Parameter()]
    [int]$Width = 1920,

    [Parameter()]
    [int]$Height = 1080,

    [Parameter()]
    [double]$BrightnessPercent = 100,

    [Parameter()]
    [string]$FPSLimit = "240.000000",

    [Parameter()]
    [int]$Reflex = 1,

    [Parameter()]
    [int]$ResolutionQuality = 100,

    [Parameter()]
    [int]$ViewDistanceQuality = 0,

    [Parameter()]
    [ValidateSet("dx11", "dx12")]
    [string]$RHI = "dx12",

    [Parameter()]
    [bool]$LockConfigFile = $false,

    [Parameter()]
    [double]$ViewDistanceScale = 1.0,

    [Parameter()]
    [int]$DetailMode = 1,

    [Parameter()]
    [switch]$DebloatCosmetics
)

if ($Settings) { $Action = "Settings" }
if ($Engine)   { $Action = "Engine" }
if ($Debloat)  { $Action = "Debloat" }
if ($Launcher) { $Action = "Launcher" }
if ($QoS)      { $Action = "QoS" }
if ($Restore)  { $Action = "Restore" }

$nvexecn = "FortniteClient-Win64-Shipping.exe"

function Show-NVBannerCyan {
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Clear-Host
    }
    Write-Host ""
    Write-Host -ForegroundColor DarkBlue "              ░░░     ░░░   ░░░░░░░░░░░   ░░░     ░░░   ░░░░░░░░░░   ░░░░░░░░░░    ░░░░░░░░░░   ░░░░░░░░░░"
    Write-Host -ForegroundColor DarkBlue "              ░░░░    ░░░   ░░░     ░░░   ░░░     ░░░   ░░░          ░░░     ░░░   ░░░          ░░░"
    Write-Host -ForegroundColor Blue     "              ▒▒▒▒▒   ░▒▒   ▒░░     ░░▒   ▒░░     ░░▒   ░░░          ▒░░     ▒▒░   ░░░          ░░░"
    Write-Host -ForegroundColor Blue     "              ▒▒▒ ▒▒▒ ▒▒▒   ▒▒░     ░▒▒   ▒▒░     ░▒▒   ▒▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒"
    Write-Host -ForegroundColor Blue     "              ▒▒▒   ▒▒▒▒▒   ▒▒▒     ▒▒▒    ▒▒▒   ▒▒▒    ▒▒▒          ▒▓▓     ▓▓▒          ▒▒▒   ▒▒▒"
    Write-Host -ForegroundColor DarkCyan "              ▒▓▓    ▓▓▓▒   ▓▓▓     ▓▓▓     ▒▓▓ ▓▓▒     ▓▓▓          ▓▓▓     ▓▓▓          ▓▓▓   ▓▓▓"
    Write-Host -ForegroundColor DarkCyan "              ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓▓       ▓▓▓       ▓▓▓▓▓▓▓▓▓▓   ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓▓▓▓▓"
    Write-Host "‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-NVBannerRed {
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Clear-Host
    }
    Write-Host ""
    Write-Host -ForegroundColor DarkRed "              ░░░     ░░░   ░░░░░░░░░░░   ░░░     ░░░   ░░░░░░░░░░   ░░░░░░░░░░    ░░░░░░░░░░   ░░░░░░░░░░"
    Write-Host -ForegroundColor DarkRed "              ░░░░    ░░░   ░░░     ░░░   ░░░     ░░░   ░░░          ░░░     ░░░   ░░░          ░░░"
    Write-Host -ForegroundColor Red     "              ▒▒▒▒▒   ░▒▒   ▒░░     ░░▒   ▒░░     ░░▒   ░░░          ▒░░     ▒▒░   ░░░          ░░░"
    Write-Host -ForegroundColor Red     "              ▒▒▒ ▒▒▒ ▒▒▒   ▒▒░     ░▒▒   ▒▒░     ░▒▒   ▒▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒"
    Write-Host -ForegroundColor Red     "              ▒▒▒   ▒▒▒▒▒   ▒▒▒     ▒▒▒    ▒▒▒   ▒▒▒    ▒▒▒          ▒▓▓     ▓▓▒          ▒▒▒   ▒▒▒"
    Write-Host -ForegroundColor DarkRed "              ▒▓▓    ▓▓▓▒   ▓▓▓     ▓▓▓     ▒▓▓ ▓▓▒     ▓▓▓          ▓▓▓     ▓▓▓          ▓▓▓   ▓▓▓"
    Write-Host -ForegroundColor DarkRed "              ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓▓       ▓▓▓       ▓▓▓▓▓▓▓▓▓▓   ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓▓▓▓▓"
    Write-Host "‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-NVLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Detail = "",
        [ConsoleColor]$PrefixColor = "Green",
        [ConsoleColor]$DetailColor = "DarkGray"
    )
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$Prefix " -NoNewline -ForegroundColor $PrefixColor
    Write-Host "$Message " -NoNewline -ForegroundColor White
    if ($Detail) {
        Write-Host "$Detail" -ForegroundColor $DetailColor
    } else {
        Write-Host ""
    }
}

function Get-FortniteInstallPath {
    param([string]$ExplicitPath = "")

    if ($ExplicitPath -and (Test-Path "$ExplicitPath\FortniteGame")) {
        return $ExplicitPath
    }

    # 1. Поиск через манифесты Epic Games Launcher
    $manifestDir = "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $manifestDir) {
        $manifests = Get-ChildItem -Path $manifestDir -Filter "*.item" -ErrorAction SilentlyContinue
        foreach ($file in $manifests) {
            try {
                $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
                if ($json.AppName -eq "Fortnite" -or $json.DisplayName -like "*Fortnite*") {
                    if ($json.InstallLocation -and (Test-Path "$($json.InstallLocation)\FortniteGame")) {
                        return $json.InstallLocation
                    }
                }
            } catch {}
        }
    }

    # 2. Поиск через реестр Windows Uninstall
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fortnite",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Fortnite"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $loc = (Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue).InstallLocation
            if ($loc -and (Test-Path "$loc\FortniteGame")) {
                return $loc
            }
        }
    }

    # 3. Проверка стандартных каталогов на доступных дисках
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' }
    $subDirs = @(
        "Program Files\Epic Games\Fortnite",
        "Epic Games\Fortnite",
        "Games\Fortnite",
        "Fortnite"
    )
    foreach ($drive in $drives) {
        foreach ($sub in $subDirs) {
            $candidate = Join-Path $drive.RootDirectory.FullName $sub
            if (Test-Path "$candidate\FortniteGame") {
                return $candidate
            }
        }
    }

    return $null
}

function Get-FortniteCatalogItemId {
    $manifestDir = "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $manifestDir) {
        $manifests = Get-ChildItem -Path $manifestDir -Filter "*.item" -ErrorAction SilentlyContinue
        foreach ($file in $manifests) {
            try {
                $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
                if ($json.AppName -eq "Fortnite" -or $json.DisplayName -like "*Fortnite*") {
                    if ($json.CatalogItemId) {
                        return $json.CatalogItemId
                    }
                }
            } catch {}
        }
    }
    return "4fe75bbc5a674f4f9b356b5c90567da5" # Стандартный fallback CatalogItemId
}

function Invoke-FortniteSettings {
    param(
        [int]$ResX = $Width,
        [int]$ResY = $Height,
        [double]$Bright = $BrightnessPercent,
        [string]$FPS = $FPSLimit,
        [int]$ReflexVal = $Reflex,
        [int]$ResQual = $ResolutionQuality,
        [int]$ViewDist = $ViewDistanceQuality,
        [string]$PreferredRHI = $RHI,
        [bool]$Lock = $LockConfigFile
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Настройка соревновательного профиля GameUserSettings.ini..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    $configFile = Join-Path $configDir "GameUserSettings.ini"
    $backupFile = Join-Path $configDir "GameUserSettings.backup"

    # Снятие атрибута Read-Only перед резервным копированием и редактированием
    if (Test-Path $configFile) {
        $item = Get-ItemProperty -Path $configFile -Name IsReadOnly -ErrorAction SilentlyContinue
        if ($item.IsReadOnly) {
            Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        }
        if (-not (Test-Path $backupFile)) {
            Copy-Item -Path $configFile -Destination $backupFile -Force
            Write-NVLog "[+]" "Создана резервная копия:" "$backupFile" -PrefixColor Green
        }
    }

    $gammaVal = [math]::Round(($Bright * 0.01) + 1.2, 6).ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)

    $optimizedSettings = [ordered]@{
        "FullscreenMode"                      = "0"
        "CosmeticStreamingEnabled"             = "CodeSet_Disabled"
        "UnlockConsoleFPS"                     = "False"
        "bMotionBlur"                          = "False"
        "bAllowUIParallax"                     = "False"
        "bShowGrass"                           = "False"
        "bShowFPS"                             = "True"
        "bUseGPUCrashDebugging"                = "False"
        "bStopRenderingInBackground"           = "False"
        "bLatencyTweak1"                       = "False"
        "LatencyTweak2"                        = "$ReflexVal"
        "bLatencyFlash"                        = "False"
        "FortAntiAliasingMethod"               = "Disabled"
        "bEnableDLSSFrameGeneration"           = "False"
        "TemporalSuperResolutionQuality"       = "Custom"
        "DLSSQuality"                          = "0"
        "PotentiallyUpscaledResolutionQuality" = "100.000000"
        "NeverUpscaledResolutionQuality"       = "100.000000"
        "bUseNanite"                           = "False"
        "DesiredGlobalIlluminationQuality"     = "0"
        "DesiredReflectionQuality"             = "0"
        "PreNaniteGlobalIlluminationQuality"   = "0"
        "PreNaniteReflectionQuality"           = "0"
        "bRayTracing"                          = "False"
        "b120FpsMode"                          = "False"
        "FrontendFrameRateLimit"               = "$FPS"
        "bIsEnergySavingEnabledIdle"           = "False"
        "bIsEnergySavingEnabledFocusLoss"      = "False"
        "EnergySavingLevelFocusLoss"           = "1"
        "DisplayGamma"                         = "$gammaVal"
        "UserInterfaceContrast"                = "1.000000"
        "bUseHeadphoneMode"                    = "False"
        "bAllowFullGameDownload"               = "False"
        "bAllowCellularDownload"               = "False"
        "bAutoLaunchFullGame"                  = "False"
        "bAllowDownloadHighResMips"            = "False"
        "bAllowLowPowerMode"                   = "False"
        "MobileFPSMode"                        = "Mode_30Fps"
        "bNeverShowMobileLink"                 = "True"
        "ParsleyIdleTime"                      = "Never"
        "bShowTemperature"                     = "False"
        "LowInputLatencyModeIsEnabled"         = "True"
        "bUseVSync"                            = "False"
        "bUseDynamicResolution"                = "False"
        "ResolutionSizeX"                      = "$ResX"
        "ResolutionSizeY"                      = "$ResY"
        "LastUserConfirmedResolutionSizeX"     = "$ResX"
        "LastUserConfirmedResolutionSizeY"     = "$ResY"
        "LastConfirmedFullscreenMode"          = "0"
        "PreferredFullscreenMode"              = "0"
        "AudioQualityLevel"                    = "1"
        "LastConfirmedAudioQualityLevel"       = "1"
        "FrameRateLimit"                       = "$FPS"
        "DesiredScreenWidth"                   = "$ResX"
        "DesiredScreenHeight"                  = "$ResY"
        "LastUserConfirmedDesiredScreenWidth"  = "$ResX"
        "LastUserConfirmedDesiredScreenHeight" = "$ResY"
        "bUseHDRDisplayOutput"                 = "False"
        "sg.ResolutionQuality"                 = "$ResQual"
        "sg.ViewDistanceQuality"               = "$ViewDist"
        "sg.AntiAliasingQuality"               = "0"
        "sg.ShadowQuality"                     = "0"
        "sg.GlobalIlluminationQuality"         = "0"
        "sg.ReflectionQuality"                 = "0"
        "sg.PostProcessQuality"                = "0"
        "sg.TextureQuality"                    = "0"
        "sg.EffectsQuality"                    = "0"
        "sg.FoliageQuality"                    = "0"
        "sg.ShadingQuality"                    = "0"
        "sg.LandscapeQuality"                  = "0"
        "PreferredRHI"                         = "$PreferredRHI"
        "PreferredFeatureLevel"                = "es31"
        "MeshQuality"                          = "0"
    }

    $existingContent = ""
    if (Test-Path $configFile) {
        $existingContent = Get-Content -Path $configFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    if ([string]::IsNullOrWhiteSpace($existingContent)) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("[/Script/FortniteGame.FortGameUserSettings]")
        foreach ($k in $optimizedSettings.Keys) {
            $lines.Add("$k=$($optimizedSettings[$k])")
        }
        $lines.Add("")
        $lines.Add("[D3DRHIPreference]")
        $lines.Add("PreferredRHI=$PreferredRHI")
        $lines.Add("PreferredFeatureLevel=es31")
        $lines.Add("")
        $lines.Add("[PerformanceMode]")
        $lines.Add("MeshQuality=0")
        [System.IO.File]::WriteAllLines($configFile, $lines, [System.Text.Encoding]::UTF8)
    } else {
        $lines = [System.Collections.Generic.List[string]]::new($existingContent -split "`r?\n")
        foreach ($k in $optimizedSettings.Keys) {
            $val = $optimizedSettings[$k]
            $found = $false
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^\s*$([regex]::Escape($k))\s*=") {
                    $lines[$i] = "$k=$val"
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                # Добавляем в конец или после основного заголовка
                $lines.Add("$k=$val")
            }
        }

        # Проверка секций D3DRHIPreference и PerformanceMode
        $allText = $lines -join "`r`n"
        if ($allText -notmatch "(?m)^\[D3DRHIPreference\]") {
            $lines.Add("")
            $lines.Add("[D3DRHIPreference]")
            $lines.Add("PreferredRHI=$PreferredRHI")
            $lines.Add("PreferredFeatureLevel=es31")
        }
        if ($allText -notmatch "(?m)^\[PerformanceMode\]") {
            $lines.Add("")
            $lines.Add("[PerformanceMode]")
            $lines.Add("MeshQuality=0")
        }

        [System.IO.File]::WriteAllLines($configFile, $lines, [System.Text.Encoding]::UTF8)
    }

    if ($Lock) {
        Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $true -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Файл GameUserSettings.ini защищён от записи (Read-Only)" -PrefixColor Green
    } else {
        Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Файл GameUserSettings.ini оставлен доступным для записи" -PrefixColor Green
    }

    Write-NVLog "[+]" "Настройки графики Fortnite успешно применены!" -PrefixColor Green
}

function Invoke-FortniteEngine {
    param(
        [double]$ViewDistScale = $ViewDistanceScale,
        [int]$Detail = $DetailMode
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Импорт соревновательного пресета Engine.ini..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    $engineFile = Join-Path $configDir "Engine.ini"
    $backupFile = Join-Path $configDir "Engine.backup"

    if (Test-Path $engineFile) {
        $item = Get-ItemProperty -Path $engineFile -Name IsReadOnly -ErrorAction SilentlyContinue
        if ($item.IsReadOnly) {
            Set-ItemProperty -Path $engineFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        }
        if (-not (Test-Path $backupFile)) {
            Copy-Item -Path $engineFile -Destination $backupFile -Force
            Write-NVLog "[+]" "Создана резервная копия:" "$backupFile" -PrefixColor Green
        }
    }

    $vds = $ViewDistScale.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)

    $engineSettings = @"
[SystemSettings]
r.FullScreenMode=0
r.VSync=0
r.TextureStreaming=1
r.ViewDistanceScale=$vds
r.ShadowQuality=0
r.MotionBlurQuality=0
r.Tonemapper.Quality=0
r.DepthOfFieldQuality=0
r.BloomQuality=0
r.LensFlareQuality=0
r.AmbientOcclusionLevels=0
r.AmbientOcclusionRadiusScale=0
r.AmbientOcclusion.Method=0
r.Shadow.CSM.MaxCascades=1
r.Shadow.MaxResolution=4
r.Shadow.RadiusThreshold=0.1
r.SSR.Quality=0
r.Tonemapper.GrainQuantization=0
r.Streaming.MipBias=2
r.DetailMode=$Detail
r.RefractionQuality=0
r.MaterialQualityLevel=0
r.SceneColorFormat=2
r.SkyLightingQuality=0
r.Fog=0
r.HZBOcclusion=0
r.Shadow.DistanceScale=0.001
r.Streaming.PoolSize=1024
r.Streaming.LimitPoolSizeToVRAM=0
r.MaxQualityMode=0
r.SceneColorFringe.Max=0
r.SceneColorFringeQuality=0
r.MaxAnisotropy=1
r.OptimizeForUAVPerformance=1
r.Nanite=0
r.Nanite.ProjectEnabled=0
r.VRS.Enable=false
r.VRS.EnableImage=false
r.Lumen.HardwareRaytracing=0
r.Lumen.Reflections.HardwareRayTracing=0
r.Lumen.ScreenProbeGather.ShortRangeAO=0
r.Lumen.Reflections.Temporal=0
r.ReflectionMethod=0
r.Lumen.Reflections.DownsampleFactor=4
r.Lumen.ScreenProbeGather.DownsampleFactor=128
r.RayTracing=0
r.RayTracing.Enable=0
r.RayTracing.GlobalIllumination=0
r.RayTracing.Reflections=0
r.RayTracing.Shadows=0
r.SSGI.Enable=0
r.SSR.MaxRoughness=0
r.SSR.HalfResSceneColor=1
r.RenderTargetPoolMin=400
r.GPUCrashDebugging=0
r.OneFrameThreadLag=0
"@

    [System.IO.File]::WriteAllText($engineFile, $engineSettings, [System.Text.Encoding]::UTF8)
    Set-ItemProperty -Path $engineFile -Name Attributes -Value ([System.IO.FileAttributes]::ReadOnly) -ErrorAction SilentlyContinue

    Write-NVLog "[+]" "Пресет параметров Unreal Engine 5 записан в Engine.ini" -PrefixColor Green
    Write-NVLog "[+]" "Атрибут Read-Only установлен для предотвращения перезаписи движком" -PrefixColor Green
}

function Invoke-FortniteDebloat {
    param(
        [string]$Path = $FortnitePath,
        [bool]$RemoveCosmetics = $DebloatCosmetics
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Очистка временных файлов и debloat Fortnite..." -PrefixColor Yellow

    # Очистка локальных кэшей Saved
    $savedPath = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved"
    $savedSubDirs = @(
        "Logs",
        "Config\CrashReportClient",
        "PersistentDownloadDir\EMS",
        "PersistentDownloadDir\ManifestCache",
        "PersistentDownloadDir\ias"
    )
    foreach ($sub in $savedSubDirs) {
        $target = Join-Path $savedPath $sub
        if (Test-Path $target) {
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-NVLog "[+]" "Кэш и логи %LOCALAPPDATA%\FortniteGame\Saved очищены" -PrefixColor Green

    # Очистка кэшей Epic Games Launcher
    $epicSaved = Join-Path $env:LOCALAPPDATA "EpicGamesLauncher\Saved"
    $epicDel = @("Cache", "Logs", "Config\CrashReportClient")
    foreach ($ed in $epicDel) {
        $epTarget = Join-Path $epicSaved $ed
        if (Test-Path $epTarget) {
            Remove-Item -Path $epTarget -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-NVLog "[+]" "Кэш и логи Epic Games Launcher очищены" -PrefixColor Green

    # Поиск директории установки Fortnite
    $fnPath = Get-FortniteInstallPath -ExplicitPath $Path
    if (-not $fnPath) {
        Write-NVLog "[!]" "Каталог установки Fortnite не найден. Очистка игровых файлов пропущена." -PrefixColor Yellow
        return
    }

    Write-NVLog "[+]" "Найден каталог Fortnite:" "$fnPath" -PrefixColor Green

    # Очистка отладочных библиотек Win64
    $win64Dir = Join-Path $fnPath "FortniteGame\Binaries\Win64"
    if (Test-Path $win64Dir) {
        Get-ChildItem -Path $win64Dir -Filter "dbghelp*" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Удаление неиспользуемых модулей ThirdParty
    $thirdParty = Join-Path $fnPath "FortniteGame\Binaries\ThirdParty"
    $thirdPartyDel = @("Discord", "SpeechGraphics", "NVIDIA\NGX")
    foreach ($folder in $thirdPartyDel) {
        $tp = Join-Path $thirdParty $folder
        if (Test-Path $tp) {
            Remove-Item -Path $tp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Удаление второстепенных и устаревших файлов
    $otherPaths = @(
        "$fnPath\FortniteGame\Binaries\Win64\EasyAntiCheat\Licenses",
        "$fnPath\FortniteGame\Binaries\Win64\EasyAntiCheat\EasyAntiCheat_EOS_Setup.exe",
        "$fnPath\FortniteGame\Content\Splash",
        "$fnPath\Engine\Binaries\ThirdParty\MaterialX",
        "$fnPath\Engine\Binaries\ThirdParty\Windows\WinPixEventRuntime",
        "$fnPath\FortniteGame\Content\Legal",
        "$fnPath\FortniteGame\Content\Movies",
        "$fnPath\Engine\Programs",
        "$fnPath\Engine\Plugins",
        "$fnPath\Engine\Binaries\ThirdParty\CEF3",
        "$fnPath\Engine\Binaries\ThirdParty\DbgHelp",
        "$fnPath\Engine\Binaries\ThirdParty\NVIDIA"
    )
    foreach ($op in $otherPaths) {
        if (Test-Path $op) {
            Remove-Item -Path $op -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Автономная настройка EasyAntiCheat Settings.json (без обязательного интернета)
    $eacDir = Join-Path $fnPath "FortniteGame\Binaries\Win64\EasyAntiCheat"
    if (Test-Path $eacDir) {
        $eacSettingsFile = Join-Path $eacDir "Settings.json"
        $eacSettingsJson = @"
{
	"title"					: "Debloated Fortnite - discord.gg/Optimizer",
	"executable"			: "FortniteClient-Win64-Shipping.exe",
	"productid"				: "prod-fn",
	"sandboxid"				: "fn",
	"deploymentid"			: "62a9473a2dca46b29ccf17577fcf42d7",
	"requested_splash"		: "EasyAntiCheat/Optimizer.png",
	"wait_for_game_process_exit"	: "true",
	"hide_bootstrapper"		: "false",
	"hide_gui"				: "true",
	"allow_null_client"		: "false"
}
"@
        [System.IO.File]::WriteAllText($eacSettingsFile, $eacSettingsJson, [System.Text.Encoding]::UTF8)

        # Опциональная загрузка splash-логотипа Optimizer (с безопасной обработкой оффлайн-режима)
        try {
            $splashPng = Join-Path $eacDir "Optimizer.png"
            if (-not (Test-Path $splashPng)) {
                Invoke-WebRequest -Uri "https://github.com/5Noxi/Files/releases/download/Fortnite/Optimizer.png" -OutFile $splashPng -TimeoutSec 3 -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    # Опциональное удаление тяжелых текстур
    if ($RemoveCosmetics) {
        $paksDir = Join-Path $fnPath "FortniteGame\Content\Paks"
        if (Test-Path $paksDir) {
            Get-ChildItem -Path $paksDir -Filter "pakchunk*optional-WindowsClient*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $paksDir -Filter "pakChunkEarly-WindowsClient*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $paksDir -Filter "pakchunk*ondemand-WindowsClient*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        $cloudDir = Join-Path $fnPath "Cloud"
        if (Test-Path $cloudDir) {
            Remove-Item -Path $cloudDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-NVLog "[+]" "Опциональные текстуры косметики удалены" -PrefixColor Green
    }

    Write-NVLog "[+]" "Debloat Fortnite успешно завершён!" -PrefixColor Green
}

function Invoke-FortniteLauncher {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Создание оптимизированного загрузчика и ярлыка Fortnite..." -PrefixColor Yellow

    $OptimizerDir = Join-Path $env:APPDATA "Optimizer"
    if (-not (Test-Path $OptimizerDir)) {
        New-Item -Path $OptimizerDir -ItemType Directory -Force | Out-Null
    }

    $catalogId = Get-FortniteCatalogItemId
    $startUrl = "com.epicgames.launcher://apps/fn%3A${catalogId}%3AFortnite?action=launch&silent=true"

    $launcherScript = Join-Path $OptimizerDir "NV-Launcher.ps1"
    $launcherContent = @"
# Created by Optimizer - discord.gg/Optimizer
Start-Process "$startUrl"
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList 'while(`$true){if(Get-Process -Name FortniteClient-Win64-Shipping -ErrorAction SilentlyContinue){Stop-Process -Name EpicGamesLauncher -Force -ErrorAction SilentlyContinue;break};Start-Sleep -Seconds 1}'
"@

    [System.IO.File]::WriteAllText($launcherScript, $launcherContent, [System.Text.Encoding]::ASCII)
    Write-NVLog "[+]" "Скрипт фоновой выгрузки сохранён:" "$launcherScript" -PrefixColor Green

    $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Fortnite.lnk"
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcherScript`""
        
        $fnPath = Get-FortniteInstallPath
        if ($fnPath -and (Test-Path "$fnPath\FortniteGame\Binaries\Win64\$nvexecn")) {
            $shortcut.IconLocation = "$fnPath\FortniteGame\Binaries\Win64\$nvexecn"
        } else {
            $shortcut.IconLocation = "shell32.dll,43"
        }
        $shortcut.Save()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
        Write-NVLog "[+]" "Ярлык на Рабочем столе успешно создан:" "$shortcutPath" -PrefixColor Green
    } catch {
        Write-NVLog "[-]" "Ошибка создания ярлыка WScript.Shell: $($_.Exception.Message)" -PrefixColor Red
    }
}

function Invoke-FortniteQoS {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Применение сетевой политики QoS (DSCP 46)..." -PrefixColor Yellow

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite"
    if (-not (Test-Path $qosPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS" -Name "Fortnite" -Force | Out-Null
    }

    $params = [ordered]@{
        "Version"                 = "1.0"
        "Application Name"        = $nvexecn
        "Protocol"                = "*"
        "Local Port"              = "*"
        "Local IP"                = "*"
        "Local IP Prefix Length"  = "*"
        "Remote Port"             = "*"
        "Remote IP"               = "*"
        "Remote IP Prefix Length" = "*"
        "DSCP Value"              = "46"
        "Throttle Rate"           = "-1"
    }

    foreach ($k in $params.Keys) {
        Set-ItemProperty -Path $qosPath -Name $k -Value $params[$k] -Type String -Force | Out-Null
    }

    Write-NVLog "[+]" "Политика QoS для $nvexecn успешно установлена (DSCP 46)" -PrefixColor Green
}

function Remove-FortniteQoS {
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite"
    if (Test-Path $qosPath) {
        Remove-Item -Path $qosPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Write-NVLog "[+]" "Политика QoS для Fortnite удалена" -PrefixColor Green
    } else {
        Write-NVLog "[~]" "Политика QoS для Fortnite не найдена" -PrefixColor Yellow
    }
}

function Invoke-FortniteRestore {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Откат настроек Fortnite к резервным копиям..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved\Config\WindowsClient"
    $configFile = Join-Path $configDir "GameUserSettings.ini"
    $configBackup = Join-Path $configDir "GameUserSettings.backup"

    $engineFile = Join-Path $configDir "Engine.ini"
    $engineBackup = Join-Path $configDir "Engine.backup"

    # Откат GameUserSettings.ini
    if (Test-Path $configBackup) {
        if (Test-Path $configFile) {
            Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $configBackup -Destination $configFile -Force
        Remove-Item -Path $configBackup -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "GameUserSettings.ini восстановлен из резервной копии" -PrefixColor Green
    } elseif (Test-Path $configFile) {
        Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Кастомный GameUserSettings.ini удалён (оригинальный файл отсутствовал)" -PrefixColor Green
    } else {
        Write-NVLog "[~]" "GameUserSettings.ini не найден" -PrefixColor Yellow
    }

    # Откат Engine.ini
    if (Test-Path $engineBackup) {
        if (Test-Path $engineFile) {
            Set-ItemProperty -Path $engineFile -Name Attributes -Value ([System.IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
            Remove-Item -Path $engineFile -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $engineBackup -Destination $engineFile -Force
        Remove-Item -Path $engineBackup -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $engineFile -Name Attributes -Value ([System.IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Engine.ini восстановлен из резервной копии" -PrefixColor Green
    } elseif (Test-Path $engineFile) {
        # Если бэкапа не было, но файл был создан нашим скриптом
        Set-ItemProperty -Path $engineFile -Name Attributes -Value ([System.IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
        Remove-Item -Path $engineFile -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Кастомный Engine.ini удалён (оригинальный файл отсутствовал)" -PrefixColor Green
    }

    # Удаление QoS
    Remove-FortniteQoS

    # Удаление ярлыка и загрузчика
    $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Fortnite.lnk"
    if (Test-Path $shortcutPath) {
        Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Ярлык Fortnite.lnk удалён с Рабочего стола" -PrefixColor Green
    }

    $launcherScript = Join-Path $env:APPDATA "Optimizer\NV-Launcher.ps1"
    if (Test-Path $launcherScript) {
        Remove-Item -Path $launcherScript -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Скрипт NV-Launcher.ps1 удалён" -PrefixColor Green
    }

    Write-NVLog "[+]" "Откат завершён!" -PrefixColor Green
}

function Get-FortniteStatus {
    Show-NVBannerCyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host "                     ТЕКУЩИЙ СТАТУС ОПТИМИЗАЦИИ FORTNITE                      " -ForegroundColor Cyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host ""

    $fnPath = Get-FortniteInstallPath
    if ($fnPath) {
        Write-Host " [√] Каталог установки: " -NoNewline -ForegroundColor Green
        Write-Host "$fnPath" -ForegroundColor White
    } else {
        Write-Host " [?] Каталог установки: " -NoNewline -ForegroundColor Yellow
        Write-Host "Не обнаружен автоматически (стандартные папки Epic Games пусты)" -ForegroundColor DarkGray
    }

    $configDir = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved\Config\WindowsClient"
    $configFile = Join-Path $configDir "GameUserSettings.ini"
    $configBackup = Join-Path $configDir "GameUserSettings.backup"

    if (Test-Path $configFile) {
        $ro = (Get-ItemProperty -Path $configFile -Name IsReadOnly -ErrorAction SilentlyContinue).IsReadOnly
        $roText = if ($ro) { "Защищён (Read-Only)" } else { "Доступен для записи" }
        Write-Host " [√] GameUserSettings.ini: " -NoNewline -ForegroundColor Green
        Write-Host "Присутствует ($roText)" -ForegroundColor White
    } else {
        Write-Host " [-] GameUserSettings.ini: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Не создан (игра ещё не запускалась)" -ForegroundColor DarkGray
    }

    if (Test-Path $configBackup) {
        Write-Host " [√] Резервная копия конфига: " -NoNewline -ForegroundColor Green
        Write-Host "$configBackup" -ForegroundColor DarkGray
    }

    $engineFile = Join-Path $configDir "Engine.ini"
    $engineBackup = Join-Path $configDir "Engine.backup"
    if (Test-Path $engineFile) {
        $hasSystemSettings = (Get-Content -Path $engineFile -Raw -ErrorAction SilentlyContinue) -match "\[SystemSettings\]"
        $statusText = if ($hasSystemSettings) { "Оптимизирован [SystemSettings]" } else { "Стандартный" }
        Write-Host " [√] Engine.ini: " -NoNewline -ForegroundColor Green
        Write-Host "$statusText" -ForegroundColor White
    } else {
        Write-Host " [-] Engine.ini: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Отсутствует" -ForegroundColor DarkGray
    }

    if (Test-Path $engineBackup) {
        Write-Host " [√] Резервная копия Engine: " -NoNewline -ForegroundColor Green
        Write-Host "$engineBackup" -ForegroundColor DarkGray
    }

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite"
    if (Test-Path $qosPath) {
        $dscp = (Get-ItemProperty -Path $qosPath -Name "DSCP Value" -ErrorAction SilentlyContinue)."DSCP Value"
        Write-Host " [√] Сетевая политика QoS: " -NoNewline -ForegroundColor Green
        Write-Host "Активна (DSCP $dscp для $nvexecn)" -ForegroundColor White
    } else {
        Write-Host " [-] Сетевая политика QoS: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Не настроена" -ForegroundColor DarkGray
    }

    $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Fortnite.lnk"
    if (Test-Path $shortcutPath) {
        Write-Host " [√] Оптимизированный ярлык: " -NoNewline -ForegroundColor Green
        Write-Host "Установлен на Рабочем столе" -ForegroundColor White
    } else {
        Write-Host " [-] Оптимизированный ярлык: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Отсутствует" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# Обработка неинтерактивного запуска по параметрам
switch ($Action) {
    "Settings" {
        Invoke-FortniteSettings
        return
    }
    "Engine" {
        Invoke-FortniteEngine
        return
    }
    "Debloat" {
        Invoke-FortniteDebloat
        return
    }
    "Launcher" {
        Invoke-FortniteLauncher
        return
    }
    "QoS" {
        Invoke-FortniteQoS
        return
    }
    "Restore" {
        Invoke-FortniteRestore
        return
    }
    "Status" {
        if ($PSBoundParameters.ContainsKey("Action") -or $PSBoundParameters.Count -gt 0) {
            Get-FortniteStatus
            return
        }
    }
}

# Интерактивное главное меню
while ($true) {
    Show-NVBannerCyan
    Write-Host "  Ознакомьтесь с информацией перед применением настроек." -ForegroundColor White
    Write-Host "  Discord сообщество Optimizer: " -NoNewline -ForegroundColor Gray
    Write-Host "https://discord.gg/E2ybG4j9jU" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  [1] Настройка '" -NoNewline -ForegroundColor White
    Write-Host "GameUserSettings.ini" -NoNewline -ForegroundColor Yellow
    Write-Host "' (Разрешение, частота кадров, Reflex)" -ForegroundColor White

    Write-Host "  [2] Настройка '" -NoNewline -ForegroundColor White
    Write-Host "Engine.ini" -NoNewline -ForegroundColor Yellow
    Write-Host "' (Оптимизация параметров движка UE5)" -ForegroundColor White

    Write-Host "  [3] Очистка и Debloat игры (Удаление мусора, кэшей и лишних текстур)" -ForegroundColor White
    Write-Host "  [4] Оптимизация лаунчера (Автозавершение Epic Games при запуске)" -ForegroundColor White
    Write-Host "  [5] Сетевая политика QoS (DSCP 46 для Fortnite)" -ForegroundColor White
    Write-Host "  [6] Восстановление настроек (Restore из резервных копий)" -ForegroundColor Green
    Write-Host "  [7] Текущий статус" -ForegroundColor Cyan
    Write-Host "  [8] Выход в главное меню" -ForegroundColor Red
    Write-Host ""
    Write-Host "  >> " -NoNewline -ForegroundColor Blue

    $choice = Read-Host

    switch ($choice) {
        "1" {
            Show-NVBannerCyan
            Write-Host " Применение соревновательного режима с кастомными настройками." -ForegroundColor White
            Write-Host ""
            Write-Host " Введите ширину разрешения (нажмите Enter для 1920) >> " -NoNewline -ForegroundColor Cyan
            $inX = Read-Host
            $finalX = if ($inX -match '^\d+$') { [int]$inX } else { 1920 }

            Write-Host " Введите высоту разрешения (нажмите Enter для 1080) >> " -NoNewline -ForegroundColor Cyan
            $inY = Read-Host
            $finalY = if ($inY -match '^\d+$') { [int]$inY } else { 1080 }

            Write-Host " Введите яркость в % (100 - 150, Enter для 100) >> " -NoNewline -ForegroundColor Cyan
            $inB = Read-Host
            $finalB = if ($inB -match '^\d+$') { [double]$inB } else { 100 }

            Write-Host " Введите лимит FPS (0 - без лимита, 240, 360, Enter для 240) >> " -NoNewline -ForegroundColor Cyan
            $inFps = Read-Host
            $finalFps = if ($inFps -match '^\d+(\.\d+)?$') { $inFps } else { "240.000000" }

            Write-Host " Режим NVIDIA Reflex: [0] Выкл  [1] Вкл  [2] Вкл+Boost (Enter для 1) >> " -NoNewline -ForegroundColor Cyan
            $inRef = Read-Host
            $finalRef = if ($inRef -match '^[0-2]$') { [int]$inRef } else { 1 }

            Write-Host " Качество разрешения % (0 - 100, Enter для 100) >> " -NoNewline -ForegroundColor Cyan
            $inQual = Read-Host
            $finalQual = if ($inQual -match '^\d+$') { [int]$inQual } else { 100 }

            Write-Host " Дальность прорисовки: [0] Близкая  [1] Средняя  [2] Дальняя  [3] Эпическая (Enter для 0) >> " -NoNewline -ForegroundColor Cyan
            $inDist = Read-Host
            $finalDist = if ($inDist -match '^[0-3]$') { [int]$inDist } else { 0 }

            Write-Host " Режим рендеринга RHI: [1] DX11  [2] DX12 (Enter для DX12) >> " -NoNewline -ForegroundColor Cyan
            $inRhi = Read-Host
            $finalRhi = if ($inRhi -eq "1") { "dx11" } else { "dx12" }

            Write-Host " Защитить файл от записи (Read-Only)? [1] Да  [2] Нет (Enter для Нет) >> " -NoNewline -ForegroundColor Cyan
            $inLock = Read-Host
            $finalLock = ($inLock -eq "1")

            Invoke-FortniteSettings -ResX $finalX -ResY $finalY -Bright $finalB -FPS $finalFps -ReflexVal $finalRef -ResQual $finalQual -ViewDist $finalDist -PreferredRHI $finalRhi -Lock $finalLock
            Start-Sleep -Seconds 2
        }
        "2" {
            Invoke-FortniteEngine
            Start-Sleep -Seconds 2
        }
        "3" {
            Show-NVBannerCyan
            Write-Host " Удаление временных файлов, кэшей и модулей телеметрии." -ForegroundColor White
            Write-Host " Внимание: модификация файлов может проверяться античитом." -ForegroundColor Red
            Write-Host ""
            Write-Host " Удалить тяжелые файлы скинов/текстур высокого разрешения? [Y/N] (Enter для N) >> " -NoNewline -ForegroundColor Cyan
            $inCos = Read-Host
            $remCos = ($inCos -eq "Y" -or $inCos -eq "y")

            Invoke-FortniteDebloat -RemoveCosmetics $remCos
            Start-Sleep -Seconds 2
        }
        "4" {
            Invoke-FortniteLauncher
            Start-Sleep -Seconds 2
        }
        "5" {
            Invoke-FortniteQoS
            Start-Sleep -Seconds 2
        }
        "6" {
            Invoke-FortniteRestore
            Start-Sleep -Seconds 2
        }
        "7" {
            Get-FortniteStatus
            Write-Host " Нажмите любую клавишу для возврата в меню..." -ForegroundColor DarkGray
            [Console]::ReadKey($true) | Out-Null
        }
        "8" {
            Write-NVLog "[/]" "Выход из утилиты Fortnite" -PrefixColor Yellow
            return
        }
        default {
            Write-NVLog "[-]" "Неверный выбор" -PrefixColor Red
            Start-Sleep -Seconds 1
        }
    }
}
