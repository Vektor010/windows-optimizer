<#
================================================================================
Имя твика:              Оптимизация параметров VS Code и VSCodium (VSCode-Tweaks)
Что делает:             Настраивает пользовательские параметры settings.json:
                           - telemetry.telemetryLevel = "off"
                           - telemetry.enableCrashReporter = false
                           - telemetry.enableTelemetry = false
                           - workbench.enableExperiments = false
                           - update.mode = "manual"
                           - update.showReleaseNotes = false
                           - extensions.ignoreRecommendations = true
                           - npm.fetchOnlinePackageInfo = false
                           - git.autofetch = false
Зачем нужно:            Полностью блокирует сетевой телеметрический трафик к серверам аналитики
                        Microsoft, отключает онлайн-эксперименты A/B, сбор дампов сбоев и
                        фоновые дисковые опросы обновлений, ускоряя запуск и снижая потребление памяти.
Значение по умолчанию:  telemetry.telemetryLevel = "all", enableExperiments = true, update.mode = "default".
Значение после твика:   Все телеметрические и экспериментальные функции отключены, обновления переведены в ручной режим.
Источник / Категория:   Gaming & System Optimizer: Code Editors & Developer Tools
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$vscTargets = @(
    @{
        Name = "Visual Studio Code"
        Dir  = Join-Path $env:APPDATA "Code\User"
        File = Join-Path $env:APPDATA "Code\User\settings.json"
    },
    @{
        Name = "VSCodium"
        Dir  = Join-Path $env:APPDATA "VSCodium\User"
        File = Join-Path $env:APPDATA "VSCodium\User\settings.json"
    },
    @{
        Name = "VS Code Insiders"
        Dir  = Join-Path $env:APPDATA "Code - Insiders\User"
        File = Join-Path $env:APPDATA "Code - Insiders\User\settings.json"
    }
)

# ------------------------------------------------------------------------------
# 1. Проверка наличия редакторов в системе
# ------------------------------------------------------------------------------
function Test-VSCodeInstalled {
    foreach ($vt in $vscTargets) {
        $parentAppDir = Split-Path -Path $vt.Dir -Parent
        if (Test-Path -LiteralPath $parentAppDir) { return $true }
    }
    $programPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code"),
        (Join-Path "${env:ProgramFiles(x86)}" "Microsoft VS Code")
    )
    foreach ($pp in $programPaths) {
        if (Test-Path -LiteralPath $pp) { return $true }
    }
    return $false
}

if (-not (Test-VSCodeInstalled)) {
    if (-not $Quiet) {
        Write-Host "[-] Редакторы VS Code / VSCodium не обнаружены в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

if (-not $Quiet) {
    Write-Host ">>> Оптимизация редакторов VS Code / VSCodium (Gaming & System Optimizer)..." -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 2. РЕЖИМ ОТКАТА (Rollback / -Restore)
# ------------------------------------------------------------------------------
if ($Restore) {
    if (-not $Quiet) {
        Write-Host "`n[ОТКАТ] Восстановление настроек редакторов из резервных копий..." -ForegroundColor Yellow
    }

    $restoredAny = $false
    foreach ($vt in $vscTargets) {
        $bakFile = "$($vt.File).bak"
        if (Test-Path -LiteralPath $bakFile) {
            if ($PSCmdlet.ShouldProcess($vt.File, "Restore settings from backup")) {
                Copy-Item -LiteralPath $bakFile -Destination $vt.File -Force
                Remove-Item -LiteralPath $bakFile -Force -ErrorAction SilentlyContinue
            }
            if (-not $Quiet) {
                Write-Host " [+] Восстановлена конфигурация $($vt.Name): $($vt.File)" -ForegroundColor Green
            }
            $restoredAny = $true
        }
    }

    if (-not $restoredAny) {
        if (-not $Quiet) {
            Write-Host " [!] Резервные копии settings.json.bak не найдены." -ForegroundColor DarkGray
        }
    } else {
        if (-not $Quiet) {
            Write-Host "`n[✓] Откат параметров редакторов успешно завершен!" -ForegroundColor Green
        }
    }
    return
}

# ------------------------------------------------------------------------------
# 3. Применение оптимизаций параметров
# ------------------------------------------------------------------------------
$optimizedAny = $false

foreach ($vt in $vscTargets) {
    $parentAppDir = Split-Path -Path $vt.Dir -Parent
    if (Test-Path -LiteralPath $parentAppDir) {
        if (-not (Test-Path -LiteralPath $vt.Dir)) {
            if ($PSCmdlet.ShouldProcess($vt.Dir, "Create User config directory")) {
                New-Item -ItemType Directory -Path $vt.Dir -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }

        # Резервное копирование (только если бэкапа еще нет для обеспечения идемпотентности)
        $bakFile = "$($vt.File).bak"
        if ((Test-Path -LiteralPath $vt.File) -and -not (Test-Path -LiteralPath $bakFile)) {
            if ($PSCmdlet.ShouldProcess($bakFile, "Create backup of settings.json")) {
                Copy-Item -LiteralPath $vt.File -Destination $bakFile -Force
            }
            if (-not $Quiet) {
                Write-Host " [+] Создана резервная копия: $bakFile" -ForegroundColor DarkGray
            }
        }

        $settings = [ordered]@{}
        if (Test-Path -LiteralPath $vt.File) {
            try {
                $raw = Get-Content -LiteralPath $vt.File -Raw -Encoding UTF8
                if ($raw -and $raw.Trim().Length -gt 0) {
                    $parsed = $raw | ConvertFrom-Json
                    if ($parsed) {
                        foreach ($prop in $parsed.PSObject.Properties) {
                            $settings[$prop.Name] = $prop.Value
                        }
                    }
                }
            } catch {
                Write-Verbose "Ошибка чтения существующего файла настроек: $_"
            }
        }

        # Применение параметров подавления телеметрии и фоновых служб
        $settings["telemetry.telemetryLevel"]         = "off"
        $settings["telemetry.enableCrashReporter"]     = $false
        $settings["telemetry.enableTelemetry"]         = $false
        $settings["workbench.enableExperiments"]       = $false
        $settings["update.mode"]                       = "manual"
        $settings["update.showReleaseNotes"]           = $false
        $settings["extensions.ignoreRecommendations"]   = $true
        $settings["npm.fetchOnlinePackageInfo"]         = $false
        $settings["git.autofetch"]                     = $false

        if ($PSCmdlet.ShouldProcess($vt.File, "Write optimized settings")) {
            $jsonContent = $settings | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($vt.File, $jsonContent, [System.Text.UTF8Encoding]::new($false))
        }

        if (-not $Quiet) {
            Write-Host " [+] Конфигурация $($vt.Name) оптимизирована (телеметрия ВЫКЛ, эксперименты ВЫКЛ, обновления вручную)" -ForegroundColor Green
        }
        $optimizedAny = $true
    }
}

if ($optimizedAny) {
    if (-not $Quiet) {
        Write-Host "`n[✓] Оптимизация редакторов кода успешно завершена!" -ForegroundColor Green
    }
} else {
    if (-not $Quiet) {
        Write-Host " [i] Каталоги профилей пользователей редакторов пока не инициализированы." -ForegroundColor DarkGray
    }
}
