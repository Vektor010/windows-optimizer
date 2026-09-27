#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Настраивает горизонтальное и вертикальное расстояние между значками (сетку ярлыков)
#    на рабочем столе Windows, а также перенос длинных подписей значков через параметры
#    WindowMetrics (IconSpacing, IconVerticalSpacing, IconTitleWrap).
#    Поддерживает как интерактивный GUI-режим с ползунками, так и автоматизацию из CLI.
#
# 2. ЗАЧЕМ:
#    Позволяет компактно организовать ярлыки на экранах любого разрешения, настроить
#    плотность сетки рабочего стола под предпочтения пользователя и устранить
#    некрасивые широкие отступы Windows 11 по умолчанию.
#
# 3. ПОСЛЕДСТВИЯ:
#    Записывает строковые значения (от -480 до -2730) в ветку реестра:
#    HKCU:\Control Panel\Desktop\WindowMetrics.
#    Для применения требуется перезапуск Проводника (explorer.exe) или повторный
#    вход в систему (Sign Out).
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Вызов с параметром -Restore удаляет кастомные значения IconSpacing и
#    IconVerticalSpacing (возврат к дефолту -1125 / 75 единиц) и возвращает
#    IconTitleWrap = 1.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий Nohuto / win-config:
#    https://github.com/nohuto/win-config/blob/main/scripts/iconSpacing.ps1
#    Документация Noverse:
#    https://noverse.dev/win-config/misc/
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(32, 182)]
    [int]$Horizontal,

    [Parameter()]
    [ValidateRange(32, 182)]
    [int]$Vertical,

    [Parameter()]
    [ValidateSet('0', '1', 'True', 'False', 'Enable', 'Disable')]
    [string]$WrapTitle,

    [Parameter()]
    [switch]$RestartExplorer,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Status,

    [Parameter()]
    [switch]$HideConsole
)

$ErrorActionPreference = 'Stop'

$metricsPath = 'HKCU:\Control Panel\Desktop\WindowMetrics'

function Get-NvCurrentMetric([string]$Name, [int]$DefaultUnits = 75) {
    try {
        $val = Get-ItemPropertyValue -Path $metricsPath -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $val) {
            $parsed = [int]$val
            return [int][Math]::Round($parsed / -15)
        }
    } catch {
        $null = $_
    }
    return $DefaultUnits
}

# ---------------------------------------------------------
# Режим командной строки (CLI Mode)
# ---------------------------------------------------------
$isCliAction = ($PSBoundParameters.ContainsKey('Horizontal') -or
                $PSBoundParameters.ContainsKey('Vertical')   -or
                $PSBoundParameters.ContainsKey('WrapTitle')  -or
                $Restore -or $Status)

if ($isCliAction) {
    if ($Status) {
        $currH = Get-NvCurrentMetric 'IconSpacing' 75
        $currV = Get-NvCurrentMetric 'IconVerticalSpacing' 75
        $wrap  = Get-ItemPropertyValue -Path $metricsPath -Name 'IconTitleWrap' -ErrorAction SilentlyContinue
        Write-Host "--- Текущие параметры сетки значков рабочего стола ---" -ForegroundColor Cyan
        Write-Host "Горизонтальный отступ : $currH единиц ($(-15 * $currH) твипов)" -ForegroundColor White
        Write-Host "Вертикальный отступ   : $currV единиц ($(-15 * $currV) твипов)" -ForegroundColor White
        Write-Host "Перенос названий      : $(if ($wrap -eq 0) { '0 (Выключен)' } else { '1 (Включен)' })" -ForegroundColor White
        if (-not $Restore -and -not $PSBoundParameters.ContainsKey('Horizontal') -and -not $PSBoundParameters.ContainsKey('Vertical')) {
            return
        }
    }

    if ($Restore) {
        Remove-ItemProperty -Path $metricsPath -Name 'IconSpacing' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $metricsPath -Name 'IconVerticalSpacing' -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $metricsPath -Name 'IconTitleWrap' -Value 1 -Force
        Write-Host "[+] Параметры сетки значков сброшены на системные по умолчанию (75 / -1125)" -ForegroundColor Green
    } else {
        if ($PSBoundParameters.ContainsKey('Horizontal')) {
            $rawH = -15 * $Horizontal
            Set-ItemProperty -Path $metricsPath -Name 'IconSpacing' -Value ([string]$rawH) -Force
            Write-Host "[+] Установлен горизонтальный отступ: $Horizontal ($rawH твипов)" -ForegroundColor Green
        }
        if ($PSBoundParameters.ContainsKey('Vertical')) {
            $rawV = -15 * $Vertical
            Set-ItemProperty -Path $metricsPath -Name 'IconVerticalSpacing' -Value ([string]$rawV) -Force
            Write-Host "[+] Установлен вертикальный отступ: $Vertical ($rawV твипов)" -ForegroundColor Green
        }
        if ($PSBoundParameters.ContainsKey('WrapTitle')) {
            $wrapVal = if ($WrapTitle -in @('1', 'True', 'Enable')) { 1 } else { 0 }
            Set-ItemProperty -Path $metricsPath -Name 'IconTitleWrap' -Value $wrapVal -Force
            Write-Host "[+] Перенос названий значков: $(if ($wrapVal -eq 1) { 'Включен (1)' } else { 'Выключен (0)' })" -ForegroundColor Green
        }
    }

    if ($RestartExplorer) {
        Write-Host "[*] Перезапуск Проводника Windows для применения изменений..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Start-Process explorer.exe
        }
        Write-Host "[+] Проводник успешно перезапущен." -ForegroundColor Green
    } else {
        Write-Host "[i] Для полного применения изменений перезапустите Проводник (-RestartExplorer) или выполните Sign Out." -ForegroundColor Yellow
    }
    return
}

# ---------------------------------------------------------
# Режим графического интерфейса (WinForms GUI)
# ---------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue

if (-not ([Management.Automation.PSTypeName]'Win32.IconWinAPI').Type) {
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IconWinAPI {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction SilentlyContinue
    } catch {
        $null = $_
    }
}

# Безопасный поиск и загрузка иконки
$icoPath = Join-Path $env:TEMP 'Noverse.ico'
if (-not (Test-Path -LiteralPath $icoPath)) {
    $candidateIcons = @(
        (if ($PSScriptRoot) { Join-Path (Split-Path $PSScriptRoot -Parent) 'misc\assets\Noverse.ico' }),
        (if ($PSScriptRoot) { Join-Path (Split-Path $PSScriptRoot -Parent) 'noverse-github\nvapi-cli\noverse.ico' })
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($candidateIcons -and $candidateIcons.Count -gt 0) {
        try { Copy-Item -LiteralPath $candidateIcons[0] -Destination $icoPath -Force } catch { $null = $_ }
    } else {
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nohuto/nohuto/main/misc/assets/Noverse.ico" -OutFile $icoPath -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        } catch {
            $null = $_
        }
    }
}

$colorGray  = [Drawing.Color]::FromArgb(28, 28, 28)
$colorWhite = [Drawing.Color]::White
$fontSmall  = [Drawing.Font]::new("Segoe UI", 9)

function Show-NvDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "info"
    )
    $form = [Windows.Forms.Form]@{
        Text            = $Title
        Size            = [Drawing.Size]::new(340, 135)
        StartPosition   = 'CenterParent'
        BackColor       = $colorGray
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        TopMost         = $true
    }
    if (Test-Path -LiteralPath $icoPath) {
        try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($icoPath) } catch { $null = $_ }
    }

    $lbl = [Windows.Forms.Label]@{
        Text      = $Message
        ForeColor = $colorWhite
        Font      = $fontSmall
        AutoSize  = $false
        TextAlign = 'MiddleCenter'
        Size      = [Drawing.Size]::new(300, 35)
        Location  = [Drawing.Point]::new(20, 10)
    }
    $form.Controls.Add($lbl)

    $okBtn = [Windows.Forms.Button]@{
        Text      = "OK"
        Size      = [Drawing.Size]::new(80, 25)
        Location  = [Drawing.Point]::new(125, 55)
        BackColor = if ($Type -eq 'error') { [Drawing.Color]::IndianRed } else { [Drawing.Color]::CornflowerBlue }
        ForeColor = $colorWhite
        FlatStyle = 'Flat'
    }
    $okBtn.Add_Click({ $form.Close() })
    $form.Controls.Add($okBtn)
    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

$valh = Get-NvCurrentMetric 'IconSpacing' 75
$valv = Get-NvCurrentMetric 'IconVerticalSpacing' 75

$nvmain = [Windows.Forms.Form]@{
    Text            = "Desktop Icon Spacing"
    Size            = [Drawing.Size]::new(480, 260)
    StartPosition   = 'CenterScreen'
    BackColor       = $colorGray
    FormBorderStyle = 'FixedSingle'
    MaximizeBox     = $false
}

if (Test-Path -LiteralPath $icoPath) {
    try { $nvmain.Icon = [Drawing.Icon]::ExtractAssociatedIcon($icoPath) } catch { $null = $_ }
}

$labelh = [Windows.Forms.Label]@{
    Text      = "Horizontal spacing"
    Location  = [Drawing.Point]::new(10, 20)
    ForeColor = $colorWhite
    BackColor = $colorGray
    Font      = $fontSmall
    AutoSize  = $true
}
$nvmain.Controls.Add($labelh)

$labelv = [Windows.Forms.Label]@{
    Text      = "Vertical spacing"
    Location  = [Drawing.Point]::new(10, 90)
    ForeColor = $colorWhite
    BackColor = $colorGray
    Font      = $fontSmall
    AutoSize  = $true
}
$nvmain.Controls.Add($labelv)

$slidho = [Windows.Forms.TrackBar]@{
    Minimum       = 32
    Maximum       = 182
    TickFrequency = 10
    Value         = $valh
    SmallChange   = 1
    LargeChange   = 5
    Location      = [Drawing.Point]::new(10, 42)
    Size          = [Drawing.Size]::new(310, 30)
    BackColor     = $colorGray
}
$nvmain.Controls.Add($slidho)

$slidvert = [Windows.Forms.TrackBar]@{
    Minimum       = 32
    Maximum       = 182
    TickFrequency = 10
    Value         = $valv
    SmallChange   = 1
    LargeChange   = 5
    Location      = [Drawing.Point]::new(10, 112)
    Size          = [Drawing.Size]::new(310, 30)
    BackColor     = $colorGray
}
$nvmain.Controls.Add($slidvert)

$numho = [Windows.Forms.NumericUpDown]@{
    Minimum   = 32
    Maximum   = 182
    Location  = [Drawing.Point]::new(335, 42)
    BackColor = $colorGray
    ForeColor = $colorWhite
    Font      = $fontSmall
    Value     = [decimal][Math]::Max(32, [Math]::Min(182, $valh))
}
$nvmain.Controls.Add($numho)

$numvert = [Windows.Forms.NumericUpDown]@{
    Minimum   = 32
    Maximum   = 182
    Location  = [Drawing.Point]::new(335, 112)
    BackColor = $colorGray
    ForeColor = $colorWhite
    Font      = $fontSmall
    Value     = [decimal][Math]::Max(32, [Math]::Min(182, $valv))
}
$nvmain.Controls.Add($numvert)

$slidho.Add_ValueChanged({ $numho.Value = $slidho.Value })
$slidvert.Add_ValueChanged({ $numvert.Value = $slidvert.Value })
$numho.Add_ValueChanged({ $slidho.Value = [int]$numho.Value })
$numvert.Add_ValueChanged({ $slidvert.Value = [int]$numvert.Value })

$apply = [Windows.Forms.Button]@{
    Text      = "Apply"
    Location  = [Drawing.Point]::new(30, 170)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $colorWhite
    FlatStyle = 'Flat'
    Size      = [Drawing.Size]::new(90, 28)
    Font      = $fontSmall
}
$apply.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$apply.FlatAppearance.BorderSize  = 1
$apply.Add_Click({
    $hval = -15 * $slidho.Value
    $vval = -15 * $slidvert.Value
    Set-ItemProperty -Path $metricsPath -Name "IconSpacing" -Value ([string]$hval) -Force
    Set-ItemProperty -Path $metricsPath -Name "IconVerticalSpacing" -Value ([string]$vval) -Force
    Set-ItemProperty -Path $metricsPath -Name "IconTitleWrap" -Value 0 -Force
    Show-NvDialog -Title "Applied" -Message "IconSpacing: $hval`nIconVerticalSpacing: $vval`nIconTitleWrap: 0"
})
$nvmain.Controls.Add($apply)

$restartBtn = [Windows.Forms.Button]@{
    Text      = "Restart Explorer"
    Location  = [Drawing.Point]::new(135, 170)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $colorWhite
    FlatStyle = 'Flat'
    Size      = [Drawing.Size]::new(125, 28)
    Font      = $fontSmall
}
$restartBtn.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$restartBtn.FlatAppearance.BorderSize  = 1
$restartBtn.Add_Click({
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
})
$nvmain.Controls.Add($restartBtn)

$resetBtn = [Windows.Forms.Button]@{
    Text      = "Default"
    Location  = [Drawing.Point]::new(275, 170)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $colorWhite
    FlatStyle = 'Flat'
    Size      = [Drawing.Size]::new(80, 28)
    Font      = $fontSmall
}
$resetBtn.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$resetBtn.FlatAppearance.BorderSize  = 1
$resetBtn.Add_Click({
    $slidho.Value = 75
    $slidvert.Value = 75
    Remove-ItemProperty -Path $metricsPath -Name "IconSpacing" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $metricsPath -Name "IconVerticalSpacing" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $metricsPath -Name "IconTitleWrap" -Value 1 -Force
    Show-NvDialog -Title "Reset" -Message "Reset to Windows defaults (-1125 / 75 units)`nIconTitleWrap: 1"
})
$nvmain.Controls.Add($resetBtn)

$signout = [Windows.Forms.Button]@{
    Text      = "Sign Out"
    Location  = [Drawing.Point]::new(370, 170)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $colorWhite
    FlatStyle = 'Flat'
    Size      = [Drawing.Size]::new(80, 28)
    Font      = $fontSmall
}
$signout.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$signout.FlatAppearance.BorderSize  = 1
$signout.Add_Click({ & shutdown.exe /l })
$nvmain.Controls.Add($signout)

if ($HideConsole) {
    try {
        [IconWinAPI]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0) | Out-Null
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