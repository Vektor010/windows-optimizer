# ==============================================================================
# Gaming & System Optimizer - Оптимизация прикладных программ и браузеров
# Охватывает: Discord, Chromium/Yandex/Brave/Edge, SteelSeries Sonar, VS Code
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Применение оптимизаций прикладных программ (Gaming & System Optimizer)..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: Оптимизация конфигурации Discord (settings.json)
# Что делает: Отключает аппаратное ускорение рендеринга интерфейса (enableHardwareAcceleration = false), отладочное логирование (debugLogging = false) и автозапуск при старте системы (OPEN_ON_STARTUP = false).
# Зачем нужно: Предотвращает конфликт кодировщиков видеопамяти GPU с активными играми, снижает нагрузку на видеокарту RTX 5080 и исключает фоновый автозапуск.
# Значение по умолчанию: enableHardwareAcceleration = true, debugLogging = true, OPEN_ON_STARTUP = true
# Значение после твика: Все параметры переведены в false
# Источник: Gaming & System Optimizer: Voice Chat & Streaming Apps
# ─────────────────────────────────────────────
function Optimize-Discord {
    $script = Join-Path $PSScriptRoot "Discord-Tweaks.ps1"
    if (Test-Path -LiteralPath $script) {
        & $script -Apply -Quiet
    } else {
        $discordPath = "$env:APPDATA\discord"
        $settingsPath = Join-Path $discordPath "settings.json"
        if (Test-Path $settingsPath) {
            try {
                $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
                $json.enableHardwareAcceleration = $false
                $json.debugLogging = $false
                $json.OPEN_ON_STARTUP = $false
                $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                Write-Host " [+] Конфигурация Discord оптимизирована (аппаратное ускорение ВЫКЛ, логирование ВЫКЛ, автозапуск ВЫКЛ)" -ForegroundColor Green
            } catch {
                Write-Host " [!] Ошибка обновления настроек Discord: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host " [-] Файл настроек Discord settings.json не обнаружен (Discord не установлен)" -ForegroundColor DarkGray
        }
    }
}

# ─────────────────────────────────────────────
# Название: Групповые политики браузеров Chromium (Chrome, Brave, Edge, Yandex)
# Что делает: Запрещает браузерам оставлять скрытые фоновые процессы после закрытия главного окна (BackgroundModeEnabled = 0) и отключает сбор телеметрии (MetricsReportingEnabled = 0).
# Зачем нужно: Мгновенно высвобождает оперативную память и процессорные потоки перед запуском тяжелых соревновательных игр, блокирует сетевые телеметрические запросы.
# Значение по умолчанию: BackgroundModeEnabled = 1 (разрешено), MetricsReportingEnabled = 1 (включено)
# Значение после твика: 0 (DWord, принудительно запрещено)
# Источник: Gaming & System Optimizer: Browsers & Background Workloads
# ─────────────────────────────────────────────
function Optimize-ChromiumBrowsers {
    $script = Join-Path $PSScriptRoot "Browsers-Tweaks.ps1"
    if (Test-Path -LiteralPath $script) {
        & $script
    } else {
        $policies = @(
            "HKLM:\SOFTWARE\Policies\YandexBrowser",
            "HKLM:\SOFTWARE\Policies\Google\Chrome",
            "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave",
            "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        )
        foreach ($pol in $policies) {
            if (-not (Test-Path $pol)) { New-Item -Path $pol -Force | Out-Null }
            Set-ItemProperty -Path $pol -Name "BackgroundModeEnabled" -Type DWord -Value 0 -Force
            Set-ItemProperty -Path $pol -Name "MetricsReportingEnabled" -Type DWord -Value 0 -Force
        }
        Write-Host " [+] Политики браузеров применены (фоновые процессы после закрытия отключены, телеметрия ВЫКЛ)" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────
# Название: Отключение фонового аудиомодуля SteelSeries Sonar / GG
# Что делает: Останавливает и переводит в режим Disabled службы виртуального аудиодрайвера SteelSeries (SteelSeriesSonar, SteelSeriesGGClient, SteelSeriesAudioService).
# Зачем нужно: Модуль Sonar создает виртуальный промежуточный аудиослой, добавляющий до 20 мс инпут-лага звука и вызывающий скачки DPC Latency. Отключение восстанавливает прямой битовый вывод звука в играх.
# Значение по умолчанию: Службы активны в фоновом режиме (Automatic).
# Значение после твика: Службы остановлены и отключены (Disabled, Stopped).
# Источник: Gaming & System Optimizer: Peripherals & Audio Latency
# ─────────────────────────────────────────────
function Disable-SteelSeriesSonar {
    $script = Join-Path $PSScriptRoot "SteelSeries-Tweaks.ps1"
    if (Test-Path -LiteralPath $script) {
        & $script
    } else {
        $services = @("SteelSeriesSonar", "SteelSeriesGGClient", "SteelSeriesAudioService")
        $found = $false
        foreach ($s in $services) {
            if (Get-Service $s -ErrorAction SilentlyContinue) {
                Stop-Service $s -Force -ErrorAction SilentlyContinue
                Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host " [+] Служба SteelSeries Sonar отключена: $s" -ForegroundColor Green
                $found = $true
            }
        }
        if (-not $found) {
            Write-Host " [-] Службы SteelSeries Sonar / GG не обнаружены в системе" -ForegroundColor DarkGray
        }
    }
}

# ─────────────────────────────────────────────
# Название: Отключение телеметрии и фоновых экспериментов VS Code / VSCodium
# Что делает: Записывает в пользовательский settings.json полный отказ от телеметрии (telemetryLevel = 'off'), отключает сбор дампов падений, фоновые онлайн-эксперименты A/B и переводит обновления в ручной режим.
# Зачем нужно: Полностью ликвидирует паразитный сетевой трафик к серверам аналитики Microsoft и фоновые дисковые обращения при работе с кодом.
# Значение по умолчанию: telemetryLevel = 'all', enableExperiments = true, update.mode = 'default'
# Значение после твика: telemetryLevel = 'off', все телеметрические флаги = false, update.mode = 'manual'
# Источник: Gaming & System Optimizer: Code Editors & Developer Tools
# ─────────────────────────────────────────────
function Optimize-VSCode {
    $script = Join-Path $PSScriptRoot "VSCode-Tweaks.ps1"
    if (Test-Path -LiteralPath $script) {
        & $script
    } else {
        $vscodePaths = @(
            "$env:APPDATA\Code\User\settings.json",
            "$env:APPDATA\VSCodium\User\settings.json"
        )
        foreach ($vscPath in $vscodePaths) {
            if (Test-Path (Split-Path $vscPath -Parent)) {
                try {
                    $dir = Split-Path $vscPath -Parent
                    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    $settings = @{}
                    if (Test-Path $vscPath) {
                        $raw = Get-Content $vscPath -Raw
                        if ($raw.Trim().Length -gt 0) {
                            $parsed = $raw | ConvertFrom-Json
                            if ($parsed) {
                                foreach ($prop in $parsed.PSObject.Properties) {
                                    $settings[$prop.Name] = $prop.Value
                                }
                            }
                        }
                    }
                    $settings["telemetry.telemetryLevel"] = "off"
                    $settings["telemetry.enableCrashReporter"] = $false
                    $settings["telemetry.enableTelemetry"] = $false
                    $settings["workbench.enableExperiments"] = $false
                    $settings["update.mode"] = "manual"
                    $settings["update.showReleaseNotes"] = $false
                    $settings["extensions.ignoreRecommendations"] = $true
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $vscPath -Encoding UTF8
                    Write-Host " [+] Конфигурация редактора оптимизирована: $vscPath" -ForegroundColor Green
                } catch {
                    Write-Host " [!] Ошибка настройки параметров VSCode: $_" -ForegroundColor Yellow
                }
            }
        }
    }
}

Write-Host " [1/4] Оптимизация Discord..." -ForegroundColor Yellow
Optimize-Discord

Write-Host " [2/4] Оптимизация политик браузеров Chromium..." -ForegroundColor Yellow
Optimize-ChromiumBrowsers

Write-Host " [3/4] Проверка и отключение служб SteelSeries Sonar..." -ForegroundColor Yellow
Disable-SteelSeriesSonar

Write-Host " [4/4] Оптимизация VS Code / VSCodium..." -ForegroundColor Yellow
Optimize-VSCode

Write-Host "`n[✓] Оптимизация прикладных программ (4/4) завершена успешно!" -ForegroundColor Green