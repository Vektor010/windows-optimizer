#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Оптимизирует конфигурационный файл клиента Discord (%APPDATA%\discord\settings.json):
#    - Отключает аппаратное ускорение рендеринга интерфейса (enableHardwareAcceleration = false).
#    - Отключает отладочное логирование на диск (debugLogging = false).
#    - Отключает автозапуск при старте операционной системы (OPEN_ON_STARTUP = false).
#
# 2. ЗАЧЕМ:
#    Аппаратное ускорение интерфейса Discord использует видеопамять (VRAM) и блок кодирования GPU,
#    что приводит к конфликтам с видеодрайвером, падению частот и микрофризам в 3D-играх.
#    Отключение ускорения и логов высвобождает ресурсы видеокарты и защищает SSD от постоянной записи.
#
# 3. ПОСЛЕДСТВИЯ:
#    Интерфейс Discord рендерится процессором без задействования GPU, предотвращая сбои DirectX/Vulkan.
#    Discord перестает запускаться вместе с Windows.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые версии с установленным десктопным клиентом Discord).
#
# 5. ОТКАТ:
#    Запуск скрипта с ключом -Restore восстанавливает предыдущее состояние из резервной копии
#    settings.json.bak (или переводит флаги в значения по умолчанию: enableHardwareAcceleration = true,
#    debugLogging = true, OPEN_ON_STARTUP = true).
#
# 6. ИСТОЧНИК:
#    Официальная документация разработчиков Discord / Electron Framework:
#    https://discord.com/safety
#    Параметры запуска и конфигурации Chromium Embedded Framework.
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$discordDir   = Join-Path $env:APPDATA "discord"
$settingsPath = Join-Path $discordDir "settings.json"
$bakPath      = Join-Path $discordDir "settings.json.bak"

# 1. Проверка наличия приложения в системе
if (-not (Test-Path -LiteralPath $discordDir)) {
    if (-not $Quiet) {
        Write-Host "[-] Discord не обнаружен в системе, пропуск твика." -ForegroundColor DarkGray
    }
    return
}

# 2. Безопасное завершение активных процессов перед изменением файла
$proc = Get-Process discord -ErrorAction SilentlyContinue
if ($proc) {
    if (-not $Quiet) {
        Write-Host "[!] Обнаружены активные процессы Discord. Завершение для предотвращения перезаписи конфигурации..." -ForegroundColor Yellow
    }
    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

# 3. Режим отката (Rollback / -Restore)
if ($Restore) {
    if (Test-Path -LiteralPath $bakPath) {
        Copy-Item -LiteralPath $bakPath -Destination $settingsPath -Force
        if (-not $Quiet) {
            Write-Host "[+] Конфигурация Discord успешно восстановлена из резервной копии settings.json.bak!" -ForegroundColor Green
        }
    } elseif (Test-Path -LiteralPath $settingsPath) {
        try {
            $json = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $json.enableHardwareAcceleration = $true
            $json.debugLogging               = $true
            $json.OPEN_ON_STARTUP            = $true
            $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
            if (-not $Quiet) {
                Write-Host "[+] Параметры Discord сброшены на стандартные (ускорение ВКЛ, логи ВКЛ, автозапуск ВКЛ)" -ForegroundColor Green
            }
        } catch {
            Write-Error "Ошибка при откате настроек Discord: $_"
        }
    }
    return
}

# 4. Режим применения оптимизации
if ($PSCmdlet.ShouldProcess($settingsPath, "Применить оптимизацию конфигурации Discord")) {
    # Создание резервной копии перед первым изменением
    if ((Test-Path -LiteralPath $settingsPath) -and -not (Test-Path -LiteralPath $bakPath)) {
        Copy-Item -LiteralPath $settingsPath -Destination $bakPath -Force
    }

    if (-not (Test-Path -LiteralPath $settingsPath)) {
        $json = [PSCustomObject]@{
            enableHardwareAcceleration = $false
            debugLogging               = $false
            OPEN_ON_STARTUP            = $false
        }
    } else {
        try {
            $json = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $json.enableHardwareAcceleration = $false
            $json.debugLogging               = $false
            $json.OPEN_ON_STARTUP            = $false
        } catch {
            Write-Error "Не удалось прочитать файл конфигурации $settingsPath : $_"
            return
        }
    }

    $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    if (-not $Quiet) {
        Write-Host "[+] Конфигурация Discord успешно оптимизирована (аппаратное ускорение ВЫКЛ, логи ВЫКЛ, автозапуск ВЫКЛ)!" -ForegroundColor Green
    }
}