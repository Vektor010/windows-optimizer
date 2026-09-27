#Requires -Version 5.1
<#
==============================================================================
ЧТО ДЕЛАЕТ:
  Универсально восстанавливает состояние операционной системы Windows по
  динамическому резервному снимку (System Snapshot), созданному через
  Backup-SystemState.ps1.
  1) Опционально импортирует физические дампы веток реестра (.reg) при ключе -ImportReg.
  2) Выполняет точечный откат реестровых параметров всех модулей оптимизации
     с восстановлением типов данных и значений (EXISTS) либо удалением
     добавленных твиками параметров и безопасной очисткой пустых веток (NOT_EXISTS).
  3) Восстанавливает режим запуска (Automatic, Manual, Disabled) и статус
     (Running / Stopped) ключевых системных служб.

ЗАЧЕМ:
  Обеспечивает комплексное возвращение всей системы к состоянию на момент
  создания снимка. Позволяет быстро ликвидировать последствия экспериментов,
  несовместимостей или сбоев как на чистой ОС, так и на кастомных сборках.

ПОСЛЕДСТВИЯ:
  Параметры реестра и службы возвращаются к значениям выбранного снимка.
  Для вступления в силу изменений в DWM, MMCSS и системных политиках
  рекомендуется перезагрузить компьютер.

СОВМЕСТИМОСТЬ:
  - Windows 10 / Windows 11 (включая 24H2 / IoT Enterprise LTSC 26200)
  - PowerShell 5.1 и PowerShell 7+
  - Поддерживает безопасный предпросмотр (-WhatIf / -Confirm)
  - Поддерживает автоматизацию (-ForceLatest, -PassThru, -Quiet)

ОТКАТ:
  Для повторного применения оптимизаций используйте профили Optimizer.ps1
  или отдельные скрипты из каталога scripts/.

ИСТОЧНИК:
  - Gaming & System Optimizer Reference
  - https://github.com/system-optimizer
==============================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$SnapshotPath = '',

    [Parameter()]
    [switch]$ForceLatest,

    [Parameter()]
    [switch]$ImportReg,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'

if (-not $Quiet) {
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "       УНИВЕРСАЛЬНОЕ ВОССТАНОВЛЕНИЕ СИСТЕМЫ (SMART RESTORE)                   " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
}

$baseDir = Split-Path $PSScriptRoot -Parent
$snapshotsDir = Join-Path (Join-Path $baseDir "backup") "snapshots"

if (-not (Test-Path -LiteralPath $snapshotsDir)) {
    if (-not $Quiet) {
        Write-Host "[-] Папка снимков '$snapshotsDir' не найдена!" -ForegroundColor Red
    }
    return
}

# ------------------------------------------------------------------------------
# 1. Определение целевого снимка
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
    $latestFile = Join-Path $snapshotsDir "LATEST.txt"
    $allSnapshots = Get-ChildItem -Path $snapshotsDir -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending

    if ($allSnapshots.Count -eq 0) {
        if (-not $Quiet) {
            Write-Host "[-] Нет сохранённых снимков в '$snapshotsDir'!" -ForegroundColor Red
        }
        return
    }

    $isNonInteractive = [Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or (-not [Environment]::UserInteractive)

    if ($ForceLatest -or $isNonInteractive) {
        if (Test-Path -LiteralPath $latestFile) {
            $snapName = (Get-Content -LiteralPath $latestFile -Raw).Trim()
            $candidate = Join-Path $snapshotsDir $snapName
            if (Test-Path -LiteralPath $candidate) {
                $SnapshotPath = $candidate
            }
        }
        if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
            $SnapshotPath = $allSnapshots[0].FullName
        }
    } else {
        Write-Host "Доступные резервные снимки:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $allSnapshots.Count; $i++) {
            $tag = if ($i -eq 0) { " (Новейший)" } else { "" }
            Write-Host " [$($i+1)] $($allSnapshots[$i].Name)$tag"
        }
        Write-Host "`nВыберите номер снимка для восстановления [1-$($allSnapshots.Count), Enter=1]: " -NoNewline -ForegroundColor Yellow
        $sel = Read-Host
        if ([string]::IsNullOrWhiteSpace($sel)) {
            $SnapshotPath = $allSnapshots[0].FullName
        } else {
            $idx = 0
            if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $allSnapshots.Count) {
                $SnapshotPath = $allSnapshots[$idx - 1].FullName
            } else {
                Write-Host "[-] Неверный выбор." -ForegroundColor Red
                return
            }
        }
    }
} elseif (-not [System.IO.Path]::IsPathRooted($SnapshotPath)) {
    $testInSnap = Join-Path $snapshotsDir $SnapshotPath
    if (Test-Path -LiteralPath $testInSnap) {
        $SnapshotPath = $testInSnap
    }
}

if (-not (Test-Path -LiteralPath $SnapshotPath)) {
    if (-not $Quiet) {
        Write-Host "[-] Путь снимка '$SnapshotPath' не существует!" -ForegroundColor Red
    }
    return
}

$jsonFile = Join-Path $SnapshotPath "snapshot_baseline.json"
if (-not (Test-Path -LiteralPath $jsonFile)) {
    if (-not $Quiet) {
        Write-Host "[-] Файл конфигурации '$jsonFile' не найден!" -ForegroundColor Red
    }
    return
}

try {
    $raw = [System.IO.File]::ReadAllText($jsonFile, [System.Text.Encoding]::UTF8)
    $data = $raw | ConvertFrom-Json
} catch {
    if (-not $Quiet) {
        Write-Host "[-] Ошибка чтения JSON '$jsonFile': $_" -ForegroundColor Red
    }
    return
}

if (-not $Quiet) {
    Write-Host "`n>>> Восстановление по снимку: $($data.Metadata.ComputerName) ($($data.Metadata.Created))..." -ForegroundColor Cyan
    Write-Host ">>> Исходная ОС: $($data.Metadata.OSVersion) (Build $($data.Metadata.Build))`n" -ForegroundColor DarkGray
}

$importedRegCount = 0
$restoredParams = 0
$cleanedParams = 0
$cleanedKeys = 0
$restoredServices = 0
$errors = 0

# ------------------------------------------------------------------------------
# Список защищенных системных веток (никогда не удаляются при очистке)
# ------------------------------------------------------------------------------
$protectedPatterns = @(
    '^HKLM:\\?$',
    '^HKCU:\\?$',
    '^HKLM:\\SYSTEM\\?$',
    '^HKLM:\\SYSTEM\\CurrentControlSet\\?$',
    '^HKLM:\\SYSTEM\\CurrentControlSet\\Control.*',
    '^HKLM:\\SYSTEM\\CurrentControlSet\\Services.*',
    '^HKLM:\\SOFTWARE\\?$',
    '^HKLM:\\SOFTWARE\\Microsoft\\?$',
    '^HKLM:\\SOFTWARE\\Microsoft\\Windows\\?$',
    '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\?$',
    '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion.*',
    '^HKLM:\\SOFTWARE\\Policies\\?$',
    '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\?$',
    '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\?$',
    '^HKCU:\\Control Panel\\?$',
    '^HKCU:\\Control Panel\\Desktop.*',
    '^HKCU:\\Software\\?$',
    '^HKCU:\\Software\\Microsoft\\?$',
    '^HKCU:\\Software\\Microsoft\\Windows\\?$',
    '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion.*',
    '^HKCU:\\Software\\Policies\\?$',
    '^HKCU:\\Software\\Policies\\Microsoft\\?$',
    '^HKCU:\\Software\\Policies\\Microsoft\\Windows\\?$'
)

function Test-IsProtectedKey {
    param([string]$KeyPath)
    $norm = $KeyPath.TrimEnd('\')
    foreach ($pat in $protectedPatterns) {
        if ($norm -match $pat) {
            return $true
        }
    }
    return $false
}

# ------------------------------------------------------------------------------
# 2. Импорт дампов реестра (.reg) при ключе -ImportReg
# ------------------------------------------------------------------------------
if ($ImportReg) {
    if (-not $Quiet) {
        Write-Host "[1/3] Импорт физических архивов веток реестра (.reg)..." -ForegroundColor Yellow
    }
    $regFiles = Get-ChildItem -Path $SnapshotPath -Filter "*.reg" -File -ErrorAction SilentlyContinue
    if ($regFiles.Count -eq 0) {
        if (-not $Quiet) {
            Write-Host "   [i] Файлы .reg в каталоге снимка не найдены." -ForegroundColor DarkGray
        }
    } else {
        foreach ($rf in $regFiles) {
            if ($PSCmdlet.ShouldProcess($rf.Name, "Импорт ветки реестра через reg import")) {
                $proc = Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($rf.FullName)`"" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -eq 0) {
                    $importedRegCount++
                    if (-not $Quiet) {
                        Write-Host "   + Импортирован: $($rf.Name)" -ForegroundColor Green
                    }
                } else {
                    $errors++
                    if (-not $Quiet) {
                        Write-Host "   [-] Ошибка импорта $($rf.Name) (Код: $($proc.ExitCode))" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 3. Точечное восстановление параметров реестра из snapshot_baseline.json
# ------------------------------------------------------------------------------
$stepNum = if ($ImportReg) { "[2/3]" } else { "[1/2]" }
if (-not $Quiet) {
    Write-Host "$stepNum Точечное восстановление параметров реестра..." -ForegroundColor Yellow
}

foreach ($p in $data.Parameters) {
    $k = $p.Key
    $n = $p.Name

    if ($p.Exists) {
        # Параметр существовал до твиков — восстанавливаем точное значение и тип данных
        try {
            if (-not (Test-Path -LiteralPath $k)) {
                if ($PSCmdlet.ShouldProcess($k, "Создать раздел реестра")) {
                    New-Item -Path $k -Force | Out-Null
                }
            }

            $vk = [Microsoft.Win32.RegistryValueKind]::DWord
            if ($p.ValueKind) {
                [Enum]::TryParse($p.ValueKind, [ref]$vk) | Out-Null
            }

            $val = $p.Value
            switch ($vk) {
                ([Microsoft.Win32.RegistryValueKind]::Binary) {
                    if ($null -ne $val) {
                        $val = [byte[]]@($val)
                    } else {
                        $val = [byte[]]@()
                    }
                }
                ([Microsoft.Win32.RegistryValueKind]::MultiString) {
                    if ($null -ne $val) {
                        $val = [string[]]@($val)
                    } else {
                        $val = [string[]]@()
                    }
                }
                ([Microsoft.Win32.RegistryValueKind]::DWord) {
                    if ($val -is [int64] -and $val -gt 2147483647) {
                        $val = [uint32]$val
                    } else {
                        $val = [int32]$val
                    }
                }
                ([Microsoft.Win32.RegistryValueKind]::QWord) {
                    $val = [int64]$val
                }
                ([Microsoft.Win32.RegistryValueKind]::String) {
                    $val = [string]$val
                }
                ([Microsoft.Win32.RegistryValueKind]::ExpandString) {
                    $val = [string]$val
                }
            }

            if ($PSCmdlet.ShouldProcess("$($k)\$($n)", "Восстановить значение ($vk = $val)")) {
                Set-ItemProperty -LiteralPath $k -Name $n -Value $val -Type $vk -Force -ErrorAction Stop
            }
            $restoredParams++
        } catch {
            if (-not $Quiet) {
                Write-Host " [-] Ошибка восстановления $($k)\$($n): $_" -ForegroundColor DarkRed
            }
            $errors++
        }
    } else {
        # Параметра НЕ было до твиков — удаляем его, очищая реестр от твика
        try {
            if (Test-Path -LiteralPath $k) {
                $keyObj = Get-Item -LiteralPath $k -ErrorAction SilentlyContinue
                if ($keyObj -and ($keyObj.Property -contains $n)) {
                    if ($PSCmdlet.ShouldProcess("$($k)\$($n)", "Удалить добавленный параметр реестра")) {
                        Remove-ItemProperty -LiteralPath $k -Name $n -Force -ErrorAction Stop
                    }
                    $cleanedParams++
                }

                # Безопасная очистка пустых дочерних веток
                if (-not (Test-IsProtectedKey -KeyPath $k)) {
                    $freshKey = Get-Item -LiteralPath $k -ErrorAction SilentlyContinue
                    if ($freshKey -and $freshKey.SubKeyCount -eq 0 -and $freshKey.ValueCount -eq 0) {
                        if ($PSCmdlet.ShouldProcess($k, "Удалить пустой дочерний раздел реестра")) {
                            Remove-Item -LiteralPath $k -Force -ErrorAction Stop
                        }
                        $cleanedKeys++
                    }
                }
            }
        } catch {
            if (-not $Quiet) {
                Write-Host " [-] Ошибка очистки параметра $($k)\$($n): $_" -ForegroundColor DarkRed
            }
            $errors++
        }
    }
}

if (-not $Quiet) {
    Write-Host "   + Восстановлено оригинальных параметров: $restoredParams" -ForegroundColor Green
    Write-Host "   + Удалено добавленных твиками параметров: $cleanedParams" -ForegroundColor Green
    if ($cleanedKeys -gt 0) {
        Write-Host "   + Удалено созданных твиками пустых веток: $cleanedKeys" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------------------
# 4. Восстановление конфигурации служб Windows
# ------------------------------------------------------------------------------
$stepNumSvc = if ($ImportReg) { "[3/3]" } else { "[2/2]" }
if (-not $Quiet) {
    Write-Host "$stepNumSvc Восстановление конфигурации служб..." -ForegroundColor Yellow
}

if ($data.Services) {
    foreach ($s in $data.Services) {
        if ($s.Exists -and $s.StartMode) {
            $mode = switch ($s.StartMode.ToString().ToLower()) {
                "auto"      { "Automatic" }
                "automatic" { "Automatic" }
                "manual"    { "Manual" }
                "disabled"  { "Disabled" }
                default     { "Manual" }
            }

            try {
                $currSvc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
                if ($currSvc) {
                    if ($PSCmdlet.ShouldProcess($s.Name, "Установить режим запуска $mode и состояние $($s.Status)")) {
                        Set-Service -Name $s.Name -StartupType $mode -ErrorAction SilentlyContinue
                        if ($s.Status -eq "Running" -and $currSvc.Status -ne "Running") {
                            Start-Service -Name $s.Name -ErrorAction SilentlyContinue
                        } elseif ($s.Status -eq "Stopped" -and $currSvc.Status -eq "Running") {
                            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
                        }
                    }
                    $restoredServices++
                    if (-not $Quiet) {
                        Write-Host "   + Служба $($s.Name): режим $mode, статус $($s.Status)" -ForegroundColor DarkGray
                    }
                }
            } catch {
                if (-not $Quiet) {
                    Write-Host " [-] Ошибка восстановления службы $($s.Name): $_" -ForegroundColor DarkRed
                }
                $errors++
            }
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n[✓] Система полностью возвращена к исходному состоянию снимка!" -ForegroundColor Green
    Write-Host "    - Восстановлено параметров реестра: $restoredParams" -ForegroundColor Cyan
    Write-Host "    - Удалено параметров твиков:        $cleanedParams" -ForegroundColor Yellow
    Write-Host "    - Восстановлено служб:              $restoredServices" -ForegroundColor Cyan
    if ($ImportReg) {
        Write-Host "    - Импортировано .reg дампов:        $importedRegCount" -ForegroundColor Green
    }
    if ($errors -gt 0) {
        Write-Host "    - Ошибок при откате:               $errors" -ForegroundColor Red
    } else {
        Write-Host "    - Ошибок:                          0" -ForegroundColor Green
    }
    Write-Host ""
}

if ($PassThru) {
    return [PSCustomObject]@{
        SnapshotName     = [System.IO.Path]::GetFileName($SnapshotPath)
        SnapshotPath     = $SnapshotPath
        ComputerName     = $data.Metadata.ComputerName
        Created          = $data.Metadata.Created
        RestoredParams   = $restoredParams
        CleanedParams    = $cleanedParams
        CleanedKeys      = $cleanedKeys
        RestoredServices = $restoredServices
        ImportedRegCount = $importedRegCount
        Errors           = $errors
    }
}
