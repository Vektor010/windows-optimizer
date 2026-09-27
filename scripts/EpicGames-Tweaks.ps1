# ==============================================================================
# Gaming & System Optimizer - Комплексная оптимизация Epic Games Launcher
# ==============================================================================
# Назначение:
#   Комплексная настройка клиента Epic Games Launcher и служб Epic Online Services (EOS)
#   для устранения фоновой нагрузки на процессор, освобождения оперативной памяти,
#   отключения телеметрии/сбора дампов и оптимизации энергопотребления.
#
# Содержит 4 этапа:
#   [1/4] Оптимизация служб (EpicGamesUpdater, EpicOnlineServices -> Manual)
#   [2/4] Отключение автозапуска лаунчера в реестре Windows
#   [3/4] Оптимизация конфигураций GameUserSettings.ini и Engine.ini
#   [4/4] Очистка накопленного кэша CEF, дампов крашей и отладочных логов
# ==============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$CleanOnly,

    [Parameter()]
    [switch]$Quiet
)

# ------------------------------------------------------------------------------
# 1. Поиск путей установки и конфигурации
# ------------------------------------------------------------------------------
$epicProgramPaths = @(
    "${env:ProgramFiles}\Epic Games\Launcher",
    "${env:ProgramFiles(x86)}\Epic Games\Launcher"
)
$epicInstallDir = $epicProgramPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$epicAppDataDir = Join-Path $env:LOCALAPPDATA "EpicGamesLauncher"
$epicConfigDir  = Join-Path $epicAppDataDir "Saved\Config\Windows"
$epicSavedDir   = Join-Path $epicAppDataDir "Saved"
$epicDataDir    = "C:\ProgramData\Epic"

$epicServices = @("EpicGamesUpdater", "EpicOnlineServices")
$existingServices = $epicServices | Where-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue }

$runRegKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$hasRunEntry = $null -ne (Get-ItemProperty -Path $runRegKey -Name "EpicGamesLauncher" -ErrorAction SilentlyContinue)

# Проверка наличия Epic Games Launcher или связанных служб в системе
$isEpicInstalled = ($null -ne $epicInstallDir) -or `
                   (Test-Path -LiteralPath $epicAppDataDir) -or `
                   (Test-Path -LiteralPath $epicDataDir) -or `
                   ($existingServices.Count -gt 0) -or `
                   $hasRunEntry

if (-not $isEpicInstalled) {
    if (-not $Quiet) {
        Write-Host "[-] Epic Games Launcher не обнаружен в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

if (-not $Quiet) {
    Write-Host ">>> Оптимизация Epic Games Launcher (Gaming & System Optimizer)..." -ForegroundColor Cyan
    if ($epicInstallDir) {
        Write-Host "Каталог установки: $epicInstallDir" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 2. Безопасное завершение активных процессов
# ------------------------------------------------------------------------------
$procNames = @("EpicGamesLauncher", "EpicWebHelper", "UnrealCEFSubProcess")
$activeProcs = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($activeProcs) {
    if (-not $Quiet) {
        Write-Host " Завершение активных процессов Epic Games..." -ForegroundColor DarkGray
    }
    $activeProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

$backupStateFile = Join-Path $epicAppDataDir "epic_state_backup.json"

# ------------------------------------------------------------------------------
# 3. Вспомогательная функция безопасного редактирования INI файлов
# ------------------------------------------------------------------------------
function Write-IniSetting {
    param(
        [string]$FilePath,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        $parentDir = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($FilePath, "[$Section]`r`n$Key=$Value`r`n", [System.Text.UTF8Encoding]::new($false))
        return
    }

    $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $FilePath -Encoding UTF8)
    $sectionHeader = "[$Section]"
    $inSection = $false
    $sectionFound = $false
    $keyFound = $false
    $insertIndex = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line.StartsWith("[") -and $line.EndsWith("]")) {
            if ($inSection) {
                $insertIndex = $i
                break
            }
            if ($line -ieq $sectionHeader) {
                $inSection = $true
                $sectionFound = $true
            }
            continue
        }
        if ($inSection) {
            if ($line -match "^$Key\s*=") {
                $lines[$i] = "$Key=$Value"
                $keyFound = $true
                break
            }
        }
    }

    if (-not $sectionFound) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne "") {
            $lines.Add("")
        }
        $lines.Add($sectionHeader)
        $lines.Add("$Key=$Value")
    } elseif (-not $keyFound) {
        if ($insertIndex -ge 0) {
            $lines.Insert($insertIndex, "$Key=$Value")
        } else {
            $lines.Add("$Key=$Value")
        }
    }

    [System.IO.File]::WriteAllLines($FilePath, $lines, [System.Text.UTF8Encoding]::new($false))
}

# ------------------------------------------------------------------------------
# 4. РЕЖИМ ОТКАТА (Rollback / -Restore)
# ------------------------------------------------------------------------------
if ($Restore) {
    if (-not $Quiet) {
        Write-Host "`n[ОТКАТ] Восстановление настроек Epic Games по умолчанию..." -ForegroundColor Yellow
    }

    # 1. Восстановление конфигурационных файлов из .bak
    $iniFiles = @("GameUserSettings.ini", "Engine.ini")
    foreach ($ini in $iniFiles) {
        $targetPath = Join-Path $epicConfigDir $ini
        $bakPath = "$targetPath.bak"
        if (Test-Path -LiteralPath $bakPath) {
            Copy-Item -LiteralPath $bakPath -Destination $targetPath -Force
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
            if (-not $Quiet) {
                Write-Host " [+] Восстановлен оригинальный файл конфигурации: $ini" -ForegroundColor Green
            }
        }
    }

    # 2. Восстановление служб и реестра из снимка состояния
    if (Test-Path -LiteralPath $backupStateFile) {
        try {
            $backupData = Get-Content -LiteralPath $backupStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($backupData.Services) {
                foreach ($s in $backupData.Services.PSObject.Properties) {
                    $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
                    if ($svc -and $s.Value) {
                        Set-Service -Name $s.Name -StartupType $s.Value -ErrorAction SilentlyContinue
                        if (-not $Quiet) {
                            Write-Host " [+] Восстановлен тип запуска службы $($s.Name): $($s.Value)" -ForegroundColor Green
                        }
                    }
                }
            }
            if ($backupData.RunEntry) {
                Set-ItemProperty -Path $runRegKey -Name "EpicGamesLauncher" -Value $backupData.RunEntry -Type String -Force
                if (-not $Quiet) {
                    Write-Host " [+] Восстановлен автозапуск в реестре: $($backupData.RunEntry)" -ForegroundColor Green
                }
            }
            Remove-Item -LiteralPath $backupStateFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Не удалось восстановить исходный снимок: $_"
        }
    } else {
        # Fallback по умолчанию для служб Epic
        foreach ($s in $epicServices) {
            if (Get-Service -Name $s -ErrorAction SilentlyContinue) {
                Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                if (-not $Quiet) {
                    Write-Host " [+] Служба $s возвращена в режим запуска Manual" -ForegroundColor Green
                }
            }
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[✓] Откат настроек Epic Games Launcher успешно завершен!" -ForegroundColor Green
    }
    return
}

# ------------------------------------------------------------------------------
# 5. Резервное копирование снимка состояния перед применением
# ------------------------------------------------------------------------------
if (Test-Path -LiteralPath $epicAppDataDir) {
    if (-not (Test-Path -LiteralPath $backupStateFile)) {
        try {
            $state = [ordered]@{
                Services = [ordered]@{}
                RunEntry = $null
            }
            foreach ($s in $epicServices) {
                $svcObj = Get-Service -Name $s -ErrorAction SilentlyContinue
                if ($svcObj) {
                    $state.Services[$s] = $svcObj.StartType.ToString()
                }
            }
            $runProp = Get-ItemProperty -Path $runRegKey -Name "EpicGamesLauncher" -ErrorAction SilentlyContinue
            if ($runProp -and $runProp.EpicGamesLauncher) {
                $state.RunEntry = $runProp.EpicGamesLauncher
            }
            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupStateFile -Encoding UTF8
        } catch {
            Write-Verbose "Не удалось создать резервный снимок: $_"
        }
    }
}

# ------------------------------------------------------------------------------
# [1/4] Оптимизация служб Epic Games
# ------------------------------------------------------------------------------
if (-not $CleanOnly) {
    if (-not $Quiet) {
        Write-Host "`n[1/4] Оптимизация служб Epic Games (отключение постоянной фоновой активности)..." -ForegroundColor Yellow
    }
    foreach ($s in $epicServices) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq 'Running') {
                if ($PSCmdlet.ShouldProcess($s, "Stop running service")) {
                    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                }
            }
            if ($PSCmdlet.ShouldProcess($s, "Set service startup type to Manual")) {
                Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
            }
            if (-not $Quiet) {
                Write-Host " [+] Служба $s переведена в режим Manual (запуск только при прямой необходимости)" -ForegroundColor Green
            }
        }
    }

    # ------------------------------------------------------------------------------
    # [2/4] Отключение автозапуска в реестре
    # ------------------------------------------------------------------------------
    if (-not $Quiet) {
        Write-Host "`n[2/4] Проверка автозапуска Epic Games при старте Windows..." -ForegroundColor Yellow
    }
    $runVal = Get-ItemProperty -Path $runRegKey -Name "EpicGamesLauncher" -ErrorAction SilentlyContinue
    if ($runVal -and $runVal.EpicGamesLauncher) {
        if ($PSCmdlet.ShouldProcess("HKCU Run", "Remove EpicGamesLauncher startup key")) {
            Remove-ItemProperty -Path $runRegKey -Name "EpicGamesLauncher" -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host " [+] Автозапуск EpicGamesLauncher отключен в реестре Windows" -ForegroundColor Green
        }
    } else {
        if (-not $Quiet) {
            Write-Host " [i] Автозапуск EpicGamesLauncher уже отключен" -ForegroundColor DarkGray
        }
    }

    # ------------------------------------------------------------------------------
    # [3/4] Оптимизация конфигурации GameUserSettings.ini и Engine.ini
    # ------------------------------------------------------------------------------
    if (-not $Quiet) {
        Write-Host "`n[3/4] Настройка конфигурационных профилей лаунчера..." -ForegroundColor Yellow
    }

    if (-not (Test-Path -LiteralPath $epicConfigDir)) {
        New-Item -ItemType Directory -Path $epicConfigDir -Force | Out-Null
    }

    # А. GameUserSettings.ini
    $gusPath = Join-Path $epicConfigDir "GameUserSettings.ini"
    $gusBak  = "$gusPath.bak"
    if ((Test-Path -LiteralPath $gusPath) -and -not (Test-Path -LiteralPath $gusBak)) {
        if ($PSCmdlet.ShouldProcess($gusBak, "Create backup of GameUserSettings.ini")) {
            Copy-Item -LiteralPath $gusPath -Destination $gusBak -Force
        }
        if (-not $Quiet) {
            Write-Host " [+] Создана резервная копия: GameUserSettings.ini.bak" -ForegroundColor DarkGray
        }
    }

    if ($PSCmdlet.ShouldProcess($gusPath, "Apply optimized settings to GameUserSettings.ini")) {
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bEnableStartup" -Value "False"
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bMinimizeToSystemTray" -Value "False"
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bHideToSystemTrayOnClose" -Value "False"
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bAllowForegroundThrottling" -Value "True"
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bDisableFreeGamesNotification" -Value "True"
        Write-IniSetting -FilePath $gusPath -Section "Launcher" -Key "bDisableNewsNotification" -Value "True"
        Write-IniSetting -FilePath $gusPath -Section "CrashReportClient" -Key "bAgreeToCrashUpload" -Value "False"
        Write-IniSetting -FilePath $gusPath -Section "CrashReportClient" -Key "bAllowSendCrashReports" -Value "False"
    }
    if (-not $Quiet) {
        Write-Host " [+] Параметры GameUserSettings.ini обновлены (автозапуск ВЫКЛ, закрытие накрест, троттлинг фонового окна ВКЛ, дампы ВЫКЛ)" -ForegroundColor Green
    }

    # Б. Engine.ini
    $engPath = Join-Path $epicConfigDir "Engine.ini"
    $engBak  = "$engPath.bak"
    if ((Test-Path -LiteralPath $engPath) -and -not (Test-Path -LiteralPath $engBak)) {
        if ($PSCmdlet.ShouldProcess($engBak, "Create backup of Engine.ini")) {
            Copy-Item -LiteralPath $engPath -Destination $engBak -Force
        }
        if (-not $Quiet) {
            Write-Host " [+] Создана резервная копия: Engine.ini.bak" -ForegroundColor DarkGray
        }
    }

    if ($PSCmdlet.ShouldProcess($engPath, "Apply telemetry suppression to Engine.ini")) {
        Write-IniSetting -FilePath $engPath -Section "Core.Log" -Key "LogHttp" -Value "quiet"
        Write-IniSetting -FilePath $engPath -Section "Core.Log" -Key "LogOnline" -Value "quiet"
        Write-IniSetting -FilePath $engPath -Section "Core.Log" -Key "LogAnalytics" -Value "quiet"
    }
    if (-not $Quiet) {
        Write-Host " [+] Параметры Engine.ini обновлены (подавление фонового HTTP/Analytics логирования)" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# [4/4] Очистка накопленного кэша, дампов крашей и отладочных логов
# ------------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Host "`n[4/4] Очистка временных файлов, кэша CEF и дампов крашей..." -ForegroundColor Yellow
}

$cleanupDirs = @(
    (Join-Path $epicSavedDir "Cache"),
    (Join-Path $epicSavedDir "Logs"),
    (Join-Path $epicSavedDir "Config\CrashReportClient"),
    (Join-Path $epicSavedDir "webcache"),
    "C:\ProgramData\Epic\EpicOnlineServices\EOSInstaller\Logs",
    (Join-Path $env:LOCALAPPDATA "Epic Games\Epic Online Services\Bootstrapper\Logs")
)

$cleanedCount = 0
foreach ($dir in $cleanupDirs) {
    if (Test-Path -LiteralPath $dir) {
        if ($PSCmdlet.ShouldProcess($dir, "Remove cache and logs directory")) {
            Remove-Item -Path "$dir\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        $cleanedCount++
    }
}

if (-not $Quiet) {
    Write-Host " [+] Очищено кэшей и каталогов логов: $cleanedCount" -ForegroundColor Green
    Write-Host "`n[✓] Комплексная оптимизация Epic Games Launcher успешно завершена!" -ForegroundColor Green
}
