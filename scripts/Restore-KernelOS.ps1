#Requires -Version 5.1
<#
==============================================================================
ЧТО ДЕЛАЕТ:
  Восстанавливает исходные параметры системного реестра Windows из эталонного
  JSON-снимка (по умолчанию backup/kernelos_baseline.json).
  - EXISTS: возвращает исходное значение и тип данных (DWord, QWord, String, MultiString, Binary)
  - VALUE_NOT_EXISTS: удаляет добавленный оптимизациями параметр реестра
  - NOT_EXISTS: удаляет созданный параметр и безопасно очищает пустую ветку (с защитой системных корней)

ЗАЧЕМ:
  Обеспечивает 100% обратимость любых твиков системы без необходимости
  переустановки ОС или использования сторонних точек восстановления.
  Гарантирует безопасный возврат в состояние чистой Windows (Stock / Baseline).

ПОСЛЕДСТВИЯ:
  Все параметры, измененные твиками Gaming & System Optimizer, возвращаются к значениям
  на момент создания эталонного снимка. Для применения некоторых
  параметров (DWM, Multimedia, Explorer) может потребоваться перезагрузка.

СОВМЕСТИМОСТЬ:
  - Windows 10 / 11 (любые редакции, включая IoT Enterprise LTSC 26200)
  - PowerShell 5.1 и PowerShell 7+
  - Поддерживает ключ -WhatIf для безопасного предварительного просмотра
  - Поддерживает -PassThru и -Quiet для автоматизации

ОТКАТ:
  Для повторного применения твиков запустите соответствующие модули
  (System-Tweaks.ps1, Visibility-Tweaks.ps1, Privacy-Tweaks.ps1 и т.д.)
  или главное меню Optimizer.ps1.

ИСТОЧНИК:
  - Gaming & System Optimizer
  - https://github.com/System
==============================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Path = "",

    [switch]$PassThru,
    [switch]$Quiet
)

$ErrorActionPreference = "SilentlyContinue"

$baseDir = Split-Path $PSScriptRoot -Parent
$backupDir = Join-Path $baseDir "backup"
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path $backupDir "kernelos_baseline.json"
}

if (-not (Test-Path -LiteralPath $Path)) {
    if (-not $Quiet) {
        Write-Host "[-] Ошибка: Файл эталонного снимка '$Path' не найден!" -ForegroundColor Red
    }
    return
}

# ------------------------------------------------------------------------------
# Список защищенных системных веток (никогда не удаляются при NOT_EXISTS)
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

try {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $baseline = $raw | ConvertFrom-Json
} catch {
    if (-not $Quiet) {
        Write-Host "[-] Ошибка чтения JSON-снимка '$Path': $_" -ForegroundColor Red
    }
    return
}

if (-not $Quiet) {
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "           ТОЧНЫЙ ОТКАТ РЕЕСТРА ПО ЭТАЛОННОМУ СНИМКУ (ROLLBACK)               " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host ">>> Загружен снимок ПК: $($baseline.computerName) от $($baseline.timestamp)" -ForegroundColor DarkGray
    Write-Host ">>> Всего параметров в снимке: $($baseline.tweaks.Count)`n" -ForegroundColor DarkGray
}

$restored = 0
$cleanedValues = 0
$cleanedKeys = 0
$errors = 0

foreach ($t in $baseline.tweaks) {
    $p = $t.path
    $n = $t.name
    $state = $t.originalState

    switch ($state) {
        "EXISTS" {
            try {
                if (-not (Test-Path -LiteralPath $p)) {
                    if ($PSCmdlet.ShouldProcess($p, "Создать раздел реестра")) {
                        New-Item -Path $p -Force | Out-Null
                    }
                }

                $vk = [Microsoft.Win32.RegistryValueKind]::DWord
                if ($t.originalType) {
                    [Enum]::TryParse($t.originalType, [ref]$vk) | Out-Null
                }

                $val = $t.originalValue
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

                if ($PSCmdlet.ShouldProcess("$p\$n", "Восстановить значение ($vk = $val)")) {
                    Set-ItemProperty -LiteralPath $p -Name $n -Value $val -Type $vk -Force -ErrorAction Stop
                }
                $restored++
            } catch {
                if (-not $Quiet) {
                    Write-Host " [-] Ошибка восстановления $($p)\$($n): $_" -ForegroundColor Red
                }
                $errors++
            }
        }

        "VALUE_NOT_EXISTS" {
            try {
                if (Test-Path -LiteralPath $p) {
                    $key = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
                    if ($key -and ($key.Property -contains $n)) {
                        if ($PSCmdlet.ShouldProcess("$p\$n", "Удалить добавленный параметр реестра")) {
                            Remove-ItemProperty -LiteralPath $p -Name $n -Force -ErrorAction Stop
                        }
                        $cleanedValues++
                    }
                }
            } catch {
                if (-not $Quiet) {
                    Write-Host " [-] Ошибка удаления свойства $($p)\$($n): $_" -ForegroundColor Red
                }
                $errors++
            }
        }

        "NOT_EXISTS" {
            try {
                if (Test-Path -LiteralPath $p) {
                    # 1. Сначала удаляем добавленное твиком свойство, если оно было создано
                    $key = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
                    if ($key -and ($key.Property -contains $n)) {
                        if ($PSCmdlet.ShouldProcess("$p\$n", "Удалить добавленный параметр реестра")) {
                            Remove-ItemProperty -LiteralPath $p -Name $n -Force -ErrorAction Stop
                        }
                        $cleanedValues++
                    }

                    # 2. Безопасная очистка ветки: ТОЛЬКО если ветка не в списке защищенных и абсолютно пуста
                    if (-not (Test-IsProtectedKey -KeyPath $p)) {
                        $freshKey = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
                        if ($freshKey -and $freshKey.SubKeyCount -eq 0 -and $freshKey.ValueCount -eq 0) {
                            if ($PSCmdlet.ShouldProcess($p, "Удалить пустой дочерний раздел реестра")) {
                                Remove-Item -LiteralPath $p -Force -ErrorAction Stop
                            }
                            $cleanedKeys++
                        }
                    }
                }
            } catch {
                if (-not $Quiet) {
                    Write-Host " [-] Ошибка безопасной очистки ветки $($p): $_" -ForegroundColor Red
                }
                $errors++
            }
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n[✓] Откат по эталонному снимку завершён!" -ForegroundColor Green
    Write-Host "    - Восстановлено исходных значений (EXISTS):           $restored" -ForegroundColor Cyan
    Write-Host "    - Удалено добавленных твиками значений (VALUE_NOT_EX): $cleanedValues" -ForegroundColor Yellow
    Write-Host "    - Удалено созданных твиками пустых веток (NOT_EXISTS): $cleanedKeys" -ForegroundColor DarkYellow
    if ($errors -gt 0) {
        Write-Host "    - Ошибок при откате: $errors" -ForegroundColor Red
    } else {
        Write-Host "    - Ошибок: 0 (все операции выполнены успешно)" -ForegroundColor Green
    }
    Write-Host ""
}

if ($PassThru) {
    return [PSCustomObject]@{
        Total          = $baseline.tweaks.Count
        Restored       = $restored
        CleanedValues  = $cleanedValues
        CleanedKeys    = $cleanedKeys
        Errors         = $errors
        BaselinePath   = $Path
        ComputerName   = $baseline.computerName
        Timestamp      = $baseline.timestamp
    }
}
