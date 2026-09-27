# ==============================================================================
# Gaming & System Optimizer - Комплексная оптимизация клиента Steam, CEF и оверлея
# ==============================================================================
# Назначение:
#   Комплексная настройка клиента Steam для минимизации задержек ввода, устранения
#   микрофризов от оверлея и освобождения оперативной/видеопамяти от фоновых
#   процессов Chromium Embedded Framework (CEF / steamwebhelper.exe).
#
# Содержит 3 этапа:
#   [1/3] Конфигурация localconfig.vdf (низкая нагрузка, отключение оверлея)
#   [2/3] Оптимизация параметров рендеринга CEF в реестре (HKCU:\Software\Valve\Steam)
#   [3/3] Управление модулем NoSteamWebHelper (umpdc.dll v5.0.2)
# ==============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter()]
    [switch]$InstallCEFKiller,

    [Parameter()]
    [switch]$RemoveCEFKiller,

    [Parameter()]
    [switch]$RunConfigOnly,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$steamReg = "HKCU:\Software\Valve\Steam"
$regVal   = Get-ItemProperty -Path $steamReg -Name "SteamPath" -ErrorAction SilentlyContinue
$steamPath = if ($regVal -and $regVal.SteamPath) { $regVal.SteamPath } else { "${env:ProgramFiles(x86)}\Steam" }

# Проверка наличия приложения в системе
if (-not (Test-Path -LiteralPath $steamPath) -and -not (Test-Path -LiteralPath $steamReg)) {
    if (-not $Quiet) {
        Write-Host "[-] Steam не обнаружен в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

$regBackupPath = Join-Path $steamPath "userdata\steam_reg_backup.json"

if (-not $Quiet) {
    Write-Host ">>> Оптимизация игрового клиента Steam (Gaming & System Optimizer)..." -ForegroundColor Cyan
    Write-Host "Каталог установки Steam: $steamPath" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# РЕЖИМ ОТКАТА (Rollback / -Restore)
# ------------------------------------------------------------------------------
if ($Restore) {
    if (-not $Quiet) {
        Write-Host "`n[ОТКАТ] Восстановление настроек Steam по умолчанию..." -ForegroundColor Yellow
    }

    # 1. Остановка процессов Steam
    $p = Get-Process steam* -ErrorAction SilentlyContinue
    if ($p) {
        if (-not $Quiet) { Write-Host " Завершение процессов Steam..." -ForegroundColor DarkGray }
        $p | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # 2. Откат localconfig.vdf из .bak
    $configScript = Join-Path $PSScriptRoot "Steam-Config.ps1"
    if (Test-Path -LiteralPath $configScript) {
        if ($Quiet) {
            & $configScript -Restore -Quiet
        } else {
            & $configScript -Restore
        }
    }

    # 3. Восстановление параметров реестра HKCU:\Software\Valve\Steam
    if (Test-Path -LiteralPath $steamReg) {
        if (Test-Path -LiteralPath $regBackupPath) {
            try {
                $snapshot = Get-Content -LiteralPath $regBackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($prop in $snapshot.PSObject.Properties) {
                    if ($null -ne $prop.Value) {
                        Set-ItemProperty -Path $steamReg -Name $prop.Name -Value $prop.Value -Type DWord -Force
                    } else {
                        Remove-ItemProperty -Path $steamReg -Name $prop.Name -ErrorAction SilentlyContinue
                    }
                }
                Remove-Item -LiteralPath $regBackupPath -Force -ErrorAction SilentlyContinue
                if (-not $Quiet) {
                    Write-Host " [+] Параметры реестра Steam восстановлены из снимка резервной копии" -ForegroundColor Green
                }
            } catch {
                Set-ItemProperty -Path $steamReg -Name "GPUAccelWebViewsV3" -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $steamReg -Name "H264HWAccel" -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $steamReg -Name "SmoothScrollWebViews" -Value 1 -Type DWord -Force
                Remove-ItemProperty -Path $steamReg -Name "DWriteEnable" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $steamReg -Name "DPIScaling" -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $steamReg -Name "OverlayScaleInterface" -Value 1 -Type DWord -Force
                if (-not $Quiet) {
                    Write-Host " [+] Параметры реестра Steam возвращены в исходное состояние по умолчанию" -ForegroundColor Green
                }
            }
        } else {
            Set-ItemProperty -Path $steamReg -Name "GPUAccelWebViewsV3" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $steamReg -Name "H264HWAccel" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $steamReg -Name "SmoothScrollWebViews" -Value 1 -Type DWord -Force
            Remove-ItemProperty -Path $steamReg -Name "DWriteEnable" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $steamReg -Name "DPIScaling" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $steamReg -Name "OverlayScaleInterface" -Value 1 -Type DWord -Force
            if (-not $Quiet) {
                Write-Host " [+] Параметры реестра Steam возвращены в исходное состояние (CEF ускорение включено)" -ForegroundColor Green
            }
        }
    }

    # 4. Удаление umpdc.dll если установлена
    $umpdcPath = Join-Path $steamPath "umpdc.dll"
    if (Test-Path -LiteralPath $umpdcPath) {
        Remove-Item -Path $umpdcPath -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) {
            Write-Host " [+] Модуль umpdc.dll удален из каталога Steam" -ForegroundColor Green
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[✓] Откат настроек клиента Steam успешно завершен!" -ForegroundColor Green
    }
    return
}

# Завершение процессов Steam перед применением любых настроек,
# чтобы Steam не перезаписал конфигурацию из памяти при закрытии
$p = Get-Process steam* -ErrorAction SilentlyContinue
if ($p) {
    if (-not $Quiet) {
        Write-Host " Завершение процессов Steam для безопасной записи конфигурации..." -ForegroundColor DarkGray
    }
    $p | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# ==============================================================================
# [1/3] Применение низкоуровневой конфигурации localconfig.vdf
#
# Включает:
#   - EnableGameOverlay = 0 : Отключение хуков оверлея GameOverlayRenderer
#   - LibraryLowBandwidthMode = 1 : Режим низкой пропускной способности библиотеки
#   - LibraryLowPerfMode = 1 : Режим низкой производительности (отключение эффектов CEF)
#   - LibraryDisableCommunityContent = 1 : Отключение подгрузки скриншотов/артов сообщества
#   - ReduceMotion = 1 : Отключение плавной анимации интерфейса
#   - Permissions = 0 : Полное отключение вещания/стримов
#   - EnableStreaming = 0 : Отключение Remote Play
#   - SignIntoFriends = 0 : Отключение автоматического входа в друзья при старте
#   - BackgroundRecordMode = 0 : Отключение фоновой записи видео геймплея
#   - NotifyAvailableGames = 0 : Отключение всплывающих баннеров скидок/новостей
#   - NetworkingAllowShareIP = 1 : Защита прямого IP (только друзья / SDR relay)
# ==============================================================================
$configScript = Join-Path $PSScriptRoot "Steam-Config.ps1"
if (Test-Path -LiteralPath $configScript) {
    if (-not $Quiet) {
        Write-Host "`n[1/3] Применение профиля производительности localconfig.vdf..." -ForegroundColor Yellow
    }
    if ($Quiet) {
        & $configScript -Quiet
    } else {
        & $configScript
    }
    if (-not $Quiet) {
        Write-Host " [+] Конфигурация интерфейса Steam обновлена (оверлей выключен, облегченный режим включен)" -ForegroundColor Green
    }
} else {
    if (-not $Quiet) {
        Write-Host " [-] Скрипт Steam-Config.ps1 не найден в каталоге scripts" -ForegroundColor Red
    }
}

if ($RunConfigOnly) {
    if (-not $Quiet) {
        Write-Host "`n[✓] Режим -RunConfigOnly: завершено без изменения реестра и CEF модуля." -ForegroundColor Green
    }
    return
}

# ==============================================================================
# [2/3] Оптимизация параметров реестра клиента Steam
# Каталог: HKCU:\Software\Valve\Steam
#
# 1. GPUAccelWebViewsV3 (DWord = 0)
#    Имя: Отключение GPU аппаратного ускорения веб-страниц CEF
#    Что делает: Запрещает процессам steamwebhelper.exe использовать GPU для рендера
#    Зачем нужно: Освобождает VRAM, исключает борьбу за GPU-ресурсы с 3D-игрой
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
#
# 2. H264HWAccel (DWord = 0)
#    Имя: Отключение аппаратного H.264 декодирования видео в CEF
#    Что делает: Отключает GPU-видеодекодер для встроенных видеороликов магазина
#    Зачем нужно: Исключает падение частоты видеоядра и фоновую загрузку блока NVDEC/VPU
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
#
# 3. SmoothScrollWebViews (DWord = 0)
#    Имя: Отключение плавной прокрутки страниц CEF
#    Что делает: Устраняет интерполяцию кадров анимации при прокрутке веб-интерфейса
#    Зачем нужно: Снижает расход процессорного времени и устраняет инпут-лаг скролла
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
#
# 4. DWriteEnable (DWord = 0)
#    Имя: Отключение сглаживания шрифтов DirectWrite в CEF
#    Что делает: Отключает библиотеку DirectWrite при отрисовке веб-интерфейса Steam
#    Зачем нужно: Ускоряет генерацию кадров интерфейса и разгружает движок рендеринга
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
#
# 5. DPIScaling (DWord = 0)
#    Имя: Отключение виртуального масштабирования DPI
#    Что делает: Запрещает апскейлинг интерфейса Steam на экранах с высоким разрешением
#    Зачем нужно: Устраняет размытие шрифтов и оверхед видеокарты на растягивание
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
#
# 6. OverlayScaleInterface (DWord = 0)
#    Имя: Отключение масштабирования интерфейса оверлея Steam
#    Что делает: Блокирует растягивание оверлея под высокое разрешение дисплея
#    Зачем нужно: Устраняет выделение лишней памяти и лаги при вызове оверлея
#    По умолчанию: 1 (Включено)
#    После твика: 0 (Выключено)
# ==============================================================================
if (-not $Quiet) {
    Write-Host "`n[2/3] Оптимизация параметров реестра клиента Steam..." -ForegroundColor Yellow
}

if (Test-Path -LiteralPath $steamReg) {
    # Резервное копирование снимка реестра перед изменением
    $targetParams = @("GPUAccelWebViewsV3", "H264HWAccel", "SmoothScrollWebViews", "DWriteEnable", "DPIScaling", "OverlayScaleInterface")
    $userdataDir = Join-Path $steamPath "userdata"
    if ((Test-Path -LiteralPath $userdataDir) -and -not (Test-Path -LiteralPath $regBackupPath)) {
        try {
            $regSnapshot = [ordered]@{}
            foreach ($name in $targetParams) {
                $val = Get-ItemProperty -Path $steamReg -Name $name -ErrorAction SilentlyContinue
                if ($null -ne $val -and $null -ne $val.$name) {
                    $regSnapshot[$name] = $val.$name
                } else {
                    $regSnapshot[$name] = $null
                }
            }
            $regSnapshot | ConvertTo-Json | Set-Content -LiteralPath $regBackupPath -Encoding UTF8
        } catch {
            Write-Verbose "Не удалось сохранить резервный снимок реестра: $_"
        }
    }

    Set-ItemProperty -Path $steamReg -Name "GPUAccelWebViewsV3" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "H264HWAccel" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "SmoothScrollWebViews" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "DWriteEnable" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "DPIScaling" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "OverlayScaleInterface" -Value 0 -Type DWord -Force
    if (-not $Quiet) {
        Write-Host " [+] Параметры реестра применены: аппаратное ускорение CEF, декодирование видео и сглаживание DirectWrite отключены" -ForegroundColor Green
    }
} else {
    if (-not $Quiet) {
        Write-Host " [!] Раздел реестра Steam ($steamReg) не обнаружен." -ForegroundColor DarkGray
    }
}

# ==============================================================================
# [3/3] Управление модулем NoSteamWebHelper (umpdc.dll v5.0.2)
#
# Что делает:
#   Библиотека umpdc.dll отслеживает переменную RunningAppID в Steam.
#   При запуске любой игры она автоматически завершает все фоновые процессы
#   steamwebhelper.exe (Chromium Embedded Framework), освобождая от 500 МБ до 1 ГБ RAM.
#   После выхода из игры интерфейс Steam автоматически восстанавливается.
# ==============================================================================
$umpdcPath = Join-Path $steamPath "umpdc.dll"

if ($RemoveCEFKiller) {
    if (-not $Quiet) {
        Write-Host "`n[3/3] Удаление модуля NoSteamWebHelper (umpdc.dll)..." -ForegroundColor Yellow
    }
    if (Test-Path -LiteralPath $umpdcPath) {
        $p = Get-Process steam* -ErrorAction SilentlyContinue
        if ($p) { $p | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
        Remove-Item -Path $umpdcPath -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) {
            Write-Host " [+] Модуль umpdc.dll успешно удален (SteamWebHelper будет работать в обычном режиме)" -ForegroundColor Yellow
        }
    } else {
        if (-not $Quiet) {
            Write-Host " [!] Модуль umpdc.dll в данный момент не установлен." -ForegroundColor DarkGray
        }
    }
} elseif ($InstallCEFKiller) {
    if (-not $Quiet) {
        Write-Host "`n[3/3] Установка модуля NoSteamWebHelper (umpdc.dll v5.0.2)..." -ForegroundColor Yellow
    }
    try {
        $p = Get-Process steam* -ErrorAction SilentlyContinue
        if ($p) {
            if (-not $Quiet) { Write-Host " Закрытие процессов Steam для замены библиотеки..." -ForegroundColor DarkGray }
            $p | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        $url = "https://github.com/Aetopia/NoSteamWebHelper/releases/download/v5.0.2/umpdc.dll"
        Invoke-WebRequest -Uri $url -OutFile $umpdcPath -Headers @{"User-Agent"="PowerShell"} -UseBasicParsing
        if (-not $Quiet) {
            Write-Host " [+] umpdc.dll успешно установлена в каталог Steam!" -ForegroundColor Green
            Write-Host "     При запуске любой игры процессы steamwebhelper.exe будут автоматически выгружаться." -ForegroundColor Cyan
            Write-Host "     При закрытии игры интерфейс Steam автоматически восстановится." -ForegroundColor Cyan
        }
    } catch {
        if (-not $Quiet) {
            Write-Host " [-] Не удалось загрузить/установить umpdc.dll: $_" -ForegroundColor Red
        }
    }
} else {
    if (-not $Quiet) {
        Write-Host "`n[3/3] Статус модуля NoSteamWebHelper (umpdc.dll):" -ForegroundColor Yellow
        if (Test-Path -LiteralPath $umpdcPath) {
            Write-Host " [+] Модуль установлен: фоновые процессы CEF автоматически выгружаются во время игры." -ForegroundColor Green
        } else {
            Write-Host " [i] Модуль не установлен. Для установки запустите скрипт с ключом -InstallCEFKiller или выберите соответствующий пункт в меню Steam." -ForegroundColor DarkGray
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n[✓] Оптимизация игрового клиента Steam завершена!" -ForegroundColor Green
}
