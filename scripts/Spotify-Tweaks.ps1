<#
================================================================================
Имя твика:              Оптимизация клиента Spotify Desktop (Spotify-Tweaks)
Что делает:             1. Настраивает глобальные параметры приложения в %APPDATA%\Spotify\prefs:
                           - Отключает аппаратное ускорение UI (ui.hardware_acceleration=false)
                           - Отключает автозапуск при входе в систему (app.autostart-mode="off")
                           - Отключает автопоиск прокси (network.proxy.mode=1 - No proxy)
                        2. Настраивает параметры профиля пользователя в %APPDATA%\Spotify\Users\*\prefs:
                           - Отключает нормализацию громкости (audio.normalize_v2=false) для чистого динамического диапазона
                           - Отключает оверлей мультимедийных клавиш Windows (ui.system_media_controls_enabled=false)
                           - Скрывает панель активности друзей (ui.right_panel_content=0)
                           - Отключает показ промо-анонсов релизов (ui.hide_hpto=true)
                           - Отключает сворачивание в трей при закрытии (ui.minimize_to_tray=false)
                           - Включает плавный переход Automix (audio.automix=true)
Зачем нужно:            Снижает потребление ОЗУ и CPU, исключает задержки ввода от фонового рендеринга CEF/Chromium,
                        устраняет оверлей громкости SMTC, конфликтующий с полноэкранными играми, и восстанавливает
                        оригинальный динамический диапазон аудио без компрессии.
Значение по умолчанию:  Аппаратное ускорение включено; автозапуск в свернутом виде ("on"); оверлей мультимедиа включен;
                        нормализация громкости включена; панель друзей отображается.
Значение после твика:   Аппаратное ускорение выключено; автозапуск "off"; оверлей выключен; нормализация выключена;
                        панель друзей скрыта; промо-баннеры отключены.
Источник / Категория:   Gaming & System Optimizer: Audio & Media Players Tuning
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Apply", "Restore", "Status")]
    [string]$Action,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

if ($Apply)   { $Action = "Apply" }
if ($Restore) { $Action = "Restore" }

$spotifyDir = Join-Path $env:APPDATA "Spotify"
$globalPrefsPath = Join-Path $spotifyDir "prefs"
$usersDir = Join-Path $spotifyDir "Users"

$globalDefaults = @{
    'app.autostart-configured' = 'false'
    'app.autostart-mode'       = '"on"'
    'network.proxy.mode'       = '0'
    'ui.hardware_acceleration' = 'true'
}

$userDefaults = @{
    'audio.normalize_v2'               = 'true'
    'ui.hide_hpto'                     = 'false'
    'ui.system_media_controls_enabled' = 'true'
    'ui.right_panel_content'           = '1'
    'audio.crossfade_v2'               = 'false'
    'audio.automix'                    = 'true'
    'audio.downmixer_v2'               = 'false'
    'audio.silence_trimmer_v2'         = 'false'
    'ui.minimize_to_tray'              = 'false'
}

$globalTweaks = @{
    'app.autostart-configured' = 'true'
    'app.autostart-mode'       = '"off"'
    'network.proxy.mode'       = '1'
    'ui.hardware_acceleration' = 'false'
}

$userTweaks = @{
    'audio.play_bitrate_non_metered_enumeration' = '0'
    'audio.play_bitrate_enumeration'             = '0'
    'audio.sync_bitrate_enumeration'             = '0'
    'audio.allow_downgrade'                      = 'true'
    'audio.normalize_v2'                         = 'false'
    'ui.hide_hpto'                               = 'true'
    'ui.system_media_controls_enabled'           = 'false'
    'ui.right_panel_content'                     = '0'
    'audio.crossfade_v2'                         = 'false'
    'audio.automix'                              = 'true'
    'audio.downmixer_v2'                         = 'false'
    'audio.silence_trimmer_v2'                   = 'false'
    'ui.minimize_to_tray'                        = 'false'
}

# ------------------------------------------------------------------------------
# 1. Проверка наличия приложения в системе
# ------------------------------------------------------------------------------
function Test-SpotifyInstalled {
    $hasDir = (Test-Path -LiteralPath $spotifyDir) -or `
              (Test-Path -LiteralPath "${env:ProgramFiles}\Spotify") -or `
              (Test-Path -LiteralPath "${env:ProgramFiles(x86)}\Spotify") -or `
              (Test-Path -LiteralPath "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe")
    return $hasDir
}

if (-not (Test-SpotifyInstalled)) {
    if (-not $Quiet) {
        Write-Host "[-] Spotify не обнаружен в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

# По умолчанию в неинтерактивном режиме с пустым Action применяем Apply
if ([string]::IsNullOrEmpty($Action)) {
    $Action = "Apply"
}

function Stop-Spotify {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $proc = Get-Process spotify* -ErrorAction SilentlyContinue
    if ($proc) {
        if ($PSCmdlet.ShouldProcess("Spotify", "Stop active processes")) {
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host " [*] Завершены активные процессы Spotify" -ForegroundColor DarkGray
        }
        Start-Sleep -Milliseconds 500
    }
}

function Update-SpotifyPrefItem {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [hashtable]$Prefs
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        if ($PSCmdlet.ShouldProcess($parent, "Create directory")) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
    }

    # Создание резервной копии перед первой модификацией (гарантия идемпотентности)
    $bakPath = "$Path.bak"
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath $bakPath)) {
        if ($PSCmdlet.ShouldProcess($bakPath, "Create backup of prefs")) {
            Copy-Item -LiteralPath $Path -Destination $bakPath -Force
        }
        if (-not $Quiet) {
            Write-Host "    [+] Создана резервная копия: $bakPath" -ForegroundColor DarkGray
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                [void]$lines.Add($line)
            }
        }
    }

    foreach ($key in $Prefs.Keys) {
        $entry = "$key=$($Prefs[$key])"
        $index = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -like "$key=*") {
                $index = $i
                break
            }
        }
        if ($index -ge 0) {
            $lines[$index] = $entry
        } else {
            [void]$lines.Add($entry)
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, "Write updated preferences")) {
        [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
    }
}

function Restore-SpotifyPrefsFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [hashtable]$Defaults
    )

    $bakPath = "$Path.bak"
    if (Test-Path -LiteralPath $bakPath) {
        if ($PSCmdlet.ShouldProcess($Path, "Restore preferences from backup")) {
            Copy-Item -LiteralPath $bakPath -Destination $Path -Force
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        }
        if (-not $Quiet) {
            Write-Host "    [+] Восстановлен оригинальный файл из: $bakPath" -ForegroundColor Green
        }
        return
    }

    if (Test-Path -LiteralPath $Path) {
        Update-SpotifyPrefItem -Path $Path -Prefs $Defaults
        if (-not $Quiet) {
            Write-Host "    [*] Значения в $Path сброшены к стандартным значениям Spotify" -ForegroundColor Yellow
        }
    }
}

function Get-SpotifyStatus {
    $status = @{
        Installed             = (Test-Path -LiteralPath $spotifyDir)
        GlobalConfigured      = $false
        HardwareAccelOff      = $false
        AutostartOff          = $false
        UserCount             = 0
        UserOptimizedCount    = 0
    }

    if (Test-Path -LiteralPath $globalPrefsPath) {
        $content = [System.IO.File]::ReadAllText($globalPrefsPath)
        if ($content -match 'ui\.hardware_acceleration=false') { $status.HardwareAccelOff = $true }
        if ($content -match 'app\.autostart-mode="off"') { $status.AutostartOff = $true }
        if ($status.HardwareAccelOff -and $status.AutostartOff) { $status.GlobalConfigured = $true }
    }

    if (Test-Path -LiteralPath $usersDir) {
        $userDirs = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue
        $status.UserCount = ($userDirs | Measure-Object).Count
        foreach ($u in $userDirs) {
            $uPrefs = Join-Path $u.FullName "prefs"
            if (Test-Path -LiteralPath $uPrefs) {
                $uContent = [System.IO.File]::ReadAllText($uPrefs)
                if ($uContent -match 'ui\.system_media_controls_enabled=false') {
                    $status.UserOptimizedCount++
                }
            }
        }
    }

    return $status
}

switch ($Action) {
    "Apply" {
        Stop-Spotify

        if (-not (Test-Path -LiteralPath $spotifyDir)) {
            if ($PSCmdlet.ShouldProcess($spotifyDir, "Create Spotify AppData directory")) {
                New-Item -Path $spotifyDir -ItemType Directory -Force | Out-Null
            }
        }

        if (-not $Quiet) {
            Write-Host "`n[*] Применение оптимизаций Spotify (Gaming & System Optimizer)..." -ForegroundColor Cyan
        }
        Update-SpotifyPrefItem -Path $globalPrefsPath -Prefs $globalTweaks
        if (-not $Quiet) {
            Write-Host "[+] Глобальные настройки ($globalPrefsPath) успешно оптимизированы!" -ForegroundColor Green
        }

        $userDirs = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue
        if ($userDirs) {
            foreach ($u in $userDirs) {
                $uPrefs = Join-Path $u.FullName "prefs"
                Update-SpotifyPrefItem -Path $uPrefs -Prefs $userTweaks
                if (-not $Quiet) {
                    Write-Host "[+] Профиль пользователя ($($u.Name)) успешно оптимизирован!" -ForegroundColor Green
                }
            }
        } else {
            if (-not $Quiet) {
                Write-Host " [i] Папка профилей пользователей не найдена (профиль будет сконфигурирован при первом логине)." -ForegroundColor DarkGray
            }
        }

        if (-not $Quiet) {
            Write-Host "`n[OK] Все твики Spotify успешно применены!" -ForegroundColor Green
        }
    }

    "Restore" {
        Stop-Spotify

        if (-not $Quiet) {
            Write-Host "`n[*] Восстановление исходных настроек Spotify..." -ForegroundColor Cyan
        }
        Restore-SpotifyPrefsFile -Path $globalPrefsPath -Defaults $globalDefaults

        $userDirs = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue
        if ($userDirs) {
            foreach ($u in $userDirs) {
                $uPrefs = Join-Path $u.FullName "prefs"
                Restore-SpotifyPrefsFile -Path $uPrefs -Defaults $userDefaults
            }
        }

        if (-not $Quiet) {
            Write-Host "`n[OK] Настройки Spotify успешно сброшены в исходное состояние!" -ForegroundColor Yellow
        }
    }

    "Status" {
        while ($true) {
            $st = Get-SpotifyStatus

            Write-Host "`n==============================================================================" -ForegroundColor DarkCyan
            Write-Host "             ОПТИМИЗАЦИЯ SPOTIFY DESKTOP (Gaming & System Optimizer)          " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "Каталог Spotify      : $spotifyDir" -ForegroundColor DarkGray
            Write-Host "Статус установки     : $(if ($st.Installed) { '[ ОБНАРУЖЕН ]' } else { '[ НЕ УСТАНОВЛЕН ]' })" -ForegroundColor $(if ($st.Installed) { 'Green' } else { 'Yellow' })
            Write-Host "Аппаратное ускорение : $(if ($st.HardwareAccelOff) { '[ ВЫКЛЮЧЕНО (Оптимизировано) ]' } else { '[ ВКЛЮЧЕНО (По умолчанию) ]' })" -ForegroundColor $(if ($st.HardwareAccelOff) { 'Green' } else { 'Yellow' })
            Write-Host "Автозапуск системы   : $(if ($st.AutostartOff) { '[ ВЫКЛЮЧЕН (Оптимизировано) ]' } else { '[ ВКЛЮЧЕН ]' })" -ForegroundColor $(if ($st.AutostartOff) { 'Green' } else { 'Yellow' })
            Write-Host "Профили пользователей: $($st.UserOptimizedCount) из $($st.UserCount) оптимизированы" -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "[1] Применить оптимизированную конфигурацию (Hardware Accel Off, Overlay Off)" -ForegroundColor White
            Write-Host "[2] Сбросить настройки к значениям по умолчанию / из бэкапа (.bak)" -ForegroundColor White
            Write-Host "[Q] Назад" -ForegroundColor DarkGray
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " >> " -NoNewline -ForegroundColor Cyan
            $c = Read-Host

            switch ($c) {
                "1" { & $MyInvocation.MyCommand.Path -Action Apply }
                "2" { & $MyInvocation.MyCommand.Path -Action Restore }
                default { return }
            }
        }
    }
}
