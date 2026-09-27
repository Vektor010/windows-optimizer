<#
================================================================================
Имя твика:              Оптимизация Overwatch 2 (NV-OW-Tool)
Что делает:             1. Настраивает соревновательный конфигурационный файл Settings_v0.ini:
                           - Отключение вступительного видеоролика (ShowIntro = 0).
                           - Включение высокочастотного опроса мыши (HighTickInput = 1).
                           - Принудительный полноэкранный режим (FullscreenWindow = 0, WindowMode = 0).
                           - Отключение сглаживания (AADetail = 0) для максимальной четкости и FPS.
                           - Настройка кастомного лимита кадров (FrameRateCap) под герцовку монитора.
                           - Управление NVIDIA Reflex Low Latency (ReflexMode: 0 = Off, 1 = On).
                           - Отключение каскадных теней воды и упрощение теней (SimpleDirectionalShadows).
                           - Включение отображения FPS, сетевого пинга RTT и системных часов на экране.
                           - Оптимизация звукового микса под наушники (AudioMix = 6) и отключение музыки в матче.
                           - Сохранение уникального аппаратного блока [GPU.6] и частоты развёртки монитора.
                        2. Настраивает сетевую политику качества обслуживания QoS:
                           - Приоритезация сетевого трафика (DSCP 46) для процесса Overwatch.exe.
                        3. Поддерживает функцию отката (Restore):
                           - Мгновенное восстановление оригинального Settings_v0.ini из бэкапа (.backup).
                           - Удаление правил QoS из реестра Windows.
Зачем нужно:            Снижает системный инпутлаг рендеринга (движок Blizzard Engine), устраняет микрозадержки
                        ввода мыши при высоких частотах опроса (1000–8000 Гц), обеспечивает минимальный джиттер
                        и приоритет соревновательных пакетов на сетевом оборудовании.
Значение по умолчанию:  Стандартный конфиг с вступительными роликами, сглаживанием, включенной фоновой музыкой
                        и отсутствием сетевого приоритета QoS.
Значение после твика:   Соревновательный конфиг с HighTickInput=1, Reflex On, оптимизированным звуком,
                        сетевые пакеты Overwatch.exe передаются с приоритетом DSCP 46.
Источник:               Официальное руководство Gaming & System Optimizer и репозиторий github.com/system-optimizer
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Settings", "QoS", "Restore", "Status")]
    [string]$Action = "Status",

    [Parameter(ParameterSetName = "Settings")]
    [switch]$Settings,

    [Parameter(ParameterSetName = "QoS")]
    [switch]$QoS,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore,

    [Parameter()]
    [string]$FPSLimit = "240",

    [Parameter()]
    [ValidateSet("0", "1")]
    [string]$ShadowDetail = "1",

    [Parameter()]
    [ValidateSet("0", "1")]
    [string]$Reflex = "1"
)

if ($Settings) { $Action = "Settings" }
if ($QoS)      { $Action = "QoS" }
if ($Restore)  { $Action = "Restore" }

$nvexecn = "Overwatch.exe"

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

function Invoke-OverwatchSettings {
    param(
        [string]$FPS = $FPSLimit,
        [string]$Shadow = $ShadowDetail,
        [string]$ReflexSetting = $Reflex
    )

    Show-NVBannerCyan
    Write-NVLog "[~]" "Применение соревновательного профиля Settings_v0.ini..." -PrefixColor Yellow

    $settingsDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Overwatch\Settings"
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
    }

    $settingsFile = Join-Path $settingsDir "Settings_v0.ini"
    $backupFile = Join-Path $settingsDir "Settings_v0.backup"

    $gpuLines = [System.Collections.Generic.List[string]]::new()
    $fullScreenRefresh = ""
    $windowedRefresh = ""

    if (Test-Path $settingsFile) {
        if (-not (Test-Path $backupFile)) {
            Copy-Item -Path $settingsFile -Destination $backupFile -Force
            Write-NVLog "[+]" "Создана резервная копия:" "$backupFile" -PrefixColor Green
        }

        # Чтение существующего конфига для извлечения параметров GPU и частоты развёртки
        $lines = Get-Content -Path $settingsFile -Encoding UTF8 -ErrorAction SilentlyContinue
        $inGpu = $false
        foreach ($line in $lines) {
            if ($line -match '^\[GPU\.') {
                $inGpu = $true
                $gpuLines.Add($line)
                continue
            }
            if ($inGpu) {
                if ($line -match '^\[') {
                    $inGpu = $false
                } else {
                    $gpuLines.Add($line)
                }
            }
            if ($line -match '^FullScreenRefresh = "\d+"$') {
                $fullScreenRefresh = $line
            }
            if ($line -match '^WindowedRefresh = "\d+"$') {
                $windowedRefresh = $line
            }
        }
    }

    # Построение оптимизированного файла конфигурации (System template)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("[Cinematics.1]")
    $null = $sb.AppendLine('ShowIntro = "0"')

    if ($gpuLines.Count -gt 0) {
        foreach ($gl in $gpuLines) {
            $null = $sb.AppendLine($gl)
        }
    }

    $null = $sb.AppendLine("[Input.1]")
    $null = $sb.AppendLine('HighTickInput = "1"')

    $null = $sb.AppendLine("[Render.13]")
    $null = $sb.AppendLine('AADetail = "0"')
    $null = $sb.AppendLine("FrameRateCap = `"$FPS`"")
    if ($fullScreenRefresh) {
        $null = $sb.AppendLine($fullScreenRefresh)
    }
    $null = $sb.AppendLine('FullscreenWindow = "0"')
    $null = $sb.AppendLine('FullscreenWindowEnabled = "1"')
    $null = $sb.AppendLine('GFXPresetLevel = "1"')
    $null = $sb.AppendLine('ImageSharpening = "0.000000"')
    $null = $sb.AppendLine('PhysicsQuality = "3"')
    $null = $sb.AppendLine("ReflexMode = `"$ReflexSetting`"")
    $null = $sb.AppendLine('ShowFPSCounter = "1"')
    $null = $sb.AppendLine('ShowRTT = "1"')
    $null = $sb.AppendLine('ShowSystemClock = "1"')
    $null = $sb.AppendLine("SimpleDirectionalShadows = `"$Shadow`"")
    $null = $sb.AppendLine('TextureDetail = "2"')
    $null = $sb.AppendLine('UseCustomFrameRates = "1"')
    $null = $sb.AppendLine('UseCustomWorldScale = "1"')
    $null = $sb.AppendLine('WaterCombineCascades = "0"')
    if ($windowedRefresh) {
        $null = $sb.AppendLine($windowedRefresh)
    }
    $null = $sb.AppendLine('WindowMode = "0"')

    $null = $sb.AppendLine("[Sound.3]")
    $null = $sb.AppendLine('AudioMix = "6"')
    $null = $sb.AppendLine('MusicVolume = "0.000000"')

    $null = $sb.AppendLine("[TankMenuItems.1]")
    $null = $sb.AppendLine('FPSOverlay = "0"')

    [System.IO.File]::WriteAllText($settingsFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-NVLog "[+]" "Соревновательные настройки Overwatch 2 успешно применены!" -PrefixColor Green
}

function Invoke-OverwatchQoS {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Применение сетевой политики QoS (DSCP 46)..." -PrefixColor Yellow

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Overwatch"
    if (-not (Test-Path $qosPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS" -Name "Overwatch" -Force | Out-Null
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

function Remove-OverwatchQoS {
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Overwatch"
    if (Test-Path $qosPath) {
        Remove-Item -Path $qosPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Write-NVLog "[+]" "Политика QoS для Overwatch удалена" -PrefixColor Green
    } else {
        Write-NVLog "[~]" "Политика QoS для Overwatch не найдена" -PrefixColor Yellow
    }
}

function Invoke-OverwatchRestore {
    Show-NVBannerCyan
    Write-NVLog "[~]" "Откат настроек Overwatch к резервным копиям..." -PrefixColor Yellow

    $settingsDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Overwatch\Settings"
    $settingsFile = Join-Path $settingsDir "Settings_v0.ini"
    $backupFile = Join-Path $settingsDir "Settings_v0.backup"

    # Откат Settings_v0.ini
    if (Test-Path $backupFile) {
        if (Test-Path $settingsFile) {
            Remove-Item -Path $settingsFile -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $backupFile -Destination $settingsFile -Force
        Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Settings_v0.ini восстановлен из резервной копии" -PrefixColor Green
    } elseif (Test-Path $settingsFile) {
        Remove-Item -Path $settingsFile -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Кастомный Settings_v0.ini удалён (оригинальный файл отсутствовал)" -PrefixColor Green
    } else {
        Write-NVLog "[~]" "Settings_v0.ini не найден" -PrefixColor Yellow
    }

    # Удаление QoS
    Remove-OverwatchQoS

    Write-NVLog "[+]" "Откат завершён!" -PrefixColor Green
}

function Get-OverwatchStatus {
    Show-NVBannerCyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host "                    ТЕКУЩИЙ СТАТУС ОПТИМИЗАЦИИ OVERWATCH                      " -ForegroundColor Cyan
    Write-Host " ==============================================================================" -ForegroundColor DarkCyan
    Write-Host ""

    $settingsDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Overwatch\Settings"
    $settingsFile = Join-Path $settingsDir "Settings_v0.ini"
    $backupFile = Join-Path $settingsDir "Settings_v0.backup"

    if (Test-Path $settingsFile) {
        $hasHighTick = (Get-Content -Path $settingsFile -Raw -ErrorAction SilentlyContinue) -match 'HighTickInput = "1"'
        $statusText = if ($hasHighTick) { "Оптимизирован (HighTickInput=1)" } else { "Стандартный" }
        Write-Host " [√] Settings_v0.ini: " -NoNewline -ForegroundColor Green
        Write-Host "$statusText" -ForegroundColor White
    } else {
        Write-Host " [-] Settings_v0.ini: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Не создан (игра ещё не запускалась)" -ForegroundColor DarkGray
    }

    if (Test-Path $backupFile) {
        Write-Host " [√] Резервная копия конфига: " -NoNewline -ForegroundColor Green
        Write-Host "$backupFile" -ForegroundColor DarkGray
    }

    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\Overwatch"
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
        Invoke-OverwatchSettings
        return
    }
    "QoS" {
        Invoke-OverwatchQoS
        return
    }
    "Restore" {
        Invoke-OverwatchRestore
        return
    }
    "Status" {
        if ($PSBoundParameters.ContainsKey("Action") -or $PSBoundParameters.Count -gt 0) {
            Get-OverwatchStatus
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
    Write-Host "Settings_v0.ini" -NoNewline -ForegroundColor Yellow
    Write-Host "' (FPS, Reflex, HighTickInput, Звук)" -ForegroundColor White

    Write-Host "  [2] Сетевая политика QoS (DSCP 46 для Overwatch.exe)" -ForegroundColor White
    Write-Host "  [3] Восстановление настроек (Restore из резервной копии)" -ForegroundColor Green
    Write-Host "  [4] Текущий статус" -ForegroundColor Cyan
    Write-Host "  [5] Выход в главное меню" -ForegroundColor Red
    Write-Host ""
    Write-Host "  >> " -NoNewline -ForegroundColor Blue

    $choice = Read-Host

    switch ($choice) {
        "1" {
            Show-NVBannerCyan
            Write-Host " Применение соревновательного режима Overwatch 2." -ForegroundColor White
            Write-Host ""
            Write-Host " Введите лимит FPS (нажмите Enter для 240) >> " -NoNewline -ForegroundColor Cyan
            $inFps = Read-Host
            $finalFps = if ($inFps -match '^\d+$') { $inFps } else { "240" }

            Write-Host " Тени: [0] Простые/Выкл  [1] Низкие (Enter для 0) >> " -NoNewline -ForegroundColor Cyan
            $inShadow = Read-Host
            $finalShadow = if ($inShadow -eq "1") { "0" } else { "1" }

            Write-Host " Режим NVIDIA Reflex: [0] Выкл  [1] Вкл (Enter для 1) >> " -NoNewline -ForegroundColor Cyan
            $inRef = Read-Host
            $finalRef = if ($inRef -eq "0") { "0" } else { "1" }

            Invoke-OverwatchSettings -FPS $finalFps -Shadow $finalShadow -ReflexSetting $finalRef
            Start-Sleep -Seconds 2
        }
        "2" {
            Invoke-OverwatchQoS
            Start-Sleep -Seconds 2
        }
        "3" {
            Invoke-OverwatchRestore
            Start-Sleep -Seconds 2
        }
        "4" {
            Get-OverwatchStatus
            Write-Host " Нажмите любую клавишу для возврата в меню..." -ForegroundColor DarkGray
            [Console]::ReadKey($true) | Out-Null
        }
        "5" {
            Write-NVLog "[/]" "Выход из утилиты Overwatch" -PrefixColor Yellow
            return
        }
        default {
            Write-NVLog "[-]" "Неверный выбор" -PrefixColor Red
            Start-Sleep -Seconds 1
        }
    }
}