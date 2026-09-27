<#
================================================================================
Имя твика:              Оптимизация Marvel Rivals (NV-Marvel-Tool)
Что делает:             1. Настраивает GameUserSettings.ini:
                           - Принудительный полноэкранный режим (FullscreenMode=0, WindowPosX=0, WindowPosY=0).
                           - Отключение вертикальной синхронизации (bUseVSync=False).
                           - Отключение теней, размытия, постобработки и отражений (sg.ShadowQuality=0, sg.PostProcessQuality=0).
                           - Включение NVIDIA Reflex Low Latency (bNvidiaReflex=True).
                           - Отключение генерации кадров DLSS/FSR/XeSS для исключения инпутлага (bDlssFrameGeneration=False).
                           - Пресеты: Производительный (Performance - максимальный FPS) или Сбалансированный (Balanced - резкость CAS 75%).
                           - Настройка кастомного разрешения и лимита частоты кадров (FrameRateLimit).
                        2. Настраивает Engine.ini (пресет параметров Unreal Engine 5):
                           - Сохранение видимости персонажей и суперспособностей в воздухе (r.ViewDistanceScale=1.0, r.DetailMode=1).
                           - Отключение пост-обработки, Bloom, глубин резкости, Ambient Occlusion.
                           - Минимизация разрешения и дистанции теней (r.Shadow.CSM.MaxCascades=1, r.Shadow.MaxResolution=4).
                           - Отключение Nanite (r.Nanite=0), Lumen (r.Lumen.HardwareRaytracing=0) и аппаратно-ускоренного RayTracing.
                           - Оптимизация пула стриминга текстур (r.TextureStreaming=1, r.Streaming.PoolSize=1024).
                           - Установка атрибута Read-Only для защиты от перезаписи игрой.
                        3. Очистка и Trim Game (Debloat):
                           - Удаление утилит сбора телеметрии и краш-репортов (UniCrashReporter, client_diagnose, CrashReportClient).
                           - Удаление лишних языковых пакетов интерфейса PySide6 (освобождение дискового пространства).
                           - Очистка логов и дампов из %LOCALAPPDATA%\Marvel\Saved.
                        4. Оптимизация лаунчера (launcher_config.xml):
                           - Отключение отладочного режима GPU (start_game_with_gpu_debug_mode=False).
                           - Автоматическое закрытие лаунчера после запуска игры (exit_after_start_game=True).
                           - Отключение навязчивых диалогов проверки CPU и подтверждения выхода.
                        5. Сетевая политика QoS:
                           - Приоритезация сетевого трафика (DSCP 46) для Marvel-Win64-Shipping.exe.
                        6. Функция отката (Restore):
                           - Восстановление оригинальных GameUserSettings.ini, Engine.ini и launcher_config.xml.
                           - Удаление правил QoS из реестра Windows.
Зачем нужно:            Снижает сетевой джиттер и задержки рендеринга движка Unreal Engine 5, устраняет микрофризы
                        в динамичных командных замесах, стабилизирует 0.1% и 1% Low FPS, закрывает лаунчер для экономии ОЗУ и CPU.
Значение по умолчанию:  Стандартные графические пресеты, Nanite и эффекты постобработки активны, лаунчер висит в фоне,
                        сетевой приоритет QoS отсутствует.
Значение после твика:   Оптимальные соревновательные настройки графики, лаунчер закрывается при старте, сетевые пакеты
                        Marvel Rivals передаются с наивысшим приоритетом DSCP 46.
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
    [string]$MarvelPath = "",

    [Parameter()]
    [int]$Width = 1920,

    [Parameter()]
    [int]$Height = 1080,

    [Parameter()]
    [string]$FPSLimit = "240.000000",

    [Parameter()]
    [ValidateSet("Performance", "Balanced")]
    [string]$Preset = "Performance",

    [Parameter()]
    [double]$ViewDistanceScale = 1.0,

    [Parameter()]
    [int]$DetailMode = 1
)

if ($Settings) { $Action = "Settings" }
if ($Engine)   { $Action = "Engine" }
if ($Debloat)  { $Action = "Debloat" }
if ($Launcher) { $Action = "Launcher" }
if ($QoS)      { $Action = "QoS" }
if ($Restore)  { $Action = "Restore" }

$nvexecn = "Marvel-Win64-Shipping.exe"

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

function Get-MarvelInstallPath {
    param([string]$ExplicitPath = "")

    if ($ExplicitPath -and (Test-Path "$ExplicitPath\MarvelGame")) {
        return $ExplicitPath
    }

    # 1. Поиск через Steam libraryfolders.vdf
    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamPath -or -not (Test-Path $steamPath)) {
        if (Test-Path "C:\Program Files (x86)\Steam") {
            $steamPath = "C:\Program Files (x86)\Steam"
        }
    }

    if ($steamPath) {
        $libVdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
        if (Test-Path $libVdf) {
            $content = Get-Content $libVdf -Raw -ErrorAction SilentlyContinue
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $lib = $m.Groups[1].Value.Replace('\\', '\')
                $candidate = Join-Path $lib "steamapps\common\MarvelRivals"
                if (Test-Path "$candidate\MarvelGame") { return $candidate }
                $candidate2 = Join-Path $lib "steamapps\common\Marvel Rivals"
                if (Test-Path "$candidate2\MarvelGame") { return $candidate2 }
            }
        }
        $stdCandidate = Join-Path $steamPath "steamapps\common\MarvelRivals"
        if (Test-Path "$stdCandidate\MarvelGame") { return $stdCandidate }
    }

    # 2. Поиск через манифесты Epic Games Launcher
    $manifestDir = "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $manifestDir) {
        $manifests = Get-ChildItem -Path $manifestDir -Filter "*.item" -ErrorAction SilentlyContinue
        foreach ($file in $manifests) {
            try {
                $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
                if ($json.AppName -like "*Marvel*" -or $json.DisplayName -like "*Marvel*") {
                    if ($json.InstallLocation -and (Test-Path "$($json.InstallLocation)\MarvelGame")) {
                        return $json.InstallLocation
                    }
                }
            } catch {}
        }
    }

    # 3. Проверка стандартных каталогов на доступных дисках
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' }
    $subDirs = @(
        "SteamLibrary\steamapps\common\MarvelRivals",
        "SteamLibrary\steamapps\common\Marvel Rivals",
        "Program Files (x86)\Steam\steamapps\common\MarvelRivals",
        "Games\MarvelRivals",
        "Games\Marvel Rivals",
        "MarvelRivals",
        "Marvel Rivals"
    )
    foreach ($drive in $drives) {
        foreach ($sub in $subDirs) {
            $candidate = Join-Path $drive.RootDirectory.FullName $sub
            if (Test-Path "$candidate\MarvelGame") {
                return $candidate
            }
        }
    }

    return $null
}

function Invoke-MarvelSettings {
    param(
        [int]$ResX = $Width,
        [int]$ResY = $Height,
        [string]$FPS = $FPSLimit,
        [string]$PresetMode = $Preset
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Настройка соревновательного профиля GameUserSettings.ini..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "Marvel\Saved\Config\Windows"
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    $configFile = Join-Path $configDir "GameUserSettings.ini"
    $backupFile = Join-Path $configDir "GameUserSettings.backup"

    # Снятие Read-Only перед бэкапом и редактированием
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

    # Настройки пресета (Competitive specifications)
    if ($PresetMode -eq "Balanced") {
        $ssm = 4
        $ssq = 2
        $sharp = "0.750000"
        $distance = 1
        $texture = 1
    } else {
        # Performance
        $ssm = 4
        $ssq = 4
        $sharp = "0.000000"
        $distance = 0
        $texture = 0
    }

    $optimizedSettings = [ordered]@{
        "sg.AntiAliasingQuality"         = "0"
        "sg.ShadowQuality"               = "0"
        "sg.PostProcessQuality"          = "0"
        "sg.TextureQuality"              = "$texture"
        "sg.EffectsQuality"              = "0"
        "sg.FoliageQuality"              = "0"
        "sg.ShadingQuality"              = "0"
        "sg.ReflectionQuality"           = "0"
        "sg.GlobalIlluminationQuality"   = "0"
        "sg.ViewDistanceQuality"         = "$distance"
        "bUseDesiredScreenHeight"        = "False"
        "AntiAliasingSuperSamplingMode"  = "$ssm"
        "SuperSamplingQuality"           = "$ssq"
        "CASSharpness"                   = "$sharp"
        "ScreenPercentage"               = "100.000000"
        "bNvidiaReflex"                  = "True"
        "bXeLowLatency"                  = "False"
        "bDlssFrameGeneration"           = "False"
        "bFSRFrameGeneration"            = "False"
        "bXeFrameGeneration"             = "False"
        "DlssFrameGenerationCount"       = "1"
        "bEnableConsole120Fps"           = "False"
        "bUseVSync"                      = "False"
        "bUseDynamicResolution"          = "True"
        "ResolutionSizeX"                = "$ResX"
        "ResolutionSizeY"                = "$ResY"
        "LastUserConfirmedResolutionSizeX"= "$ResX"
        "LastUserConfirmedResolutionSizeY"= "$ResY"
        "WindowPosX"                     = "0"
        "WindowPosY"                     = "0"
        "FullscreenMode"                 = "0"
        "LastConfirmedFullscreenMode"    = "0"
        "PreferredFullscreenMode"        = "0"
        "AudioQualityLevel"              = "0"
        "LastConfirmedAudioQualityLevel" = "0"
        "FrameRateLimit"                 = "$FPS"
        "DesiredScreenWidth"             = "$ResX"
        "DesiredScreenHeight"            = "$ResY"
        "LastUserConfirmedDesiredScreenWidth" = "$ResX"
        "LastUserConfirmedDesiredScreenHeight"= "$ResY"
        "bUseHDRDisplayOutput"           = "False"
        "HDRDisplayOutputNits"           = "1000"
    }

    $existingContent = ""
    if (Test-Path $configFile) {
        $existingContent = Get-Content -Path $configFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    if ([string]::IsNullOrWhiteSpace($existingContent)) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("[/Script/Engine.GameUserSettings]")
        foreach ($k in $optimizedSettings.Keys) {
            $lines.Add("$k=$($optimizedSettings[$k])")
        }
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
                $lines.Add("$k=$val")
            }
        }
        [System.IO.File]::WriteAllLines($configFile, $lines, [System.Text.Encoding]::UTF8)
    }

    Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    Write-NVLog "[+]" "Настройки графики Marvel Rivals успешно применены (Пресет: $PresetMode)!" -PrefixColor Green
}

function Invoke-MarvelEngine {
    param(
        [double]$ViewDistScale = $ViewDistanceScale,
        [int]$Detail = $DetailMode
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Импорт соревновательного пресета Engine.ini..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "Marvel\Saved\Config\Windows"
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

    Write-NVLog "[+]" "Пресет параметров Unreal Engine 5 записан в Engine.ini (ViewDistanceScale=$vds, DetailMode=$Detail)" -PrefixColor Green
    Write-NVLog "[+]" "Атрибут Read-Only установлен для защиты от перезаписи игрой" -PrefixColor Green
}

function Invoke-MarvelDebloat {
    param([string]$Path = $MarvelPath)

    Show-NVBannerCyan
    Write-NVLog "[~]" "Очистка временных файлов и debloat Marvel Rivals..." -PrefixColor Yellow

    # Очистка локальных кэшей Saved
    $localSavedPaths = @(
        "$env:LOCALAPPDATA\Marvel\Saved\Config\CrashReportClient",
        "$env:LOCALAPPDATA\Marvel\Saved\Crashes",
        "$env:LOCALAPPDATA\Marvel\Saved\Logs"
    )
    foreach ($p in $localSavedPaths) {
        if (Test-Path $p) {
            Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-NVLog "[+]" "Кэши и дампы %LOCALAPPDATA%\Marvel\Saved очищены" -PrefixColor Green

    $gamePath = Get-MarvelInstallPath -ExplicitPath $Path
    if (-not $gamePath) {
        Write-NVLog "[!]" "Каталог установки Marvel Rivals не найден. Очистка файлов игры пропущена." -PrefixColor Yellow
        return
    }

    Write-NVLog "[+]" "Найден каталог Marvel Rivals:" "$gamePath" -PrefixColor Green

    # Удаление мусорных файлов и телеметрии
    $removeList = @(
        "$gamePath\UniCrashReporter.exe",
        "$gamePath\client_diagnose.exe",
        "$gamePath\LICENSE.txt",
        "$gamePath\patchlst.txt",
        "$gamePath\anticheat_popup.exe",
        "$gamePath\temp",
        "$gamePath\Log",
        "$gamePath\MarvelGame\Engine\Binaries\ThirdParty\Dbgman",
        "$gamePath\MarvelGame\Engine\Binaries\Win64\CrashReportClient.exe",
        "$gamePath\MarvelGame\Engine\Programs",
        "$gamePath\MarvelGame\Marvel\Binaries\Win64\ccmini\logs",
        "$gamePath\VMProtectSDK64*",
        "$gamePath\upload_profile.exe",
        "$gamePath\network_tools.exe",
        "$gamePath\launch_record"
    )
    foreach ($item in $removeList) {
        if (Test-Path $item) {
            Remove-Item -Path $item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Удаление неиспользуемых переводов интерфейса PySide6 (оставляем en и pak)
    $translationsDir = Join-Path $gamePath "PySide6\translations"
    if (Test-Path $translationsDir) {
        $allowed = @("qt_en.qm", "qt_man_en.qm", "qtbase_en.qm", "qtdeclarative_en.qm", "qtmultimedia_en.qm", "en-US.pak")
        Get-ChildItem -Path $translationsDir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $allowed -notcontains $_.Name } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-NVLog "[+]" "Debloat Marvel Rivals успешно завершён!" -PrefixColor Green
}

function Invoke-MarvelLauncherConfig {
    param([string]$Path = $MarvelPath)

    Show-NVBannerCyan
    Write-NVLog "[~]" "Оптимизация конфигурации лаунчера Marvel Rivals..." -PrefixColor Yellow

    $gamePath = Get-MarvelInstallPath -ExplicitPath $Path
    if (-not $gamePath) {
        Write-NVLog "[-]" "Каталог установки Marvel Rivals не найден." -PrefixColor Red
        return
    }

    $xmlPath = Join-Path $gamePath "config\launcher_config.xml"
    if (-not (Test-Path $xmlPath)) {
        Write-NVLog "[-]" "Файл конфигурации не найден:" "$xmlPath" -PrefixColor Red
        return
    }

    $xmlBackup = Join-Path $gamePath "config\launcher_config.backup"
    if (-not (Test-Path $xmlBackup)) {
        Copy-Item -Path $xmlPath -Destination $xmlBackup -Force
        Write-NVLog "[+]" "Создана резервная копия:" "$xmlBackup" -PrefixColor Green
    }

    try {
        [xml]$xml = Get-Content -Path $xmlPath -Raw -Encoding UTF8

        $gpu = $xml.SelectSingleNode("//start_game_with_gpu_debug_mode")
        if ($gpu) { $gpu.InnerText = "False" }

        $exit = $xml.SelectSingleNode("//exit_after_start_game")
        if ($exit) { $exit.InnerText = "True" }

        $quit = $xml.SelectSingleNode("//show_quit_dialog")
        if ($quit) { $quit.InnerText = "False" }

        $close = $xml.SelectSingleNode("//close_type")
        if ($close) { $close.InnerText = "0" }

        $cpu = $xml.SelectSingleNode("//show_check_cpu_name_dialog")
        if ($cpu) { $cpu.InnerText = "False" }

        $crash = $xml.SelectSingleNode("//show_check_game_crash_dialog")
        if ($crash) { $crash.InnerText = "False" }

        $xml.Save($xmlPath)
        Write-NVLog "[+]" "Конфигурация launcher_config.xml успешно оптимизирована!" -PrefixColor Green
        Write-NVLog "[+]" "Лаунчер теперь будет автоматически выгружаться при старте игры" -PrefixColor Green
    } catch {
        Write-NVLog "[-]" "Ошибка обработки XML: $($_.Exception.Message)" -PrefixColor Red
    }
}

function Invoke-MarvelQoS {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Применение сетевой политики QoS (DSCP 46)..." -PrefixColor Yellow

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MarvelRivals"
    if (-not (Test-Path $qosPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS" -Name "MarvelRivals" -Force | Out-Null
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

function Remove-MarvelQoS {
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MarvelRivals"
    if (Test-Path $qosPath) {
        Remove-Item -Path $qosPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Write-NVLog "[+]" "Политика QoS для Marvel Rivals удалена" -PrefixColor Green
    } else {
        Write-NVLog "[~]" "Политика QoS для Marvel Rivals не найдена" -PrefixColor Yellow
    }
}

function Invoke-MarvelRestore {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Откат настроек Marvel Rivals к резервным копиям..." -PrefixColor Yellow

    $configDir = Join-Path $env:LOCALAPPDATA "Marvel\Saved\Config\Windows"
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
        Set-ItemProperty -Path $engineFile -Name Attributes -Value ([System.IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
        Remove-Item -Path $engineFile -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Кастомный Engine.ini удалён (оригинальный файл отсутствовал)" -PrefixColor Green
    }

    # Откат launcher_config.xml
    $gamePath = Get-MarvelInstallPath
    if ($gamePath) {
        $xmlPath = Join-Path $gamePath "config\launcher_config.xml"
        $xmlBackup = Join-Path $gamePath "config\launcher_config.backup"
        if (Test-Path $xmlBackup) {
            Copy-Item -Path $xmlBackup -Destination $xmlPath -Force
            Remove-Item -Path $xmlBackup -Force -ErrorAction SilentlyContinue
            Write-NVLog "[+]" "launcher_config.xml восстановлен из резервной копии" -PrefixColor Green
        }
    }

    # Удаление QoS
    Remove-MarvelQoS

    Write-NVLog "[+]" "Откат завершён!" -PrefixColor Green
}

function Get-MarvelStatus {
    Show-NVBannerCyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host "                  ТЕКУЩИЙ СТАТУС ОПТИМИЗАЦИИ MARVEL RIVALS                    " -ForegroundColor Cyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host ""

    $gamePath = Get-MarvelInstallPath
    if ($gamePath) {
        Write-Host " [√] Каталог установки: " -NoNewline -ForegroundColor Green
        Write-Host "$gamePath" -ForegroundColor White
    } else {
        Write-Host " [?] Каталог установки: " -NoNewline -ForegroundColor Yellow
        Write-Host "Не обнаружен автоматически (стандартные папки Steam пусты)" -ForegroundColor DarkGray
    }

    $configDir = Join-Path $env:LOCALAPPDATA "Marvel\Saved\Config\Windows"
    $configFile = Join-Path $configDir "GameUserSettings.ini"
    $configBackup = Join-Path $configDir "GameUserSettings.backup"

    if (Test-Path $configFile) {
        Write-Host " [√] GameUserSettings.ini: " -NoNewline -ForegroundColor Green
        Write-Host "Присутствует" -ForegroundColor White
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
        $hasSettings = (Get-Content -Path $engineFile -Raw -ErrorAction SilentlyContinue) -match "\[SystemSettings\]"
        $statusText = if ($hasSettings) { "Оптимизирован [SystemSettings]" } else { "Стандартный" }
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

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\MarvelRivals"
    if (Test-Path $qosPath) {
        $dscp = (Get-ItemProperty -Path $qosPath -Name "DSCP Value" -ErrorAction SilentlyContinue)."DSCP Value"
        Write-Host " [√] Сетевая политика QoS: " -NoNewline -ForegroundColor Green
        Write-Host "Активна (DSCP $dscp для $nvexecn)" -ForegroundColor White
    } else {
        Write-Host " [-] Сетевая политика QoS: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Не настроена" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# Обработка неинтерактивного запуска по параметрам
switch ($Action) {
    "Settings" {
        Invoke-MarvelSettings
        return
    }
    "Engine" {
        Invoke-MarvelEngine
        return
    }
    "Debloat" {
        Invoke-MarvelDebloat
        return
    }
    "Launcher" {
        Invoke-MarvelLauncherConfig
        return
    }
    "QoS" {
        Invoke-MarvelQoS
        return
    }
    "Restore" {
        Invoke-MarvelRestore
        return
    }
    "Status" {
        if ($PSBoundParameters.ContainsKey("Action") -or $PSBoundParameters.Count -gt 0) {
            Get-MarvelStatus
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

    Write-Host "  [3] Очистка и Debloat игры (Удаление мусора, логов и дампов)" -ForegroundColor White
    Write-Host "  [4] Оптимизация лаунчера (Автозавершение лаунчера при старте)" -ForegroundColor White
    Write-Host "  [5] Сетевая политика QoS (DSCP 46 для Marvel Rivals)" -ForegroundColor White
    Write-Host "  [6] Восстановление настроек (Restore из резервных копий)" -ForegroundColor Green
    Write-Host "  [7] Текущий статус" -ForegroundColor Cyan
    Write-Host "  [8] Выход в главное меню" -ForegroundColor Red
    Write-Host ""
    Write-Host "  >> " -NoNewline -ForegroundColor Blue

    $choice = Read-Host

    switch ($choice) {
        "1" {
            Show-NVBannerCyan
            Write-Host " Применение соревновательного режима Marvel Rivals." -ForegroundColor White
            Write-Host ""
            Write-Host " Введите ширину разрешения (нажмите Enter для 1920) >> " -NoNewline -ForegroundColor Cyan
            $inX = Read-Host
            $finalX = if ($inX -match '^\d+$') { [int]$inX } else { 1920 }

            Write-Host " Введите высоту разрешения (нажмите Enter для 1080) >> " -NoNewline -ForegroundColor Cyan
            $inY = Read-Host
            $finalY = if ($inY -match '^\d+$') { [int]$inY } else { 1080 }

            Write-Host " Введите лимит FPS (0 - без лимита, 240, 360, Enter для 240) >> " -NoNewline -ForegroundColor Cyan
            $inFps = Read-Host
            $finalFps = if ($inFps -match '^\d+(\.\d+)?$') { $inFps } else { "240.000000" }

            Write-Host " Выберите пресет: [1] Performance (Макс. FPS)  [2] Balanced (Резкость 75%) >> " -NoNewline -ForegroundColor Cyan
            $inP = Read-Host
            $finalP = if ($inP -eq "2") { "Balanced" } else { "Performance" }

            Invoke-MarvelSettings -ResX $finalX -ResY $finalY -FPS $finalFps -PresetMode $finalP
            Start-Sleep -Seconds 2
        }
        "2" {
            Invoke-MarvelEngine
            Start-Sleep -Seconds 2
        }
        "3" {
            Invoke-MarvelDebloat
            Start-Sleep -Seconds 2
        }
        "4" {
            Invoke-MarvelLauncherConfig
            Start-Sleep -Seconds 2
        }
        "5" {
            Invoke-MarvelQoS
            Start-Sleep -Seconds 2
        }
        "6" {
            Invoke-MarvelRestore
            Start-Sleep -Seconds 2
        }
        "7" {
            Get-MarvelStatus
            Write-Host " Нажмите любую клавишу для возврата в меню..." -ForegroundColor DarkGray
            [Console]::ReadKey($true) | Out-Null
        }
        "8" {
            Write-NVLog "[/]" "Выход из утилиты Marvel Rivals" -PrefixColor Yellow
            return
        }
        default {
            Write-NVLog "[-]" "Неверный выбор" -PrefixColor Red
            Start-Sleep -Seconds 1
        }
    }
}