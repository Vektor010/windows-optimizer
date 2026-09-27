<#
================================================================================
Имя твика:              Оптимизация групповых политик браузеров Chromium (Browsers-Tweaks)
Что делает:             Настраивает системные групповые политики для всех Chromium-браузеров
                        (Google Chrome, Microsoft Edge, Brave, Yandex Browser):
                           - BackgroundModeEnabled = 0 (запрет фоновых процессов после закрытия)
                           - MetricsReportingEnabled = 0 (отключение телеметрии и краш-репортов)
                           - StartupBoostEnabled = 0 (Edge: запрет фонового предзапуска)
                           - HubsSidebarEnabled = 0 (Edge: отключение фонового сайдбара)
Зачем нужно:            Браузеры на базе Chromium по умолчанию остаются работать в фоне
                        даже после закрытия окна, потребляя от 200 до 800 МБ ОЗУ и создавая
                        фоновые дисковые и сетевые обращения. Твик полностью освобождает
                        память и потоки CPU перед запуском требовательных соревновательных игр.
Значение по умолчанию:  BackgroundModeEnabled = 1 (включено), MetricsReportingEnabled = 1,
                        StartupBoostEnabled = 1 (Edge).
Значение после твика:   Все параметры переведены в 0 (DWord, принудительно запрещено).
Источник / Категория:   Gaming & System Optimizer: Browsers & Background Workloads
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$policyTargets = @(
    @{
        Name   = "Google Chrome"
        Path   = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        Values = @{
            "BackgroundModeEnabled"   = 0
            "MetricsReportingEnabled" = 0
        }
    },
    @{
        Name   = "Microsoft Edge"
        Path   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        Values = @{
            "BackgroundModeEnabled"   = 0
            "MetricsReportingEnabled" = 0
            "StartupBoostEnabled"     = 0
            "HubsSidebarEnabled"      = 0
        }
    },
    @{
        Name   = "Brave Browser"
        Path   = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
        Values = @{
            "BackgroundModeEnabled"   = 0
            "MetricsReportingEnabled" = 0
        }
    },
    @{
        Name   = "Yandex Browser"
        Path   = "HKLM:\SOFTWARE\Policies\YandexBrowser"
        Values = @{
            "BackgroundModeEnabled"   = 0
            "MetricsReportingEnabled" = 0
        }
    }
)

$backupFile = Join-Path $env:ProgramData "browser_policies_backup.json"

# ------------------------------------------------------------------------------
# 1. Проверка наличия поддерживаемых браузеров или разделов политик
# ------------------------------------------------------------------------------
function Test-BrowsersInstalled {
    $hasPolicyKey = $false
    foreach ($pt in $policyTargets) {
        if (Test-Path -LiteralPath $pt.Path) { $hasPolicyKey = $true; break }
    }
    $hasBrowserExe = (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") -or `
                     (Test-Path "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe") -or `
                     (Test-Path "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe") -or `
                     (Test-Path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") -or `
                     (Test-Path "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe") -or `
                     (Test-Path "${env:LOCALAPPDATA}\Yandex\YandexBrowser\Application\browser.exe")
    return ($hasPolicyKey -or $hasBrowserExe)
}

if (-not (Test-BrowsersInstalled)) {
    if (-not $Quiet) {
        Write-Host "[-] Браузеры Chromium не обнаружены в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

if (-not $Quiet) {
    Write-Host ">>> Оптимизация политик браузеров Chromium (Gaming & System Optimizer)..." -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 2. РЕЖИМ ОТКАТА (Rollback / -Restore)
# ------------------------------------------------------------------------------
if ($Restore) {
    if (-not $Quiet) {
        Write-Host "`n[ОТКАТ] Восстановление исходных политик браузеров..." -ForegroundColor Yellow
    }

    if (Test-Path -LiteralPath $backupFile) {
        try {
            $backupData = Get-Content -LiteralPath $backupFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($item in $backupData) {
                if (Test-Path -LiteralPath $item.Path) {
                    foreach ($prop in $item.Values.PSObject.Properties) {
                        if ($null -ne $prop.Value) {
                            Set-ItemProperty -Path $item.Path -Name $prop.Name -Value $prop.Value -Type DWord -Force
                            if (-not $Quiet) {
                                Write-Host " [+] Восстановлен параметр $($item.Name) -> $($prop.Name): $($prop.Value)" -ForegroundColor Green
                            }
                        } else {
                            Remove-ItemProperty -Path $item.Path -Name $prop.Name -ErrorAction SilentlyContinue
                            if (-not $Quiet) {
                                Write-Host " [+] Удален примененный параметр $($item.Name) -> $($prop.Name)" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
            Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Ошибка при чтении файла отката: $_"
        }
    } else {
        # Fallback по умолчанию: удаление BackgroundModeEnabled и установка дефолтов
        foreach ($pt in $policyTargets) {
            if (Test-Path -LiteralPath $pt.Path) {
                Remove-ItemProperty -Path $pt.Path -Name "BackgroundModeEnabled" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $pt.Path -Name "MetricsReportingEnabled" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $pt.Path -Name "StartupBoostEnabled" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $pt.Path -Name "HubsSidebarEnabled" -ErrorAction SilentlyContinue
                if (-not $Quiet) {
                    Write-Host " [+] Политики $($pt.Name) возвращены к системным значениям по умолчанию" -ForegroundColor Green
                }
            }
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[✓] Откат политик браузеров успешно завершен!" -ForegroundColor Green
    }
    return
}

# ------------------------------------------------------------------------------
# 3. Резервное копирование снимка состояния
# ------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $backupFile)) {
    try {
        $backupList = [System.Collections.Generic.List[object]]::new()
        foreach ($pt in $policyTargets) {
            $entry = [ordered]@{
                Name   = $pt.Name
                Path   = $pt.Path
                Values = [ordered]@{}
            }
            if (Test-Path -LiteralPath $pt.Path) {
                foreach ($valName in $pt.Values.Keys) {
                    $prop = Get-ItemProperty -Path $pt.Path -Name $valName -ErrorAction SilentlyContinue
                    if ($null -ne $prop -and $null -ne $prop.$valName) {
                        $entry.Values[$valName] = $prop.$valName
                    } else {
                        $entry.Values[$valName] = $null
                    }
                }
            } else {
                foreach ($valName in $pt.Values.Keys) {
                    $entry.Values[$valName] = $null
                }
            }
            $backupList.Add($entry)
        }
        $backupList | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupFile -Encoding UTF8
    } catch {
        Write-Verbose "Не удалось создать резервную копию: $_"
    }
}

# ------------------------------------------------------------------------------
# 4. Применение оптимизаций политик
# ------------------------------------------------------------------------------
foreach ($pt in $policyTargets) {
    if (-not (Test-Path -LiteralPath $pt.Path)) {
        if ($PSCmdlet.ShouldProcess($pt.Path, "Create policy registry key")) {
            New-Item -Path $pt.Path -Force | Out-Null
        }
    }
    foreach ($vName in $pt.Values.Keys) {
        $val = $pt.Values[$vName]
        if ($PSCmdlet.ShouldProcess("$($pt.Path)\$vName", "Set policy value to $val")) {
            Set-ItemProperty -Path $pt.Path -Name $vName -Value $val -Type DWord -Force
        }
    }
    if (-not $Quiet) {
        Write-Host " [+] Политики $($pt.Name) применены (BackgroundMode=0, Metrics=0)" -ForegroundColor Green
    }
}

if (-not $Quiet) {
    Write-Host "`n[✓] Оптимизация политик браузеров завершена (фоновые процессы после закрытия заблокированы)!" -ForegroundColor Green
}
