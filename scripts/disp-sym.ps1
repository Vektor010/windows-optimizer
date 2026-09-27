#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Графическая и консольная утилита для исследования структуры памяти ядра Windows
#    и дампа символов (Display Symbols / Kernel Symbol Inspector).
#    Взаимодействует с отладчиком ядра kd.exe (Microsoft WinDbg), считывает список
#    загруженных модулей ядра (lm), выполняет поиск символов (x /1 <module>!*),
#    считывает значения памяти через команды WinDbg (dd, dq, db, dp и др.) и выполняет
#    структурированный экспорт дампов в %LOCALAPPDATA%\Optimizer\Symbols.
#
# 2. ЗАЧЕМ:
#    Необходим для низкоуровневого анализа архитектуры Windows, реверс-инжиниринга
#    недокументированных структур ядра (nt, hal, ntoskrnl, fltmgr), исследования
#    системных механизмов оптимизации и проверки параметров без подключения внешнего
#    аппаратного отладчика.
#
# 3. ПОСЛЕДСТВИЯ:
#    - Требует наличия установленного WinDbg (kd.exe) и включённой отладки ядра
#      (bcdedit /debug on) для взаимодействия с живым ядром (Local Kernel Debugging -kl).
#    - Создаёт текстовые дампы символов в %LOCALAPPDATA%\Optimizer\Symbols\<module>\.
#    - Не изменяет системные параметры ядра (работает в режиме чтения памяти).
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+. Для локальной отладки ядра (-kl) требуются
#    права Администратора.
#
# 5. ОТКАТ:
#    Удаление каталога экспортированных дампов: %LOCALAPPDATA%\Optimizer\Symbols
#    (кнопка «Remove Dumps» в интерфейсе или вызов с ключом -CleanDumps).
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
    [Parameter()]
    [string]$Module,

    [Parameter()]
    [switch]$ListModules,

    [Parameter()]
    [ValidateSet('d', 'da', 'db', 'dc', 'dd', 'dD', 'df', 'dp', 'dq', 'du', 'dw')]
    [string]$DisplayCommand = 'dd',

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$Length = 1,

    [Parameter()]
    [string]$OutputDir = "$env:LOCALAPPDATA\Optimizer\Symbols",

    [Parameter()]
    [switch]$CleanDumps,

    [Parameter()]
    [switch]$Status,

    [Parameter()]
    [switch]$HideConsole,

    [Parameter()]
    [switch]$NoGui
)

# Поиск пути к отладчику ядра kd.exe
function Get-KdPath {
    $inPath = (Get-Command 'kd.exe' -ErrorAction SilentlyContinue).Source
    if ($inPath) { return $inPath }

    $roots = @(
        "$env:ProgramFiles\Windows Kits",
        "${env:ProgramFiles(x86)}\Windows Kits",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps",
        "$env:ProgramFiles\WindowsApps\Microsoft.WinDbg_*_x64__8wekyb3d8bbwe"
    )

    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $found = Get-ChildItem -LiteralPath $root -Recurse -Filter 'kd.exe' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\(x64|amd64)\\kd\.exe$' } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

# Проверка активации отладки ядра в BCD
function Test-KernelDebuggingEnabled {
    $currentBcd = bcdedit /enum "{current}" 2>$null
    if ($currentBcd -match '(?i)^\s*debug\s+(?:Yes|True|1)\b') {
        return $true
    }
    return $false
}

# Очистка сохранённых дампов
if ($CleanDumps) {
    if (Test-Path -LiteralPath $OutputDir) {
        Get-ChildItem -LiteralPath $OutputDir -Directory -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Каталог дампов очищен: $OutputDir" -ForegroundColor Green
    } else {
        Write-Host "[i] Каталог дампов пуст: $OutputDir" -ForegroundColor Cyan
    }
    return
}

# Отображение статуса среды отладки
if ($Status) {
    $kd = Get-KdPath
    $debug = Test-KernelDebuggingEnabled
    Write-Host "=== Статус среды отладки ядра Windows (disp-sym) ===" -ForegroundColor Cyan
    Write-Host ("Отладчик ядра (kd.exe)   : {0}" -f $(if ($kd) { $kd } else { "НЕ НАЙДЕН (установите WinDbg через winget install Microsoft.WinDbg)" })) -ForegroundColor $(if ($kd) { "Green" } else { "Yellow" })
    Write-Host ("Отладка ядра (BCD debug) : {0}" -f $(if ($debug) { "ВКЛЮЧЕНА (bcdedit /debug on)" } else { "ВЫКЛЮЧЕНА (для включения выполните: bcdedit /debug on)" })) -ForegroundColor $(if ($debug) { "Green" } else { "Yellow" })
    Write-Host ("Каталог сохранения дампов: {0}" -f $OutputDir) -ForegroundColor Cyan
    Write-Host ("Команда отображения памяти: {0} (длина: {1})" -f $DisplayCommand, $Length) -ForegroundColor Gray
    return
}

# Вывод списка модулей в CLI
if ($ListModules) {
    $kd = Get-KdPath
    if (-not $kd) {
        throw "kd.exe не найден в системе. Установите WinDbg (winget install Microsoft.WinDbg)."
    }
    Write-Host "[~] Запрос списка модулей ядра через kd.exe -kl..." -ForegroundColor Cyan
    $modList = & $kd -kl -c ".reload /f; lm; q"
    $mods = $modList -split "`r?`n" | ForEach-Object {
        if ($_ -match '^\s*[0-9A-Fa-f`]+\s+[0-9A-Fa-f`]+\s+(\S+)') { $matches[1] }
    } | Sort-Object -Unique
    Write-Host "[+] Найдено модулей ядра: $($mods.Count)" -ForegroundColor Green
    $mods
    return
}

# Headless дамп символов для указанного модуля из CLI
if ($Module) {
    $kd = Get-KdPath
    if (-not $kd) {
        throw "kd.exe не найден в системе. Установите WinDbg (winget install Microsoft.WinDbg)."
    }

    $moduledir = Join-Path $OutputDir $Module
    if (-not (Test-Path -LiteralPath $moduledir)) {
        [System.IO.Directory]::CreateDirectory($moduledir) | Out-Null
    }

    $outsym = Join-Path $moduledir "$Module-Symbols.txt"
    $outfin = Join-Path $moduledir "$Module-Dump.txt"

    Write-Host "[~] Поиск символов модуля $Module..." -ForegroundColor Cyan
    & $kd -kl -c ".reload /f; .logopen `"$outsym`"; x /1 ${Module}!*; .logclose; q" | Out-Null

    if (-not (Test-Path -LiteralPath $outsym)) {
        throw "Не удалось сгенерировать файл символов: $outsym"
    }

    Write-Host "[+] Символы экспортированы в: $outsym" -ForegroundColor Green
    return
}

# Если запрошен режим без GUI
if ($NoGui) {
    Write-Host "[i] Запуск в режиме NoGui без параметров. Используйте -Status, -ListModules, -Module <имя> или запустите интерактивный GUI." -ForegroundColor Cyan
    return
}

# ==============================================================================
# ИНТЕРАКТИВНЫЙ ГРАФИЧЕСКИЙ ИНТЕРФЕЙС (WinForms)
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'WinAPI').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction SilentlyContinue | Out-Null
}

$script:kd = Get-KdPath
$script:memDisplay = $DisplayCommand
$script:memLength  = $Length
$script:selectedBoxName = $null
$script:selectedBox = $null
$script:modules = @()

# Проверка наличия kd.exe перед запуском GUI
if (-not $script:kd) {
    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Отладчик ядра kd.exe (WinDbg) не найден в системе.`n`nУстановите Microsoft WinDbg через winget:`nwinget install Microsoft.WinDbg`n`nОткрыть сайт загрузки WinDbg?",
        "WinDbg / kd.exe не найден",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process "https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/"
    }
    return
}

# Проверка статуса отладки ядра
if (-not (Test-KernelDebuggingEnabled)) {
    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Отладка ядра в системе выключена.`n`nДля локального анализа живого ядра (Local Kernel Debugging -kl) требуется включить отладку:`nbcdedit /debug on`n`nВключить отладку ядра прямо сейчас?",
        "Отладчик ядра выключен",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Start-Process bcdedit -Verb RunAs -Wait -ArgumentList '/debug', 'on'
            [System.Windows.Forms.MessageBox]::Show(
                "Отладка ядра включена. Для применения настроек потребуется перезагрузка Windows.",
                "Перезагрузка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Ошибка включения отладки: $($_.Exception.Message)",
                "Ошибка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
}

# Подготовка локального каталога дампов
if (-not (Test-Path -LiteralPath $OutputDir)) {
    [System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
}

$inputf = [Drawing.Font]::new('Segoe UI', 10, [Drawing.FontStyle]::Regular)
$blue = [Drawing.Color]::CornflowerBlue
$gray = [Drawing.Color]::FromArgb(40, 40, 40)
$white = [Drawing.Color]::White
$boxempty = [Drawing.Color]::Transparent

# Безопасная загрузка системной иконки
$appIcon = $null
$cachedIcon = Join-Path $env:TEMP 'Optimizer.ico'
if (Test-Path -LiteralPath $cachedIcon) {
    try { $appIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($cachedIcon) } catch { $null = $_ }
}
if (-not $appIcon) {
    $appIcon = [System.Drawing.SystemIcons]::Application
}

$nvmain = [Windows.Forms.Form]@{
    Text = 'Optimizer Symbols - Kernel Debugger Inspector'
    Size = [Drawing.Size]::new(1305, 800)
    StartPosition = 'CenterScreen'
    BackColor = [Drawing.Color]::FromArgb(28, 28, 28)
    FormBorderStyle = 'Sizable'
    Icon = $appIcon
    MinimumSize = [Drawing.Size]::new(600, 200)
}

$modulepanel = [Windows.Forms.Panel]@{
    Location = [Drawing.Point]::new(5, 35)
    Size = [Drawing.Size]::new(850, 721)
    BackColor = $gray
    BorderStyle = 'FixedSingle'
    AutoScroll = $true
}
$nvmain.Controls.Add($modulepanel)

$logspanel = [Windows.Forms.Panel]@{
    Location = [Drawing.Point]::new(860, 35)
    Size = [Drawing.Size]::new(425, 721)
    BackColor = [Drawing.Color]::FromArgb(40, 40, 40)
    BorderStyle = 'FixedSingle'
}
$nvmain.Controls.Add($logspanel)

$logs = [Windows.Forms.RichTextBox]@{
    Multiline = $true
    ReadOnly = $true
    ScrollBars = [Windows.Forms.RichTextBoxScrollBars]::Vertical
    BackColor = [Drawing.Color]::FromArgb(40, 40, 40)
    ForeColor = $white
    Font = [Drawing.Font]::new('Consolas', 9)
    BorderStyle = 'None'
    Location = [Drawing.Point]::new(1, 1)
    Size = [Drawing.Size]::new(423, 714)
}
$logspanel.Controls.Add($logs)

function log {
    param (
        [string]$HighlightMessage,
        [string]$Message,
        [string]$Sequence = '',
        [ConsoleColor]$TimeColor = 'DarkGray',
        [ConsoleColor]$HighlightColor = 'White',
        [ConsoleColor]$MessageColor = 'White',
        [ConsoleColor]$SequenceColor = 'White'
    )
    $timestamp = "[{0:HH:mm:ss}]" -f (Get-Date)

    function appendColor($text, $color) {
        $logs.SelectionStart = $logs.Text.Length
        $logs.SelectionColor = [Drawing.Color]::$color
        $logs.AppendText($text)
    }

    appendColor "$timestamp " $TimeColor
    appendColor "$HighlightMessage " $HighlightColor
    appendColor "$Message " $MessageColor
    appendColor "$Sequence`r`n" $SequenceColor
    $logs.SelectionStart = $logs.Text.Length
    $logs.ScrollToCaret()
}

$cmbMemDisp = [Windows.Forms.ComboBox]@{
    DropDownStyle = 'DropDownList'
    Location = [Drawing.Point]::new($nvmain.Right - 835, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Font = [Drawing.Font]::new('Segoe UI', 10, [Drawing.FontStyle]::Regular)
    Size = [Drawing.Size]::new(80, 25)
}
$cmbMemDisp.Items.AddRange(@('d', 'da', 'db', 'dc', 'dd', 'dD', 'df', 'dp', 'dq', 'du', 'dw'))
$cmbMemDisp.SelectedItem = $script:memDisplay
$cmbMemDisp.Add_SelectedIndexChanged({
    $script:memDisplay = $cmbMemDisp.SelectedItem
    log "[~]" "Changed d* command to $script:memDisplay" -HighlightColor Gray
})
$nvmain.Controls.Add($cmbMemDisp)

$lenpanel = [Windows.Forms.Panel]@{
    Location = [Drawing.Point]::new($nvmain.Right - 750, 5)
    Size = [Drawing.Size]::new(80, 25)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    BorderStyle = 'FixedSingle'
}
$nvmain.Controls.Add($lenpanel)

$lenminus = [Windows.Forms.Label]@{
    Text = '-'
    Location = [Drawing.Point]::new(2, 0)
    ForeColor = 'Tomato'
    AutoSize = $true
    BackColor = $lenpanel.BackColor
    Font = [Drawing.Font]::new('Segoe UI', 11)
}
$lenpanel.Controls.Add($lenminus)

$lenbox = [Windows.Forms.TextBox]@{
    BorderStyle = 'None'
    BackColor = $lenpanel.BackColor
    ForeColor = $white
    Font = $inputf
    Location = [Drawing.Point]::new(18, 2)
    Size = [Drawing.Size]::new(40, 21)
    Text = "$script:memLength"
    TextAlign = 'Center'
}

$lenbox.Add_KeyPress({
    if (![char]::IsControl($_.KeyChar) -and ![char]::IsDigit($_.KeyChar)) {
        $_.Handled = $true
    }
})

$lenbox.Add_TextChanged({
    if ([int]::TryParse($lenbox.Text, [ref]([int]$null)) -and [int]$lenbox.Text -gt 0) {
        $script:memLength = [int]$lenbox.Text
    } else {
        $lenbox.Text = "1"
        $script:memLength = 1
    }
})
$lenpanel.Controls.Add($lenbox)

$lenplus = [Windows.Forms.Label]@{
    Text = '+'
    Location = [Drawing.Point]::new(62, 0)
    ForeColor = 'DarkSeaGreen'
    AutoSize = $true
    BackColor = $lenpanel.BackColor
    Font = [Drawing.Font]::new('Segoe UI', 11)
}
$lenpanel.Controls.Add($lenplus)

$lenminus.Add_Click({
    if ([int]::TryParse($lenbox.Text, [ref]$null)) {
        $value = [int]$lenbox.Text
        $lenbox.Text = [Math]::Max(1, $value - 1).ToString()
    } else {
        $lenbox.Text = '1'
    }
})

$lenplus.Add_Click({
    if ([int]::TryParse($lenbox.Text, [ref]$null)) {
        $value = [int]$lenbox.Text
        $lenbox.Text = [Math]::Min(1000, $value + 1).ToString()
    } else {
        $lenbox.Text = '1'
    }
})

$searchbox = [Windows.Forms.TextBox]@{
    BorderStyle = 'FixedSingle'
    Multiline = $true
    Font = $inputf
    Location = [Drawing.Point]::new(5, 5)
    Size = [Drawing.Size]::new($modulepanel.Width / 4.25, 25)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
}
$nvmain.Controls.Add($searchbox)

$dump = [Windows.Forms.Button]@{
    Text = "Dump"
    Location = [Drawing.Point]::new($nvmain.Right - 100, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(80, 25)
    Font = $inputf
}
$dump.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$dump.FlatAppearance.BorderSize = 1
$dump.Add_Click({
    if (-not $script:selectedBoxName) { log "[-]" "Select a module" -HighlightColor Red; return }
    $mod = $script:selectedBoxName
    log "[+]" "Using module $mod" -HighlightColor Green
    $moduledir = Join-Path $OutputDir $mod
    if (-not (Test-Path -LiteralPath $moduledir)) {
        [System.IO.Directory]::CreateDirectory($moduledir) | Out-Null
    }

    $outsym = Join-Path $moduledir "$mod-Symbols.txt"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    log "[~]" "Searching symbol names" -HighlightColor Gray
    & $script:kd -kl -c ".reload /f; .logopen `"$outsym`"; x /1 ${mod}!*; .logclose; q"
    if (-not (Test-Path -LiteralPath $outsym)) { log "[!]" "No output file" -HighlightColor Red; return }

    $in = $outsym
    $out = Join-Path $moduledir "$mod-Filtered.txt"

    log "[~]" "First filter phase" -HighlightColor Gray
    $regsym = [regex]'(\S+![^\s(]+)'
    $regparen = [regex]'\s+\(.*$'
    $lines = [System.IO.File]::ReadAllLines($in)
    if ($lines.Length -ge 3) {
        $lines = $lines[1..($lines.Length - 2)]
    }

    $escapedMod = [regex]::Escape($mod)
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match "$escapedMod!(?:_xmm|write_char|write_string|write_multi_char|chunkset_core|ReadString|\s\?\?)") { continue }

        $line = $line.Replace(' = <no type information>', '')
        $line = $regparen.Replace($line, '')

        $m = $regsym.Match($line)
        if (-not $m.Success) { continue }

        $sym = $m.Groups[1].Value
        $null = $sb.Append($script:memDisplay).Append(' ').Append($sym).Append(' l').AppendLine($script:memLength.ToString())
    }
    [System.IO.File]::WriteAllText($out, $sb.ToString())

    $outkd = Join-Path $moduledir "$mod-KD.txt"
    $kdcmd = '.reload /f;.logopen "{0}"; $$< "{1}"; .logclose; q' -f $outkd, $out
    $pscmd = "& '$($script:kd)' -kl -c '$kdcmd'"
    log "[*]" "KD output window minimized" -HighlightColor DarkCyan
    Start-Process powershell.exe -ArgumentList @('-Command', $pscmd) -WindowStyle Minimized -Wait

    log "[~]" "Second filter phase" -HighlightColor Gray
    $outfin = Join-Path $moduledir "$mod-Dump.txt"

    $regerror = [regex]'\berror\b'
    $readdr = [regex]'^[0-9A-Fa-f]{8}`[0-9A-Fa-f]{8}\s+'
    $regparen = [regex]' \([^)]*\)'
    $reglkd = [regex]('lkd> {0} {1}!' -f [regex]::Escape($script:memDisplay), [regex]::Escape($mod))
    $reglength = [regex]("(?i)\s+l{0}$" -f [regex]::Escape($script:memLength.ToString()))
    $regmatch = [regex]'^Matched:'
    $regendp = [regex]'\)+$'

    function Get-HexChunkWidth([string]$cmd) {
        switch -Regex ($cmd) {
            '^(db)$'         { return 2 }
            '^(dw)$'         { return 4 }
            '^(dd|dD|dc|d)$' { return 8 }
            '^(dq|dp)$'      { return 16 }
            default          { return 0 }
        }
    }

    $chunkWidth = Get-HexChunkWidth $script:memDisplay

    if ($chunkWidth -gt 0) {
        $chunkPattern = "[0-9A-Fa-f?]{$chunkWidth}"
        $regHexLine = [regex]("^(?:$chunkPattern)(?:\s+$chunkPattern){0,3}$")
        function Get-ChunkCount([string]$line, [string]$chunk) {
            return ([regex]::Matches($line, $chunk)).Count
        }
    } else {
        $regHexLine = [regex]"^\b$"
        function Get-ChunkCount([string]$line, [string]$chunk) { return 0 }
    }

    $kdLines = [System.IO.File]::ReadAllLines($outkd)
    if ($kdLines.Length -ge 3) {
        $kdLines = $kdLines[1..($kdLines.Length - 2)]
    }

    $lstout = [System.Collections.Generic.List[string]]::new()
    $prev = $null
    $chunksCollected = 0
    $chunksNeeded = [Math]::Max(1, $script:memLength)
    $haveSep = $false

    foreach ($raw in $kdLines) {
        $clean = $readdr.Replace($raw, '')
        $clean = $regparen.Replace($clean, '')
        $clean = $reglkd.Replace($clean, '')
        $clean = $reglength.Replace($clean, '')
        $clean = $regendp.Replace($clean, '')

        if ($regerror.IsMatch($clean) -or $regmatch.IsMatch($clean)) {
            $prev = $null
            $chunksCollected = 0
            $haveSep = $false
            continue
        }

        if ($null -ne $prev -and $chunkWidth -gt 0 -and $regHexLine.IsMatch($clean) -and $chunksCollected -lt $chunksNeeded) {
            if (-not $haveSep) {
                $prev = "$prev <> $clean"
                $haveSep = $true
            } else {
                $prev = "$prev $clean"
            }
            $chunksCollected += Get-ChunkCount $clean $chunkPattern
            continue
        }

        if ($null -ne $prev) { $lstout.Add($prev) }

        $prev = $clean
        $chunksCollected = 0
        $haveSep = $false
        if ($chunkWidth -gt 0 -and $regHexLine.IsMatch($clean)) {
            $chunksCollected = Get-ChunkCount $clean $chunkPattern
        }
    }

    if ($null -ne $prev) { $lstout.Add($prev) }

    $sortdump = $lstout | Sort-Object
    [System.IO.File]::WriteAllLines($outfin, $sortdump)

    $sw.Stop()
    log "[+]" "$($sw.Elapsed.TotalSeconds) seconds" -HighlightColor Green
})

$discord = [Windows.Forms.Button]@{
    Text = "Discord"
    Location = [Drawing.Point]::new($nvmain.Right - 665, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(80, 25)
    Font = $inputf
}
$discord.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$discord.FlatAppearance.BorderSize = 1
$discord.Add_Click({
    log "[~]" "Opening link" -HighlightColor Gray
    Start-Process "https://discord.gg/E2ybG4j9jU"
})

$phasefolder = [Windows.Forms.Button]@{
    Text = "Phase Folder"
    Location = [Drawing.Point]::new($nvmain.Right - 205, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(100, 25)
    Font = $inputf
}
$phasefolder.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$phasefolder.FlatAppearance.BorderSize = 1
$phasefolder.Add_Click({
    log "[~]" "Opening folder" -HighlightColor Gray
    Start-Process $OutputDir
})

$reloadBtn = [Windows.Forms.Button]@{
    Text = "Reload Modules"
    Location = [Drawing.Point]::new($nvmain.Right - 330, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(120, 25)
    Font = $inputf
}
$reloadBtn.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$reloadBtn.FlatAppearance.BorderSize = 1
$reloadBtn.Add_Click({ reloadModules })

$remdumps = [Windows.Forms.Button]@{
    Text = "Remove Dumps"
    Location = [Drawing.Point]::new($nvmain.Right - 455, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(120, 25)
    Font = $inputf
}
$remdumps.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$remdumps.FlatAppearance.BorderSize = 1
$remdumps.Add_Click({
    log "[~]" "Removing dump folders" -HighlightColor Gray
    if (Test-Path -LiteralPath $OutputDir) {
        Get-ChildItem -LiteralPath $OutputDir -Directory -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
})

$kdsession = [Windows.Forms.Button]@{
    Text = "New KD Session"
    Location = [Drawing.Point]::new($nvmain.Right - 580, 5)
    BackColor = [Drawing.Color]::FromArgb(50, 50, 50)
    ForeColor = $white
    FlatStyle = 'Flat'
    Size = [Drawing.Size]::new(120, 25)
    Font = $inputf
}
$kdsession.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$kdsession.FlatAppearance.BorderSize = 1
$kdsession.Add_Click({
    log "[~]" "Starting new kernel debugging session" -HighlightColor Gray
    Start-Process "$($script:kd)" -Verb RunAs -ArgumentList '-kl'
})

$nvmain.Controls.AddRange(@($dump, $discord, $phasefolder, $reloadBtn, $kdsession, $remdumps))

function modulelist {
    param([string]$filter)

    $filterstring = if ($null -ne $filter) { $filter.Trim() } else { "" }

    $names = if ($filterstring -eq "") {
        $script:modules
    } else {
        $script:modules | Where-Object { $_ -like "*$filterstring*" }
    }

    for ($i = $modulepanel.Controls.Count - 1; $i -ge 0; $i--) {
        $c = $modulepanel.Controls[$i]
        if ($c.Tag -and ($c.Tag.Kind -in @('mod', 'grid'))) {
            $modulepanel.Controls.RemoveAt($i)
            $c.Dispose()
        }
    }

    $padx = 10
    $pady = 8
    $rowh = 22
    $boxgap = 35
    $panelw = [Math]::Max(0, $modulepanel.ClientSize.Width)

    $mincolw = 180
    $maxcolw = 320
    $maxcols = 8
    $colamount = [Math]::Max(1, [Math]::Min($maxcols, [Math]::Floor(($panelw - $padx) / ($mincolw + $padx))))
    if ($colamount -lt 1) { $colamount = 1 }

    $colw = if ($colamount -gt 0) { [Math]::Floor(($panelw - (($colamount + 1) * $padx)) / $colamount) } else { $panelw - (2 * $padx) }
    $colw = [Math]::Max($mincolw, [Math]::Min($maxcolw, $colw))
    $labelbw = [Math]::Max(10, $colw - $boxgap)

    $modulepanel.SuspendLayout()
    for ($i = 0; $i -lt $names.Count; $i++) {
        $name = $names[$i]
        $col = $i % $colamount
        $row = [math]::Floor($i / $colamount)

        $x = $padx + ($col * ($colw + $padx))
        $y = $pady + ($row * ($rowh + $pady))

        $box = New-Object Windows.Forms.Panel
        $box.Size = [Drawing.Size]::new(13, 13)
        $box.Location = [Drawing.Point]::new($x, $y)
        $box.BackColor = $boxempty
        $box.BorderStyle = 'FixedSingle'
        $box.Tag = @{ Kind = 'mod'; Name = $name; Checked = $false }

        $label = New-Object Windows.Forms.Label
        $label.Text = $name
        $label.ForeColor = $white
        $label.BackColor = $boxempty
        $label.Location = [Drawing.Point]::new($x + 20, $y - 2)
        $label.AutoSize = $true
        if ($names.Count -eq 1) {
            $available = $modulepanel.ClientSize.Width - ($label.Location.X + $padx)
            $label.Width = [Math]::Max(10, $available)
        } else {
            $label.Width = $labelbw
        }
        $label.AutoEllipsis = $true
        $label.Font = [Drawing.Font]::new('Segoe UI', 9, [Drawing.FontStyle]::Regular)
        $label.Tag = @{ Kind = 'mod'; Name = $name }

        if ($script:selectedBoxName -and $name -eq $script:selectedBoxName) {
            $box.Tag.Checked = $true
            $box.BackColor = $blue
            $script:selectedBox = $box
        }

        $currentb = $box
        $panel = $modulepanel
        $cblue = $blue
        $cempty = $boxempty
        $click = {
            if ($panel -and -not $panel.IsDisposed) {
                foreach ($ctrl in $panel.Controls) {
                    if ($ctrl -is [System.Windows.Forms.Panel] -and $ctrl.Tag -and $ctrl.Tag.Kind -eq 'mod') {
                        $ctrl.Tag.Checked = $false
                        $ctrl.BackColor = $cempty
                    }
                }
            }
            $currentb.Tag.Checked = $true
            $currentb.BackColor = $cblue
            $script:selectedBox = $currentb
            $script:selectedBoxName = $currentb.Tag.Name
        }.GetNewClosure()

        $box.Add_Click($click)
        $label.Add_Click($click)
        $modulepanel.Controls.AddRange(@($box, $label))
    }

    $gridc = [Drawing.Color]::FromArgb(80, 80, 80)
    $totrows = [math]::Ceiling(($names.Count) / $colamount)
    $reqh = $pady + ($totrows * ($rowh + $pady)) + $pady
    $fullh = [Math]::Max($modulepanel.ClientSize.Height, $reqh)

    for ($c = 0; $c -le $colamount; $c++) {
        $vx = ($padx * $c) + ($colw * $c)
        $v = New-Object Windows.Forms.Panel
        $v.BackColor = $gridc
        $v.Tag = @{ Kind = 'grid'; Axis = 'V' }
        $v.Width = 1
        $v.Height = $fullh
        $v.Location = [Drawing.Point]::new($vx, 0)
        $modulepanel.Controls.Add($v)
        $v.BringToFront()
    }

    for ($r = 0; $r -le $totrows; $r++) {
        $hy = ($pady + ($r * ($rowh + $pady))) - 8
        if ($hy -lt 0) { $hy = 0 }
        $h = New-Object Windows.Forms.Panel
        $h.BackColor = $gridc
        $h.Tag = @{ Kind = 'grid'; Axis = 'H' }
        $h.Height = 1
        $h.Width = [Math]::Max(0, $modulepanel.ClientSize.Width)
        $h.Location = [Drawing.Point]::new(0, $hy)
        $modulepanel.Controls.Add($h)
        $h.BringToFront()
    }

    $modulepanel.ResumeLayout($true)
    $modulepanel.AutoScrollMinSize = New-Object Drawing.Size(0, $reqh)
}

$searchbox.Add_TextChanged({ modulelist -Filter $searchbox.Text })

if (-not (Get-Variable loadertimer -Scope Script -ErrorAction SilentlyContinue)) {
    $script:loadertimer = New-Object Windows.Forms.Timer
    $script:loadertimer.Interval = 400
    $script:loadertimer.Add_Tick({
        $job = $script:loadertimer.Tag
        if (-not $job) { return }

        if ($job.State -in @('Completed', 'Failed', 'Stopped')) {
            if ($job.State -eq 'Completed') {
                $result = Receive-Job $job
                $mods = @($result) | Where-Object { $_ -and $_ -ne '' }
                if ($mods.Count -gt 0) {
                    $script:modules = $mods
                    log "[+]" "Displaying loaded modules" -HighlightColor Green
                } else {
                    log "[-]" "No modules loaded" -HighlightColor Red
                }
            } else {
                log "[-]" "Module load job: $($job.State)" -HighlightColor Red
            }

            try { Remove-Job $job -Force } catch { $null = $_ }
            $script:loadertimer.Tag = $null
            $script:loadertimer.Stop()

            if (-not $nvmain.IsDisposed) { modulelist -Filter $searchbox.Text }
        }
    })
}

function reloadModules {
    log "[~]" "Reloading modules" -HighlightColor Gray

    $job = Start-Job -ScriptBlock {
        $kdExe = $using:script:kd
        $modList = & "$kdExe" -kl -c ".reload /f; lm; q"
        $mods = $modList -split "`r?`n" | ForEach-Object {
            if ($_ -match '^\s*[0-9A-Fa-f`]+\s+[0-9A-Fa-f`]+\s+(\S+)') { $matches[1] }
        } | Sort-Object -Unique
        $mods
    }

    $script:loadertimer.Tag = $job
    $script:loadertimer.Stop()
    $script:loadertimer.Start()
}

$script:reflowtimer = New-Object Windows.Forms.Timer
$script:reflowtimer.Interval = 200
$script:reflowtimer.Add_Tick({
    $script:reflowtimer.Stop()
    if (-not $nvmain.IsDisposed) { modulelist -Filter $searchbox.Text }
})

$nvmain.Add_Resize({
    $m = 5
    $clientW = $nvmain.ClientSize.Width
    $clientH = $nvmain.ClientSize.Height

    $totalW = [Math]::Max(0, $clientW - (3 * $m))
    $logW = [Math]::Max(200, [Math]::Floor($totalW * 0.33))
    $chkW = [Math]::Max(200, $totalW - $logW)

    $dump.Left = $clientW - 85
    $phasefolder.Left = $clientW - 190
    $reloadBtn.Left = $clientW - 315
    $remdumps.Left = $clientW - 440
    $kdsession.Left = $clientW - 565
    $discord.Left = $clientW - 650
    $lenpanel.Left = $clientW - 735
    $cmbMemDisp.Left = $clientW - 820

    $dump.Top = $m
    $phasefolder.Top = $m
    $reloadBtn.Top = $m
    $remdumps.Top = $m
    $kdsession.Top = $m
    $discord.Top = $m
    $lenpanel.Top = $m
    $cmbMemDisp.Top = $m

    $searchbox.Left = $m
    $searchbox.Top = $m
    $searchbox.Width = $chkW / 4.25

    $modulepanel.Left = $m
    $modulepanel.Top = $searchbox.Bottom + $m
    $modulepanel.Width = $chkW
    $modulepanel.Height = [Math]::Max(100, $clientH - $modulepanel.Top - $m)

    $logspanel.Width = $logW
    $logspanel.Left = $clientW - $m - $logspanel.Width
    $logspanel.Top = 35
    $logspanel.Height = [Math]::Max(100, $clientH - $logspanel.Top - $m)

    $logs.Left = 1
    $logs.Top = 1
    $logs.Width = [Math]::Max(0, $logspanel.ClientSize.Width - 2)
    $logs.Height = [Math]::Max(0, $logspanel.ClientSize.Height - 2)

    $script:reflowtimer.Stop()
    $script:reflowtimer.Start()
})

reloadModules

if ($HideConsole) {
    [WinAPI]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0) | Out-Null
}

[Windows.Forms.Application]::Run($nvmain)