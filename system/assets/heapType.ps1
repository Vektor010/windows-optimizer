#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Графический (WinForms GUI) и консольный (CLI) менеджер типов кучи памяти Windows
#    (NT Heap и Segment Heap) для всей системы глобально (Session Manager\Segment Heap)
#    и индивидуально для каждого приложения через IFEO (Image File Execution Options\<exe>).
#
# 2. ЗАЧЕМ:
#    Позволяет гибко переключать процессы на современный сегментный аллокатор
#    Segment Heap (FrontEndHeapDebugOptions = 8) или классический NT Heap (0x4),
#    настраивать пороги резервирования и декоммита кучи NT Heap (HeapSegmentReserve,
#    HeapSegmentCommit, DeCommitFreeBlockThreshold), отключать Lookaside списки и
#    задавать интервалы сборщика мусора GCInterval перед оптимизацией задержек в играх.
#
# 3. ПОСЛЕДСТВИЯ:
#    Вносит или удаляет параметры отладки кучи в ветках реестра:
#    - HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<exe>
#    - HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager
#    - HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Segment Heap
#    В интерактивном режиме открывает тёмную панель управления Noverse Heap Type.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 (версии 2004 / 20H1 и новее, где внедрён Segment Heap) и Windows 11 (x64).
#    Поддерживает Windows PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    В GUI: кнопка "Remove" в каждом блоке.
#    В CLI: параметры -Executable <exe> -Mode Default (удаляет параметры IFEO),
#    -GlobalSegmentHeap Default (удаляет глобальный ключ), -RemoveDefaults.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий Nohuto / win-config:
#    https://github.com/nohuto/win-config/blob/main/system/assets/heapType.ps1
#    Документация Noverse:
#    https://noverse.dev/docs/win-config/system/heap-type/
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [Alias('Exe', 'Process')]
    [string]$Executable,

    [Parameter(Position = 1)]
    [ValidateSet('Default', 'NTHeap', 'SegmentHeap', 'Status')]
    [string]$Mode,

    [Parameter()]
    [ValidateSet('Enable', 'Disable', 'Default')]
    [string]$GlobalSegmentHeap,

    [Parameter()]
    [switch]$ApplyDefaults,

    [Parameter()]
    [switch]$RemoveDefaults,

    [Parameter()]
    [switch]$HideConsole,

    [Parameter()]
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sessionManager = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
$segmentHeapKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Segment Heap'
$ifeoRoot       = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'

function testAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function setDword([string]$Path, [string]$Name, [uint32]$Value) {
    try {
        if (!(Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        $signed = [BitConverter]::ToInt32([BitConverter]::GetBytes($Value), 0)
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $signed -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        $readback = getValue $Path $Name
        if ($readback -ne $Value) { throw "Readback $readback does not match $Value" }
        return $true
    } catch {
        $script:lastRegistryError = $_.Exception.Message
        return $false
    }
}

function getValue([string]$Path, [string]$Name) {
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        if ($null -eq $item.$Name) { return $null }
        return [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$item.$Name), 0)
    } catch {
        return $null
    }
}

function removeValue([string]$Path, [string]$Name) {
    if (Test-Path -LiteralPath $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function cleanEmptyKey([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $leaf = Split-Path -Leaf $Path
        if ($leaf -match '\.exe$' -or $leaf -eq 'Segment Heap') {
            $k = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
            if ($k -and $k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0) {
                Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ---------------------------------------------------------
# Режим командной строки (CLI Mode)
# ---------------------------------------------------------
$isCliAction = $Executable -or $GlobalSegmentHeap -or $ApplyDefaults -or $RemoveDefaults -or $List

if ($isCliAction) {
    if (-not (testAdmin)) {
        Write-Warning "Для изменения настроек кучи требуются права Администратора."
    }

    if ($List) {
        Write-Host "--- Проверка зарегистрированных IFEO настроек кучи ---" -ForegroundColor Cyan
        Get-ChildItem -LiteralPath $ifeoRoot -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if ($p.FrontEndHeapDebugOptions -or $p.DisableHeapLookaside -or $p.GCInterval) {
                [PSCustomObject]@{
                    Executable               = $_.PSChildName
                    FrontEndHeapDebugOptions = if ($null -ne $p.FrontEndHeapDebugOptions) { "0x$(([uint32]$p.FrontEndHeapDebugOptions).ToString('X'))" } else { $null }
                    DisableHeapLookaside     = $p.DisableHeapLookaside
                    GCInterval               = $p.GCInterval
                }
            }
        } | Format-Table -AutoSize
    }

    if ($Executable) {
        $cleanExe = if ($Executable -match '[\\/]') { Split-Path $Executable -Leaf } else { $Executable }
        if ($cleanExe -notmatch '\.exe$') { $cleanExe = "$cleanExe.exe" }
        $targetIfeo = Join-Path $ifeoRoot $cleanExe

        if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = 'Status' }

        switch ($Mode) {
            'SegmentHeap' {
                if (setDword $targetIfeo 'FrontEndHeapDebugOptions' 8) {
                    Write-Host "[+] Установлен Segment Heap (FrontEndHeapDebugOptions = 0x8) для: $cleanExe" -ForegroundColor Green
                } else {
                    Write-Error "Не удалось записать IFEO: $script:lastRegistryError"
                }
            }
            'NTHeap' {
                if (setDword $targetIfeo 'FrontEndHeapDebugOptions' 4) {
                    Write-Host "[+] Установлен NT Heap (FrontEndHeapDebugOptions = 0x4) для: $cleanExe" -ForegroundColor Green
                } else {
                    Write-Error "Не удалось записать IFEO: $script:lastRegistryError"
                }
            }
            'Default' {
                removeValue $targetIfeo 'FrontEndHeapDebugOptions'
                removeValue $targetIfeo 'DisableHeapLookaside'
                removeValue $targetIfeo 'GCInterval'
                cleanEmptyKey $targetIfeo
                Write-Host "[+] Сброшены параметры IFEO кучи (Default) для: $cleanExe" -ForegroundColor Green
            }
            'Status' {
                $val = getValue $targetIfeo 'FrontEndHeapDebugOptions'
                $modeStr = if ($null -eq $val) {
                    'Default (OS decides)'
                } elseif ($val -eq 8) {
                    'Segment Heap (0x8)'
                } elseif ($val -eq 4) {
                    'NT Heap (0x4)'
                } else {
                    "Custom (0x$($val.ToString('X')))"
                }
                Write-Host "Исполняемый файл : $cleanExe" -ForegroundColor White
                Write-Host "Режим кучи       : $modeStr" -ForegroundColor Cyan
                $lookaside = getValue $targetIfeo 'DisableHeapLookaside'
                Write-Host "DisableLookaside : $(if ($null -ne $lookaside -and $lookaside -ne 0) { '1 (Disabled)' } else { '0/None' })" -ForegroundColor White
            }
        }
    }

    if ($GlobalSegmentHeap) {
        switch ($GlobalSegmentHeap) {
            'Enable' {
                setDword $segmentHeapKey 'Enabled' 1 | Out-Null
                Write-Host "[+] Глобальный Segment Heap принудительно включен (Enabled = 1)" -ForegroundColor Green
            }
            'Disable' {
                setDword $segmentHeapKey 'Enabled' 0 | Out-Null
                Write-Host "[+] Глобальный Segment Heap принудительно отключен (Enabled = 0)" -ForegroundColor Green
            }
            'Default' {
                removeValue $segmentHeapKey 'Enabled'
                cleanEmptyKey $segmentHeapKey
                Write-Host "[+] Глобальный Segment Heap сброшен на значение Windows по умолчанию" -ForegroundColor Green
            }
        }
    }

    if ($ApplyDefaults) {
        setDword $sessionManager 'HeapSegmentReserve' 1048576 | Out-Null
        setDword $sessionManager 'HeapSegmentCommit' 8192 | Out-Null
        setDword $sessionManager 'HeapDeCommitFreeBlockThreshold' 4096 | Out-Null
        setDword $sessionManager 'HeapDeCommitTotalFreeThreshold' 65536 | Out-Null
        Write-Host "[+] Параметры NT Heap Session Manager успешно установлены (1MB/8KB/4KB/64KB)" -ForegroundColor Green
    }

    if ($RemoveDefaults) {
        removeValue $sessionManager 'HeapSegmentReserve'
        removeValue $sessionManager 'HeapSegmentCommit'
        removeValue $sessionManager 'HeapDeCommitFreeBlockThreshold'
        removeValue $sessionManager 'HeapDeCommitTotalFreeThreshold'
        Write-Host "[+] Параметры NT Heap Session Manager удалены (возврат к дефолтам ядра NT)" -ForegroundColor Green
    }

    return
}

# ---------------------------------------------------------
# Режим графического интерфейса (WinForms GUI)
# ---------------------------------------------------------
if (!(testAdmin)) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    if ($scriptPath) {
        $pArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $pArgs
    }
    return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue

if (-not ([Management.Automation.PSTypeName]'Win32.HeapWinAPI').Type) {
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HeapWinAPI {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction SilentlyContinue
    } catch {
        $null = $_
    }
}

# Безопасное получение иконки
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

$smallFont = [Drawing.Font]::new('Segoe UI', 9, [Drawing.FontStyle]::Regular)
$blueColor = [Drawing.Color]::CornflowerBlue
$grayColor = [Drawing.Color]::FromArgb(40, 40, 40)
$darkColor = [Drawing.Color]::FromArgb(28, 28, 28)
$whiteColor = [Drawing.Color]::White

function writeGuiLog([string]$HighlightMessage, [string]$Message, [ConsoleColor]$TimeColor = 'DarkGray', [ConsoleColor]$HighlightColor = 'White', [ConsoleColor]$MessageColor = 'White') {
    if (-not $logs -or $logs.IsDisposed) { return }
    $timestamp = "[{0:HH:mm:ss}]" -f (Get-Date)

    $logs.SelectionStart = $logs.Text.Length
    $logs.SelectionColor = [Drawing.Color]::$TimeColor
    $logs.AppendText("$timestamp ")

    $logs.SelectionStart = $logs.Text.Length
    $logs.SelectionColor = [Drawing.Color]::$HighlightColor
    $logs.AppendText("$HighlightMessage ")

    $logs.SelectionStart = $logs.Text.Length
    $logs.SelectionColor = [Drawing.Color]::$MessageColor
    $logs.AppendText("$Message`r`n")

    $logs.SelectionStart = $logs.Text.Length
    $logs.ScrollToCaret()
}

function newPanel([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Title) {
    $panel = [Windows.Forms.Panel]@{
        Location    = [Drawing.Point]::new($X, $Y)
        Size        = [Drawing.Size]::new($W, $H)
        BackColor   = $grayColor
        BorderStyle = 'FixedSingle'
    }
    $label = [Windows.Forms.Label]@{
        Text      = $Title
        ForeColor = $blueColor
        BackColor = $grayColor
        Location  = [Drawing.Point]::new(9, 7)
        AutoSize  = $true
        Font      = [Drawing.Font]::new('Segoe UI', 10, [Drawing.FontStyle]::Regular)
    }
    $panel.Controls.Add($label)
    return $panel
}

function newLabel($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W = 160) {
    $label = [Windows.Forms.Label]@{
        Text      = $Text
        ForeColor = $whiteColor
        BackColor = $grayColor
        Location  = [Drawing.Point]::new($X, $Y)
        Size      = [Drawing.Size]::new($W, 20)
        Font      = $smallFont
    }
    $Parent.Controls.Add($label)
    return $label
}

function newButton($Parent, [string]$Text, [int]$X, [int]$Y, [scriptblock]$Action, [int]$W = 95) {
    $btn = [Windows.Forms.Button]@{
        Text      = $Text
        Location  = [Drawing.Point]::new($X, $Y)
        BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
        ForeColor = $whiteColor
        FlatStyle = 'Flat'
        Size      = [Drawing.Size]::new($W, 25)
        Font      = $smallFont
    }
    $btn.FlatAppearance.BorderColor = [Drawing.Color]::Gray
    $btn.FlatAppearance.BorderSize  = 1
    $btn.Add_Click($Action)
    $Parent.Controls.Add($btn)
    return $btn
}

function newNumber($Parent, [int]$X, [int]$Y, [uint32]$Min, [uint32]$Max, [uint32]$Increment, [uint32]$Value) {
    $num = [Windows.Forms.NumericUpDown]@{
        Location  = [Drawing.Point]::new($X, $Y)
        Size      = [Drawing.Size]::new(132, 24)
        BackColor = [Drawing.Color]::FromArgb(30, 30, 30)
        ForeColor = $whiteColor
        Font      = $smallFont
        Minimum   = [decimal]$Min
        Maximum   = [decimal]$Max
        Increment = [decimal]$Increment
        Value     = [decimal]$Value
    }
    $Parent.Controls.Add($num)
    return $num
}

function newCheck($Parent, [string]$Text, [int]$X, [int]$Y, [bool]$Checked = $false, [scriptblock]$Action = $null) {
    $box = [Windows.Forms.Panel]@{
        Size        = [Drawing.Size]::new(13, 13)
        Location    = [Drawing.Point]::new($X, $Y + 2)
        BackColor   = $(if ($Checked) { [Drawing.Color]::CornflowerBlue } else { [Drawing.Color]::Transparent })
        BorderStyle = 'FixedSingle'
        Tag         = @{ Checked = $Checked }
    }
    $label = [Windows.Forms.Label]@{
        Text      = $Text
        ForeColor = $whiteColor
        BackColor = $grayColor
        Location  = [Drawing.Point]::new($X + 18, $Y)
        AutoSize  = $true
        Font      = $smallFont
    }
    $click = {
        $box.Tag.Checked = -not $box.Tag.Checked
        $box.BackColor = if ($box.Tag.Checked) { [Drawing.Color]::CornflowerBlue } else { [Drawing.Color]::Transparent }
        if ($Action) { & $Action }
    }.GetNewClosure()

    $box.Add_Click($click)
    $label.Add_Click($click)
    $Parent.Controls.AddRange(@($box, $label))
    return $box
}

function setCheckState($Box, [bool]$Checked) {
    if ($Box -is [Windows.Forms.CheckBox]) {
        $Box.Checked = $Checked
        return
    }
    $Box.Tag.Checked = $Checked
    $Box.BackColor = if ($Checked) { [Drawing.Color]::CornflowerBlue } else { [Drawing.Color]::Transparent }
}

function getCheckState($Box) {
    if ($Box -is [Windows.Forms.CheckBox]) { return [bool]$Box.Checked }
    return [bool]$Box.Tag.Checked
}

function getExeFromIcon([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()
    if ($v.StartsWith('"')) {
        $m = [regex]::Match($v, '^"([^"]+)"')
        if ($m.Success) { $v = $m.Groups[1].Value }
    } else {
        $v = ($v -split ',')[0].Trim()
    }
    if ($v -match '\.exe$' -and (Test-Path -LiteralPath $v)) { return (Resolve-Path -LiteralPath $v).Path }
    return $null
}

function addProgramRow($Rows, [string]$Name, [string]$Exe, [string]$Path, [string]$Source) {
    if ([string]::IsNullOrWhiteSpace($Exe)) { return }
    if ($Exe -notmatch '\.exe$') { return }
    if ($Path -and !(Test-Path -LiteralPath $Path)) { return }
    $key = "$($Exe.ToLowerInvariant())|$($Path.ToLowerInvariant())"
    if ($Rows.ContainsKey($key)) { return }
    $Rows[$key] = [pscustomobject]@{
        Name   = if ($Name) { $Name } else { $Exe }
        Exe    = $Exe
        Path   = $Path
        Source = $Source
    }
}

function resolveShortcut([string]$Path) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        if ($shortcut.TargetPath -match '\.exe$' -and (Test-Path -LiteralPath $shortcut.TargetPath)) {
            return (Resolve-Path -LiteralPath $shortcut.TargetPath).Path
        }
    } catch {
        $null = $_
    }
    return $null
}

function getInstalledExecutables {
    $rows = @{}
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (!(Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
            $itemProp = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if (!$itemProp -or !$itemProp.DisplayName) { return }
            $iconExe = getExeFromIcon $itemProp.DisplayIcon
            if ($iconExe) {
                addProgramRow $rows $itemProp.DisplayName (Split-Path $iconExe -Leaf) $iconExe 'Uninstall'
                return
            }
            if ($itemProp.InstallLocation -and (Test-Path -LiteralPath $itemProp.InstallLocation)) {
                Get-ChildItem -LiteralPath $itemProp.InstallLocation -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 8 | ForEach-Object {
                    addProgramRow $rows $itemProp.DisplayName $_.Name $_.FullName 'InstallLocation'
                }
            }
        }
    }

    $appPathRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    )
    foreach ($root in $appPathRoots) {
        if (!(Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
            $defaultVal = $_.GetValue('')
            if ($defaultVal -and (Test-Path -LiteralPath $defaultVal)) {
                addProgramRow $rows $_.PSChildName $_.PSChildName (Resolve-Path -LiteralPath $defaultVal).Path 'App Paths'
            }
        }
    }

    $shortcutRoots = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:AppData\Microsoft\Windows\Start Menu\Programs"
    )
    foreach ($root in $shortcutRoots) {
        if (!(Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
            $target = resolveShortcut $_.FullName
            if ($target) { addProgramRow $rows $_.BaseName (Split-Path $target -Leaf) $target 'Start Menu' }
        }
    }

    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and ($_.Path -match '\.exe$') } | ForEach-Object {
        addProgramRow $rows $_.ProcessName (Split-Path $_.Path -Leaf) $_.Path 'Running'
    }

    return $rows.Values | Sort-Object Name, Exe
}

function getIfeoPath {
    $exe = $exeInput.Text.Trim()
    if ($exe -match '[\\/]') { $exe = Split-Path $exe -Leaf }
    if ($exe -and $exe -notmatch '\.exe$') { $exe = "$exe.exe" }
    if (!$exe) { return $null }
    return Join-Path $ifeoRoot $exe
}

function setExeInput([string]$PathOrExe) {
    if (!$PathOrExe) { return }
    $exeInput.Text = if ($PathOrExe -match '[\\/]') { Split-Path $PathOrExe -Leaf } else { $PathOrExe }
}

function getFrontEndValue {
    $val = 0
    foreach ($bit in $bitChecks.Keys) {
        if (getCheckState $bitChecks[$bit]) { $val = $val -bor (1 -shl [int]$bit) }
    }
    if (getCheckState $lfhContention) { $val = $val -bor (255 -shl 8) }
    if (getCheckState $lfhPerf)       { $val = $val -bor (4095 -shl 16) }
    return [uint32]$val
}

function setFrontEndControls([uint32]$Val) {
    foreach ($bit in $bitChecks.Keys) {
        setCheckState $bitChecks[$bit] (($Val -band (1 -shl [int]$bit)) -ne 0)
    }
    setCheckState $lfhContention (((($Val -shr 8) -band 255) -ne 0))
    setCheckState $lfhPerf       (((($Val -shr 16) -band 4095) -ne 0))
}

function setGlobalMode([string]$Mode) {
    $script:loadingGlobal = $true
    setCheckState $globalForceEnable  ($Mode -eq 'enable')
    setCheckState $globalForceDisable ($Mode -eq 'disable')
    setCheckState $globalDefault      ($Mode -eq 'default')
    $script:loadingGlobal = $false

    if ($Mode -eq 'enable') {
        if (setDword $segmentHeapKey 'Enabled' 1) {
            writeGuiLog '[+]' 'Global Segment Heap force enabled' -HighlightColor Green
        } else {
            writeGuiLog '[-]' "Global write failed: $script:lastRegistryError" -HighlightColor Red
        }
        return
    }
    if ($Mode -eq 'disable') {
        if (setDword $segmentHeapKey 'Enabled' 0) {
            writeGuiLog '[+]' 'Global Segment Heap force disabled' -HighlightColor Green
        } else {
            writeGuiLog '[-]' "Global write failed: $script:lastRegistryError" -HighlightColor Red
        }
        return
    }
    removeValue $segmentHeapKey 'Enabled'
    cleanEmptyKey $segmentHeapKey
    writeGuiLog '[+]' 'Global Segment Heap value removed (Default)' -HighlightColor Green
}

function refreshGlobal {
    $script:loadingGlobal = $true
    $enabled = getValue $segmentHeapKey 'Enabled'
    if ($null -eq $enabled) {
        setCheckState $globalForceEnable  $false
        setCheckState $globalForceDisable $false
        setCheckState $globalDefault      $true
    } elseif ($enabled -eq 0) {
        setCheckState $globalForceEnable  $false
        setCheckState $globalForceDisable $true
        setCheckState $globalDefault      $false
    } else {
        setCheckState $globalForceEnable  $true
        setCheckState $globalForceDisable $false
        setCheckState $globalDefault      $false
    }
    $script:loadingGlobal = $false
}

function refreshNtDefaults {
    $values = @{
        HeapSegmentReserve             = 1048576
        HeapSegmentCommit              = 8192
        HeapDeCommitFreeBlockThreshold = 4096
        HeapDeCommitTotalFreeThreshold = 65536
    }
    foreach ($name in $values.Keys) {
        $current = getValue $sessionManager $name
        $num = $ntNumbers[$name]
        if ($null -eq $current) {
            $num.Value = [decimal]$values[$name]
        } else {
            if ($current -gt [uint32]$num.Maximum) { $current = [uint32]$num.Maximum }
            $num.Value = [decimal]$current
        }
    }
}

function refreshIfeo {
    $path = getIfeoPath
    if (!$path) {
        writeGuiLog '[-]' 'Enter/select an exe first' -HighlightColor Red
        return
    }
    $v = getValue $path 'FrontEndHeapDebugOptions'
    if ($null -eq $v) { $v = 0 }
    setFrontEndControls $v
    $lookaside = getValue $path 'DisableHeapLookaside'
    setCheckState $disableLookaside ($null -ne $lookaside -and $lookaside -ne 0)
    $gc = getValue $path 'GCInterval'
    if ($null -eq $gc) { $gc = 0 }
    if ($gc -gt [uint32]$gcNum.Maximum) { $gc = [uint32]$gcNum.Maximum }
    $script:loadingGc = $true
    try {
        $gcNum.Value = [decimal]$gc
    } finally {
        $script:loadingGc = $false
    }
    writeGuiLog '[+]' "Loaded IFEO for $($exeInput.Text)" -HighlightColor Green
}

# ---------------------------------------------------------
# Инициализация Главного Окна WinForms
# ---------------------------------------------------------
$nvmain = [Windows.Forms.Form]@{
    Text            = 'Noverse Heap Type'
    Size            = [Drawing.Size]::new(1130, 650)
    StartPosition   = 'CenterScreen'
    BackColor       = $darkColor
    FormBorderStyle = 'Sizable'
    Font            = [Drawing.Font]::new('Segoe UI', 9, [Drawing.FontStyle]::Regular)
    MinimumSize     = [Drawing.Size]::new(1080, 650)
}

if (Test-Path -LiteralPath $icoPath) {
    try {
        $nvmain.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($icoPath)
    } catch {
        $null = $_
    }
}

$globalPanel = newPanel 5 5 360 60 'Global Segment Heap'
$nvmain.Controls.Add($globalPanel)
$globalForceEnable = newCheck $globalPanel 'Force Enable' 15 30 $false {
    if ($script:loadingGlobal) { return }
    setGlobalMode 'enable'
}
$globalForceDisable = newCheck $globalPanel 'Force Disable' 120 30 $false {
    if ($script:loadingGlobal) { return }
    setGlobalMode 'disable'
}
$globalDefault = newCheck $globalPanel 'Default' 225 30 $false {
    if ($script:loadingGlobal) { return }
    setGlobalMode 'default'
}

$ntPanel = newPanel 5 70 360 195 'NT Heap Defaults'
$nvmain.Controls.Add($ntPanel)
$ntNumbers = @{}
newLabel $ntPanel 'HeapSegmentReserve' 15 38 178 | Out-Null
$ntNumbers.HeapSegmentReserve = newNumber $ntPanel 195 35 65536 16580608 65536 1048576
newLabel $ntPanel 'HeapSegmentCommit' 15 68 178 | Out-Null
$ntNumbers.HeapSegmentCommit = newNumber $ntPanel 195 65 4096 16580608 4096 8192
newLabel $ntPanel 'DeCommitFreeBlockThreshold' 15 98 178 | Out-Null
$ntNumbers.HeapDeCommitFreeBlockThreshold = newNumber $ntPanel 195 95 0 4294967280 16 4096
newLabel $ntPanel 'DeCommitTotalFreeThreshold' 15 128 178 | Out-Null
$ntNumbers.HeapDeCommitTotalFreeThreshold = newNumber $ntPanel 195 125 0 4294967280 16 65536

newButton $ntPanel 'Apply' 5 164 {
    $failed = $false
    foreach ($name in $ntNumbers.Keys) {
        if (!(setDword $sessionManager $name ([uint32]$ntNumbers[$name].Value))) { $failed = $true }
    }
    if ($failed) {
        writeGuiLog '[-]' "NT heap defaults write failed: $script:lastRegistryError" -HighlightColor Red
    } else {
        writeGuiLog '[+]' 'NT heap defaults written' -HighlightColor Green
    }
} 80 | Out-Null

newButton $ntPanel 'Reload' 90 164 {
    refreshNtDefaults
    writeGuiLog '[+]' 'NT defaults reloaded' -HighlightColor Green
} 80 | Out-Null

newButton $ntPanel 'Remove' 175 164 {
    foreach ($name in $ntNumbers.Keys) { removeValue $sessionManager $name }
    refreshNtDefaults
    writeGuiLog '[+]' 'NT heap default values removed' -HighlightColor Green
} 80 | Out-Null

$programPanel = newPanel 370 5 740 385 'Per Executable'
$nvmain.Controls.Add($programPanel)
$exeInput = [Windows.Forms.TextBox]@{
    Location  = [Drawing.Point]::new(15, 33)
    Size      = [Drawing.Size]::new(370, 24)
    BackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    ForeColor = $whiteColor
    Font      = $smallFont
}
$programPanel.Controls.Add($exeInput)

newButton $programPanel 'Search' 395 32 {
    $dialog = [Windows.Forms.OpenFileDialog]@{
        Filter = 'Executable (*.exe)|*.exe|All files (*.*)|*.*'
        Title  = 'Select executable'
    }
    if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        setExeInput $dialog.FileName
        refreshIfeo
        writeGuiLog '[+]' "Selected $(Split-Path $dialog.FileName -Leaf)" -HighlightColor Green
    }
} 80 | Out-Null

newButton $programPanel 'Detect' 480 32 { startProgramDetect } 80 | Out-Null
newButton $programPanel 'Load' 565 32 { refreshIfeo } 70 | Out-Null
newButton $programPanel 'Remove' 640 32 {
    $path = getIfeoPath
    if (!$path) { writeGuiLog '[-]' 'Enter/select an exe first' -HighlightColor Red; return }
    removeValue $path 'FrontEndHeapDebugOptions'
    removeValue $path 'DisableHeapLookaside'
    removeValue $path 'GCInterval'
    cleanEmptyKey $path
    setFrontEndControls 0
    setCheckState $disableLookaside $false
    $script:loadingGc = $true
    try {
        $gcNum.Value = 0
    } finally {
        $script:loadingGc = $false
    }
    writeGuiLog '[+]' "IFEO values removed for $($exeInput.Text)" -HighlightColor Green
} 70 | Out-Null

$programList = [Windows.Forms.ListView]@{
    Location      = [Drawing.Point]::new(15, 68)
    Size          = [Drawing.Size]::new(708, 300)
    View          = 'Details'
    FullRowSelect = $true
    GridLines     = $false
    BackColor     = $grayColor
    ForeColor     = $whiteColor
    Font          = $smallFont
}
[void]$programList.Columns.Add('Name', 180)
[void]$programList.Columns.Add('Exe', 135)
[void]$programList.Columns.Add('Source', 85)
[void]$programList.Columns.Add('Path', 250)

$programList.Add_DoubleClick({
    if ($programList.SelectedItems.Count -gt 0) {
        setExeInput $programList.SelectedItems[0].SubItems[1].Text
        refreshIfeo
    }
})
$programList.Add_SelectedIndexChanged({
    if ($programList.SelectedItems.Count -gt 0) {
        setExeInput $programList.SelectedItems[0].SubItems[1].Text
        refreshIfeo
    }
})
$programPanel.Controls.Add($programList)

function setProgramRows($Items) {
    $programList.BeginUpdate()
    try {
        $programList.Items.Clear()
        foreach ($item in $Items) {
            $row = [Windows.Forms.ListViewItem]::new($item.Name)
            [void]$row.SubItems.Add($item.Exe)
            [void]$row.SubItems.Add($item.Source)
            [void]$row.SubItems.Add($item.Path)
            $row.Tag = $item
            [void]$programList.Items.Add($row)
        }
    } finally { $programList.EndUpdate() }
}

function startProgramDetect {
    if ($script:detectJob -and $script:detectJob.State -eq 'Running') {
        writeGuiLog '[~]' 'Program detection already running' -HighlightColor Gray
        return
    }
    try {
        $init = [scriptblock]::Create(@"
function getExeFromIcon { ${function:getExeFromIcon} }
function addProgramRow { ${function:addProgramRow} }
function resolveShortcut { ${function:resolveShortcut} }
function getInstalledExecutables { ${function:getInstalledExecutables} }
"@)
        $script:detectJob = Start-Job -InitializationScript $init -ScriptBlock { getInstalledExecutables } -ErrorAction Stop
        $script:detectTimer.Start()
    } catch {
        writeGuiLog '[-]' "Program detection failed: $($_.Exception.Message)" -HighlightColor Red
    }
}

$script:detectTimer = [Windows.Forms.Timer]::new()
$script:detectTimer.Interval = 500
$script:detectTimer.Add_Tick({
    if (!$script:detectJob) {
        $script:detectTimer.Stop()
        return
    }
    if ($script:detectJob.State -eq 'Running') { return }

    $job = $script:detectJob
    $script:detectJob = $null
    $script:detectTimer.Stop()

    if ($job.State -eq 'Completed') {
        $items = @(Receive-Job -Job $job)
        setProgramRows $items
        writeGuiLog '[+]' "Found $($items.Count) executable entries" -HighlightColor Green
    } else {
        $reason = $job.ChildJobs[0].JobStateInfo.Reason.Message
        if (!$reason) { $reason = $job.State }
        writeGuiLog '[-]' "Program detection failed: $reason" -HighlightColor Red
    }
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
})

$bitPanel = newPanel 370 395 740 210 'FrontEndHeapDebugOptions'
$nvmain.Controls.Add($bitPanel)
$bitChecks = @{}
$bitNames = @{
    0  = 'LFH flag 4'
    1  = 'LFH flag 2'
    2  = 'disable Segment'
    3  = 'enable Segment'
    4  = 'heap stack trace'
    5  = 'heap feature 4'
    6  = 'app compat'
    7  = 'heap feature 8'
    22 = 'GCInterval'
}
foreach ($i in @(0, 1, 2, 3, 4, 5, 6, 7)) {
    $index = $bitChecks.Count
    $col = [int][Math]::Floor($index / 4)
    $row = $index % 4
    $x = 15 + ($col * 185)
    $y = 32 + ($row * 22)
    $text = if ($bitNames.ContainsKey($i)) { "bit $i - $($bitNames[$i])" } else { "bit $i" }
    $bitChecks[$i] = newCheck $bitPanel $text $x $y $false
}
$bitChecks[22] = newCheck $bitPanel 'bit 22 - GCInterval' 385 32 $false
$lfhContention = newCheck $bitPanel 'bits 8-15 - LFH contention' 385 54 $false
$lfhPerf       = newCheck $bitPanel 'bits 16-27 - LFH perf' 385 76 $false

$disableLookaside = newCheck $bitPanel 'DisableHeapLookaside' 15 145 $false
newLabel $bitPanel 'GCInterval seconds' 185 145 125 | Out-Null
$gcNum = newNumber $bitPanel 310 142 0 4294967295 1 0
$gcNum.Add_ValueChanged({
    if (!$script:loadingGc) { setCheckState $bitChecks[22] $true }
})

newButton $bitPanel 'NT Heap' 5 179 { setFrontEndControls 4 } 80 | Out-Null
newButton $bitPanel 'Segment' 90 179 { setFrontEndControls 8 } 80 | Out-Null
newButton $bitPanel 'Clear' 175 179 {
    setFrontEndControls 0
    setCheckState $disableLookaside $false
    $script:loadingGc = $true
    try {
        $gcNum.Value = 0
    } finally {
        $script:loadingGc = $false
    }
} 80 | Out-Null

newButton $bitPanel 'Apply' 260 179 {
    $path = getIfeoPath
    if (!$path) { writeGuiLog '[-]' 'Enter/select an exe first' -HighlightColor Red; return }
    $value = getFrontEndValue
    if (!(setDword $path 'FrontEndHeapDebugOptions' $value)) {
        writeGuiLog '[-]' "IFEO write failed: $script:lastRegistryError" -HighlightColor Red
        return
    }
    if (getCheckState $disableLookaside) {
        if (!(setDword $path 'DisableHeapLookaside' 1)) {
            writeGuiLog '[-]' "IFEO write failed: $script:lastRegistryError" -HighlightColor Red
            return
        }
    } else {
        removeValue $path 'DisableHeapLookaside'
    }
    if ((getCheckState $bitChecks[22]) -and [uint32]$gcNum.Value -gt 0) {
        if (!(setDword $path 'GCInterval' ([uint32]$gcNum.Value))) {
            writeGuiLog '[-]' "IFEO write failed: $script:lastRegistryError" -HighlightColor Red
            return
        }
    } else {
        removeValue $path 'GCInterval'
    }
    writeGuiLog '[+]' "IFEO written for $($exeInput.Text)" -HighlightColor Green
} 80 | Out-Null

$logPanel = [Windows.Forms.Panel]@{
    Location    = [Drawing.Point]::new(5, 270)
    Size        = [Drawing.Size]::new(360, 335)
    BackColor   = $grayColor
    BorderStyle = 'FixedSingle'
}
$nvmain.Controls.Add($logPanel)
$logs = [Windows.Forms.RichTextBox]@{
    Multiline   = $true
    ReadOnly    = $true
    ScrollBars  = [Windows.Forms.RichTextBoxScrollBars]::Vertical
    BackColor   = $grayColor
    ForeColor   = $whiteColor
    Font        = [Drawing.Font]::new('Consolas', 9)
    BorderStyle = 'None'
    Location    = [Drawing.Point]::new(1, 1)
    Size        = [Drawing.Size]::new(357, 207)
}
$logPanel.Controls.Add($logs)

function resizeForm {
    $rightWidth = [Math]::Max(650, $nvmain.ClientSize.Width - 375)
    $programPanel.Width = $rightWidth
    $bitPanel.Width     = $rightWidth

    $programPanel.Height = [Math]::Max(260, $nvmain.ClientSize.Height - $programPanel.Top - $bitPanel.Height - 10)
    $programList.Height  = [Math]::Max(70, $programPanel.ClientSize.Height - $programList.Top - 15)
    $bitPanel.Top        = $programPanel.Bottom + 5

    $logPanel.Height           = [Math]::Max(70, $nvmain.ClientSize.Height - $logPanel.Top - 5)
    $logs.Width                = $logPanel.ClientSize.Width - 2
    $programList.Width         = $programPanel.ClientSize.Width - 30
    $programList.Columns[3].Width = [Math]::Max(180, $programList.Width - 420)
    $logs.Height               = $logPanel.ClientSize.Height - 2
}

$nvmain.Add_Resize({ resizeForm })
resizeForm

refreshGlobal
refreshNtDefaults
setFrontEndControls 0

$nvmain.Add_Shown({
    resizeForm
    $nvmain.Refresh()
    startProgramDetect
})

$nvmain.Add_FormClosing({
    if ($script:detectTimer) { $script:detectTimer.Stop() }
    if ($script:detectJob) {
        Remove-Job -Job $script:detectJob -Force -ErrorAction SilentlyContinue
        $script:detectJob = $null
    }
})

if ($HideConsole) {
    try {
        [HeapWinAPI]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0) | Out-Null
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
