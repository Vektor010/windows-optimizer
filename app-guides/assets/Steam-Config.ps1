# ==============================================================================
# Gaming & System Optimizer - Конфигурация клиента Steam (localconfig.vdf)
# ==============================================================================
# Описание:
#   Скрипт разбирает файл конфигурации аккаунта Steam (localconfig.vdf) в синтаксическое
#   дерево VDF (AST), вносит оптимизированные параметры без нарушения форматирования,
#   создает автоматическую резервную копию (localconfig.vdf.bak) и перезаписывает файл.
#
# Применяемые параметры:
#   1. [Broadcast]
#      Permissions = '0' : Отключение прямых трансляций Steam
#      FirstTimeComplete = '1' : Пропуск мастера настройки вещания
#   2. [system]
#      displayratesasbits = '0' : Отображение скорости загрузки в байтах/с (МБ/с)
#      EnableGameOverlay = '0' : Отключение внутриигрового оверлея Steam
#      InGameOverlayRestoreBrowserTabs = '0' : Отключение авто-восстановления вкладок браузера оверлея
#      InGameOverlayScreenshotNotification = '0' : Отключение всплывающих уведомлений о скриншотах
#      InGameOverlayScreenshotPlaySound = '0' : Отключение звука при создании скриншота
#      NetworkingAllowShareIP = '1' : Ограничение прямого отображения IP (только друзья / SDR relay)
#   3. [streaming_v2]
#      EnableStreaming = '0' : Отключение Remote Play (удаленная трансляция игр)
#   4. [friends]
#      SignIntoFriends = '0' : Отключение автоматического входа в друзья при старте Steam
#   5. [GameRecording]
#      BackgroundRecordMode = '0' : Отключение циклической фоновой видеозаписи геймплея
#   6. [news]
#      NotifyAvailableGames = '0' : Отключение всплывающего окна новостей и скидок при старте/выходе
#   7. [root]
#      LibraryLowBandwidthMode = '1' : Включение режима низкой пропускной способности библиотеки
#      LibraryLowPerfMode = '1' : Включение облегченного режима библиотеки (без анимаций)
#      LibraryDisableCommunityContent = '1' : Отключение загрузки контента сообщества в библиотеке
#      ReadyToPlayIncludesStreaming = '0' : Исключение удаленных устройств из статуса готовности к игре
#      SteamController_Enable_Chord = '0' : Отключение перехвата клавиш контроллера Chord
#      Controller_CheckGuideButton = '0' : Отключение проверки кнопки Guide геймпада
#      SteamController_PSSupport = '0' : Отключение расширенной поддержки PlayStation контроллеров
#   8. [Accessibility]
#      ReduceMotion = '1' : Отключение лишних анимаций и переходов в интерфейсе клиента
# ==============================================================================

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string[]]$paths,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

class vdfnode { [System.Collections.Generic.List[object]]$entries = [System.Collections.Generic.List[object]]::new() }

class vdfentry {
    [string]$kind
    [string]$name
    [string]$value
    [vdfnode]$node
    vdfentry([string]$kind, [string]$name, [string]$value, [vdfnode]$node) {
        $this.kind = $kind; $this.name = $name; $this.value = $value; $this.node = $node
    }
}

function readstr([string]$text, [ref]$pos) {
    $chars = [System.Collections.Generic.List[char]]::new(); $null = $pos.Value++
    while ($pos.Value -lt $text.Length) {
        $char = $text[$pos.Value]
        if ($char -eq '\') {
            if ($pos.Value + 1 -ge $text.Length) { throw 'unterminated escape sequence' }
            $pos.Value++; $chars.Add($text[$pos.Value]); $null = $pos.Value++; continue
        }
        if ($char -eq '"') { $null = $pos.Value++; return -join $chars }
        $chars.Add($char); $null = $pos.Value++
    }
    throw 'unterminated string'
}

function skipws([string]$text, [ref]$pos) {
    while ($pos.Value -lt $text.Length) {
        $char = $text[$pos.Value]
        if ([char]::IsWhiteSpace($char)) { $null = $pos.Value++; continue }
        if ($char -eq '/' -and $pos.Value + 1 -lt $text.Length -and $text[$pos.Value + 1] -eq '/') {
            while ($pos.Value -lt $text.Length -and $text[$pos.Value] -notin "`r", "`n") { $null = $pos.Value++ }
            continue
        }
        break
    }
}

function parseobj([string]$text, [ref]$pos) {
    $node = [vdfnode]::new()
    while ($true) {
        skipws $text $pos
        if ($pos.Value -ge $text.Length) { throw 'unexpected end of file' }
        if ($text[$pos.Value] -eq '}') { $null = $pos.Value++; return $node }
        if ($text[$pos.Value] -ne '"') { throw "expected key at offset $($pos.Value)" }
        $name = readstr $text $pos; skipws $text $pos
        if ($pos.Value -ge $text.Length) { throw "missing value for '$name'" }
        if ($text[$pos.Value] -eq '{') {
            $null = $pos.Value++
            $node.entries.Add([vdfentry]::new('block', $name, $null, (parseobj $text $pos)))
            continue
        }
        if ($text[$pos.Value] -ne '"') { throw "expected string or block for '$name'" }
        $node.entries.Add([vdfentry]::new('value', $name, (readstr $text $pos), $null))
    }
}

function parsevdf([string]$text) {
    $pos = 0; skipws $text ([ref]$pos)
    if ($pos -ge $text.Length -or $text[$pos] -ne '"') { throw 'missing root key' }
    $name = readstr $text ([ref]$pos); skipws $text ([ref]$pos)
    if ($pos -ge $text.Length -or $text[$pos] -ne '{') { throw 'missing root block' }
    $pos++
    $tree = [pscustomobject]@{ name = $name; node = parseobj $text ([ref]$pos) }
    skipws $text ([ref]$pos)
    if ($pos -lt $text.Length) { throw "unexpected trailing content at offset $pos" }
    $tree
}

function esc([string]$text) { $text.Replace('\', '\\').Replace('"', '\"') }

function writenode([vdfnode]$node, [int]$depth) {
    $lines = [System.Collections.Generic.List[string]]::new(); $pad = "`t" * $depth
    foreach ($entry in $node.entries) {
        $name = esc $entry.name
        if ($entry.kind -eq 'value') { $lines.Add($pad + '"' + $name + '"' + "`t`t" + '"' + (esc $entry.value) + '"'); continue }
        $lines.Add($pad + '"' + $name + '"'); $lines.Add($pad + '{')
        foreach ($line in writenode $entry.node ($depth + 1)) { $lines.Add($line) }
        $lines.Add($pad + '}')
    }
    $lines
}

function writevdf($tree) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('"' + (esc $tree.name) + '"'); $lines.Add('{')
    foreach ($line in writenode $tree.node 1) { $lines.Add($line) }
    $lines.Add('}')
    [string]::Join("`r`n", $lines) + "`r`n"
}

function findentry([vdfnode]$node, [string]$name) {
    for ($i = 0; $i -lt $node.entries.Count; $i++) { if ($node.entries[$i].name -ceq $name) { return $i } }
    -1
}

function ensureblock([vdfnode]$node, [string]$name) {
    $i = findentry $node $name
    if ($i -ge 0) {
        $entry = $node.entries[$i]
        if ($entry.kind -ne 'block') { throw "expected '$name' to be a block" }
        return $entry.node
    }
    $child = [vdfnode]::new()
    $node.entries.Add([vdfentry]::new('block', $name, $null, $child))
    $child
}

function setvalue([vdfnode]$node, [string]$name, [string]$value) {
    $i = findentry $node $name
    if ($i -ge 0) {
        $entry = $node.entries[$i]
        if ($entry.kind -ne 'value') { throw "expected '$name' to be a value" }
        $entry.value = $value
        return
    }
    $node.entries.Add([vdfentry]::new('value', $name, $value, $null))
}

function steamroot {
    $reg = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue
    if ($reg -and $reg.SteamPath) { return $reg.SteamPath }
    "${env:ProgramFiles(x86)}\Steam"
}

# Режим отката конфигурации из .bak
if ($Restore) {
    $proc = Get-Process steam* -ErrorAction SilentlyContinue
    if ($proc) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }
    if (-not $paths) {
        $paths = @(Get-ChildItem -Path (Join-Path (steamroot) 'userdata\*\config\localconfig.vdf.bak') -File -ErrorAction SilentlyContinue).FullName
    }
    if (-not $paths -or $paths.Count -eq 0) {
        if (-not $Quiet) {
            Write-Host " [!] Резервные копии localconfig.vdf.bak не найдены." -ForegroundColor DarkGray
        }
        return
    }
    foreach ($bak in $paths) {
        $target = $bak -replace '\.bak$', ''
        if (Test-Path -LiteralPath $bak) {
            Copy-Item -LiteralPath $bak -Destination $target -Force
            Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue
            if (-not $Quiet) {
                Write-Host " [+] Восстановлен оригинальный файл конфигурации: $target" -ForegroundColor Green
            }
        }
    }
    return
}

$settings = [ordered]@{
    Broadcast = [ordered]@{
        Permissions = '0'
        FirstTimeComplete = '1'
    }
    system = [ordered]@{
        displayratesasbits = '0'
        EnableGameOverlay = '0'
        InGameOverlayRestoreBrowserTabs = '0'
        InGameOverlayScreenshotNotification = '0'
        InGameOverlayScreenshotPlaySound = '0'
        NetworkingAllowShareIP = '1'
    }
    streaming_v2 = [ordered]@{
        EnableStreaming = '0'
    }
    friends = [ordered]@{
        SignIntoFriends = '0'
    }
    GameRecording = [ordered]@{
        BackgroundRecordMode = '0'
    }
    news = [ordered]@{
        NotifyAvailableGames = '0'
    }
    root = [ordered]@{
        LibraryLowBandwidthMode = '1'
        LibraryLowPerfMode = '1'
        LibraryDisableCommunityContent = '1'
        ReadyToPlayIncludesStreaming = '0'
        SteamController_Enable_Chord = '0'
        Controller_CheckGuideButton = '0'
        SteamController_PSSupport = '0'
    }
    Accessibility = [ordered]@{
        ReduceMotion = '1'
    }
}

$proc = Get-Process steam* -ErrorAction SilentlyContinue
if ($proc) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }

if (-not $paths) {
    $paths = @(Get-ChildItem -Path (Join-Path (steamroot) 'userdata\*\config\localconfig.vdf') -File -ErrorAction SilentlyContinue).FullName
}

if (-not $paths -or $paths.Count -eq 0) {
    if (-not $Quiet) {
        Write-Host " [!] Профили Steam не найдены в userdata (клиент еще не запускался под учетной записью)." -ForegroundColor DarkGray
    }
    return
}

foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $tree = parsevdf $text
    } else {
        $tree = [pscustomobject]@{ name = 'UserLocalConfigStore'; node = [vdfnode]::new() }
    }

    if ($tree.name -ne 'UserLocalConfigStore') { throw "unexpected root key '$($tree.name)' in $path" }

    $root = $tree.node
    foreach ($scope in $settings.Keys) {
        $node = if ($scope -eq 'root') { $root } else { ensureblock $root $scope }
        foreach ($name in $settings[$scope].Keys) { setvalue $node $name $settings[$scope][$name] }
    }

    if ((Test-Path -LiteralPath $path) -and -not (Test-Path -LiteralPath "$path.bak")) {
        if ($PSCmdlet.ShouldProcess("$path.bak", "Create backup copy of localconfig.vdf")) {
            [System.IO.File]::Copy($path, "$path.bak", $false)
        }
        if (-not $Quiet) {
            Write-Host " [+] Создана резервная копия: $path.bak" -ForegroundColor DarkGray
        }
    }
    $tmp = "$path.tmp"
    if ($PSCmdlet.ShouldProcess($path, "Write optimized configuration to localconfig.vdf")) {
        [System.IO.File]::WriteAllText($tmp, (writevdf $tree), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $path -Force
        if (-not $Quiet) {
            Write-Host " [+] Файл конфигурации успешно оптимизирован: $path" -ForegroundColor Green
        }
    }
}
