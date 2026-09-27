#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Отображает графическую галерею (WinForms GUI) всех установленных в системе шрифтов
#    с наглядными образцами начертания текста в темной теме, либо выводит список
#    всех семейств шрифтов в консоль/конвейер при передаче ключа -List.
#
# 2. ЗАЧЕМ:
#    Для визуального выбора и оценки начертания шрифтов перед их настройкой в
#    терминалах (Windows Terminal, PowerShell), кодовых редакторах (VS Code),
#    интерфейсе системы (через твикеры реестра) и играх без установки стороннего софта.
#
# 3. ПОСЛЕДСТВИЯ:
#    Открывает интерактивное окно "NV Fonts" с 4-колоночной сеткой шрифтов и вертикальной
#    прокруткой. Не вносит изменений в реестр или системные файлы.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Поддерживает Windows PowerShell 5.1
#    и PowerShell 7+ (с установленным компонентом WindowsDesktop).
#
# 5. ОТКАТ:
#    Не требуется (утилита только для чтения и визуализации).
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий System / win-config:
#    https://github.com/system-optimizer
#    Документация Optimizer:
#    Gaming & System Optimizer Reference
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$List,
    [string]$SampleText = 'Sample',
    [int]$FontSize = 11
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue

$fonts = [Drawing.FontFamily]::Families

# Консольный режим (-List) для автоматизации и скриптов
if ($List) {
    return ($fonts | Select-Object -ExpandProperty Name | Sort-Object)
}

# Графический режим (GUI)
try {
    [Windows.Forms.Application]::EnableVisualStyles()
} catch {
    $null = $_
}

$nvmain = [Windows.Forms.Form] @{
    Text            = 'NV Fonts'
    Size            = [Drawing.Size]::new(1380, 1130)
    BackColor       = [Drawing.Color]::FromArgb(30, 30, 30)
    AutoScroll      = $true
    StartPosition   = [Windows.Forms.FormStartPosition]::CenterScreen
}

$x = @(10, 355, 700, 1045)
$y = @(10, 10, 10, 10)

for ($i = 0; $i -lt $fonts.Count; $i++) {
    $col = $i % 4
    try {
        $fontFamily = $fonts[$i]
        $style = [Drawing.FontStyle]::Regular
        if (-not $fontFamily.IsStyleAvailable($style)) {
            if ($fontFamily.IsStyleAvailable([Drawing.FontStyle]::Bold)) {
                $style = [Drawing.FontStyle]::Bold
            } elseif ($fontFamily.IsStyleAvailable([Drawing.FontStyle]::Italic)) {
                $style = [Drawing.FontStyle]::Italic
            }
        }

        $font = [Drawing.Font]::new($fontFamily.Name, [float]$FontSize, $style)
        $label = [Windows.Forms.Label] @{
            Text      = "$SampleText - $($fontFamily.Name)"
            Font      = $font
            ForeColor = [Drawing.Color]::White
            AutoSize  = $true
            Location  = [Drawing.Point]::new($x[$col], $y[$col])
        }
        $nvmain.Controls.Add($label)
        $y[$col] += $label.Height + 8
    } catch {
        $null = $_
    }
}

try {
    [Windows.Forms.Application]::Run($nvmain)
} finally {
    if ($nvmain) {
        $nvmain.Dispose()
    }
}