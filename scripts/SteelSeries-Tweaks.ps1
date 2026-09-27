<#
================================================================================
Имя твика:              Оптимизация служб и виртуального звука SteelSeries GG / Sonar
Что делает:             Отключает фоновые службы виртуального аудиодрайвера Sonar:
                           - SteelSeriesGGClient
                           - SteelSeriesSonar
                           - SteelSeriesAudioService
                        Удаляет автозапуск приложения в реестре Run и завершает
                        активные фоновые процессы Electron/CEF.
Зачем нужно:            Модуль Sonar создает виртуальный промежуточный аудиослой (VAD),
                        добавляющий до 20 мс инпут-лага звука и вызывающий повышенные
                        скачки DPC/ISR Latency в играх. Отключение восстанавливает прямой
                        битовый вывод звука в Windows и освобождает память от тяжелых
                        фоновых процессов SteelSeries GG.
Значение по умолчанию:  Службы активны в фоновом режиме (Automatic, Start=2); автозапуск в Run активен.
Значение после твика:   Службы остановлены и переведены в Disabled (Start=4); автозапуск удален.
Источник / Категория:   Gaming & System Optimizer: Peripherals & Audio Latency
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services"
$targetServices = @("SteelSeriesSonar", "SteelSeriesGGClient", "SteelSeriesAudioService")
$runPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)
$runNames = @("SteelSeriesGG", "SteelSeriesGGClient", "SteelSeries Sonar")

$ssProgramDirs = @(
    "${env:ProgramFiles}\SteelSeries\GG",
    "${env:ProgramFiles(x86)}\SteelSeries\GG",
    "${env:ProgramFiles}\SteelSeries",
    "${env:ProgramFiles(x86)}\SteelSeries"
)
$ssInstallDir = $ssProgramDirs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$ssAppDataDir = Join-Path $env:LOCALAPPDATA "SteelSeries"
$ssDataDir    = "C:\ProgramData\SteelSeries"

$backupFile = if (Test-Path -LiteralPath $ssAppDataDir) {
    Join-Path $ssAppDataDir "steelseries_state_backup.json"
} elseif (Test-Path -LiteralPath $ssDataDir) {
    Join-Path $ssDataDir "steelseries_state_backup.json"
} else {
    Join-Path $env:LOCALAPPDATA "steelseries_state_backup.json"
}

# ------------------------------------------------------------------------------
# 1. Проверка наличия компонентов SteelSeries в системе
# ------------------------------------------------------------------------------
function Test-SteelSeriesInstalled {
    $hasSvc = $false
    foreach ($s in $targetServices) {
        if (Test-Path -LiteralPath "$svcKey\$s") { $hasSvc = $true; break }
    }
    $hasDir = ($null -ne $ssInstallDir) -or (Test-Path -LiteralPath $ssAppDataDir) -or (Test-Path -LiteralPath $ssDataDir)
    $hasRun = $false
    foreach ($rp in $runPaths) {
        if (Test-Path -LiteralPath $rp) {
            foreach ($rn in $runNames) {
                $val = Get-ItemProperty -Path $rp -Name $rn -ErrorAction SilentlyContinue
                if ($val -and $val.$rn) { $hasRun = $true; break }
            }
        }
    }
    return ($hasSvc -or $hasDir -or $hasRun)
}

if (-not (Test-SteelSeriesInstalled)) {
    if (-not $Quiet) {
        Write-Host "[-] SteelSeries GG / Sonar не обнаружен в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

if (-not $Quiet) {
    Write-Host ">>> Оптимизация SteelSeries GG / Sonar (Gaming & System Optimizer)..." -ForegroundColor Cyan
    if ($ssInstallDir) {
        Write-Host "Каталог установки: $ssInstallDir" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 2. Безопасное завершение активных процессов
# ------------------------------------------------------------------------------
$procNames = @("SteelSeriesGG", "SteelSeriesGGClient", "SteelSeriesSonar", "SteelSeriesEngine", "SteelSeriesPrism")
foreach ($p in $procNames) {
    $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($procs) {
        if ($PSCmdlet.ShouldProcess($p, "Stop active process")) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host " [-] Завершен активный процесс: $p" -ForegroundColor DarkGray
        }
    }
}

# ------------------------------------------------------------------------------
# 3. РЕЖИМ ОТКАТА (Rollback / -Restore)
# ------------------------------------------------------------------------------
if ($Restore) {
    if (-not $Quiet) {
        Write-Host "`n[ОТКАТ] Восстановление исходных параметров SteelSeries GG / Sonar..." -ForegroundColor Yellow
    }

    if (Test-Path -LiteralPath $backupFile) {
        try {
            $backupData = Get-Content -LiteralPath $backupFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($backupData.Services) {
                foreach ($s in $backupData.Services.PSObject.Properties) {
                    $sKeyPath = "$svcKey\$($s.Name)"
                    if (Test-Path -LiteralPath $sKeyPath) {
                        Set-ItemProperty -Path $sKeyPath -Name "Start" -Value $s.Value -Type DWord -ErrorAction SilentlyContinue
                        if (-not $Quiet) {
                            Write-Host " [+] Восстановлен запуск службы $($s.Name): Start=$($s.Value)" -ForegroundColor Green
                        }
                    }
                }
            }
            if ($backupData.RunEntries) {
                foreach ($re in $backupData.RunEntries.PSObject.Properties) {
                    if ($re.Value -and (Test-Path -LiteralPath $re.Value.Path)) {
                        Set-ItemProperty -Path $re.Value.Path -Name $re.Name -Value $re.Value.Value -Type String -Force
                        if (-not $Quiet) {
                            Write-Host " [+] Восстановлен автозапуск: $($re.Name) -> $($re.Value.Value)" -ForegroundColor Green
                        }
                    }
                }
            }
            Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Ошибка чтения снимка отката: $_"
        }
    } else {
        # Fallback по умолчанию
        foreach ($s in $targetServices) {
            $sKeyPath = "$svcKey\$s"
            if (Test-Path -LiteralPath $sKeyPath) {
                Set-ItemProperty -Path $sKeyPath -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                if (-not $Quiet) {
                    Write-Host " [+] Служба $s возвращена в режим Automatic (Start=2)" -ForegroundColor Green
                }
            }
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[✓] Откат параметров SteelSeries GG / Sonar успешно завершен!" -ForegroundColor Green
    }
    return
}

# ------------------------------------------------------------------------------
# 4. Резервное копирование снимка состояния
# ------------------------------------------------------------------------------
$parentBackupDir = Split-Path -Path $backupFile -Parent
if (-not (Test-Path -LiteralPath $parentBackupDir)) {
    New-Item -ItemType Directory -Path $parentBackupDir -Force -ErrorAction SilentlyContinue | Out-Null
}

if ((Test-Path -LiteralPath $parentBackupDir) -and -not (Test-Path -LiteralPath $backupFile)) {
    try {
        $state = [ordered]@{
            Services   = [ordered]@{}
            RunEntries = [ordered]@{}
        }
        foreach ($s in $targetServices) {
            $sKeyPath = "$svcKey\$s"
            if (Test-Path -LiteralPath $sKeyPath) {
                $val = (Get-ItemProperty -Path $sKeyPath -Name "Start" -ErrorAction SilentlyContinue).Start
                if ($null -ne $val) { $state.Services[$s] = $val }
            }
        }
        foreach ($rp in $runPaths) {
            if (Test-Path -LiteralPath $rp) {
                foreach ($rn in $runNames) {
                    $runVal = (Get-ItemProperty -Path $rp -Name $rn -ErrorAction SilentlyContinue).$rn
                    if ($runVal) {
                        $state.RunEntries[$rn] = [ordered]@{
                            Path  = $rp
                            Value = $runVal
                        }
                    }
                }
            }
        }
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupFile -Encoding UTF8
    } catch {
        Write-Verbose "Не удалось создать резервный снимок: $_"
    }
}

# ------------------------------------------------------------------------------
# 5. Применение оптимизаций (Отключение служб и автозапуска)
# ------------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Host "`n[1/2] Отключение фоновых служб и виртуального аудиодрайвера Sonar..." -ForegroundColor Yellow
}

foreach ($s in $targetServices) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        if ($PSCmdlet.ShouldProcess($s, "Stop running service")) {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host " [-] Служба $s остановлена" -ForegroundColor DarkGray
        }
    }

    $sKeyPath = "$svcKey\$s"
    if (Test-Path -LiteralPath $sKeyPath) {
        if ($PSCmdlet.ShouldProcess($sKeyPath, "Set Start=4 (Disabled)")) {
            Set-ItemProperty -Path $sKeyPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host " [+] Служба $s отключена (Start=4 Disabled)" -ForegroundColor Green
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n[2/2] Проверка и отключение автозапуска в реестре Windows..." -ForegroundColor Yellow
}

foreach ($rp in $runPaths) {
    if (Test-Path -LiteralPath $rp) {
        foreach ($rn in $runNames) {
            $val = Get-ItemProperty -Path $rp -Name $rn -ErrorAction SilentlyContinue
            if ($val -and $val.$rn) {
                if ($PSCmdlet.ShouldProcess("$rp\$rn", "Remove autostart entry")) {
                    Remove-ItemProperty -Path $rp -Name $rn -ErrorAction SilentlyContinue
                }
                if (-not $Quiet) {
                    Write-Host " [+] Запись автозапуска $rn удалена из $rp" -ForegroundColor Green
                }
            }
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n[✓] Оптимизация SteelSeries GG / Sonar завершена (виртуальный аудиослой отключен, задержки DPC устранены)!" -ForegroundColor Green
}
