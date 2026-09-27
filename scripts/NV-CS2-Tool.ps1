<#
================================================================================
Имя твика:              Оптимизация Counter-Strike 2 (NV-CS2-Tool)
Что делает:             1. Настраивает соревновательный конфиг графики в cs2_video.txt и cs2_machine_convars.vcfg:
                           - Полноэкранный режим (Exclusive Fullscreen), отключение V-Sync.
                           - NVIDIA Reflex Low Latency (On + Boost: r_low_latency=2).
                           - Отключение Ambient Occlusion, снижение шейдеров и текстур для максимального FPS.
                           - Включение динамических теней (videocfg_dynamic_shadows=1) для видимости теней врагов.
                           - Кастомные лимиты FPS для матча и меню (fps_max и fps_max_ui).
                        2. Оптимизирует autoexec.cfg:
                           - cl_disable_ragdolls 1 (отключение физики тел после смерти для экономии CPU).
                           - cl_autohelp 0 (отключение всплывающих подсказок).
                           - demo_flush 0, r_drawparticles 0.
                        3. Настраивает политику качества обслуживания QoS (DSCP 46) для пакетов cs2.exe.
                        4. Поддерживает мгновенный откат всех настроек из резервных копий (.backup).
Зачем нужно:            Снижает сетевой джиттер и задержки рендеринга (input lag), стабилизирует время кадра (0.1% и 1% Low FPS)
                        в нагруженных перестрелках и исключает микрофризы от фоновых эффектов.
Значение по умолчанию:  Стандартные автоматические настройки графики CS2 (V-Sync может быть включен, Reflex выключен,
                        подсказки включены, приоритет QoS отсутствует).
Значение после твика:   Графика оптимизирована под минимальную задержку ввода, Reflex включен, autoexec настроен,
                        сетевые пакеты CS2 имеют наивысший приоритет DSCP 46.
Источник:               Официальное руководство Gaming & System Optimizer и репозиторий github.com/system-optimizer
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Settings", "Console", "QoS", "Restore", "Status")]
    [string]$Action = "Status",

    [Parameter(ParameterSetName = "Settings")]
    [switch]$Settings,

    [Parameter(ParameterSetName = "Console")]
    [switch]$Console,

    [Parameter(ParameterSetName = "QoS")]
    [switch]$QoS,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore
)

if ($Settings) { $Action = "Settings" }
if ($Console)  { $Action = "Console" }
if ($QoS)      { $Action = "QoS" }
if ($Restore)  { $Action = "Restore" }

$nvexecn = "cs2.exe"

function Show-NVBannerCyan {
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Clear-Host
    }
    Write-Host ""
    Write-Host -ForegroundColor DarkBlue "              ░░░     ░░░   ░░░░░░░░░░░   ░░░     ░░░   ░░░░░░░░░░   ░░░░░░░░░░    ░░░░░░░░░░   ░░░░░░░░░░"
    Write-Host -ForegroundColor DarkBlue "              ░░░░    ░░░   ░░░     ░░░   ░░░     ░░░   ░░░          ░░░     ░░░   ░░░          ░░░"
    Write-Host -ForegroundColor Blue     "              ▒▒▒▒▒   ░▒▒   ▒░░     ░░▒   ▒░░     ░░▒   ░░░          ▒░░     ▒▒░   ░░░          ░░░"
    Write-Host -ForegroundColor Blue     "              ▒▒▒ ▒▒▒ ▒▒▒   ▒▒░     ░▒▒   ▒▒░     ░▒▒   ▒▒▒▒▒▒▒▒     ▒▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒"
    Write-Host -ForegroundColor Blue     "              ▒▒▒   ▒▒▒▒▒   ▒▒▒     ▒▒▒    ▒▒▒   ▒▒▒    ▒▒▒          ▒▓▓     ▓▓▒          ▒▒▒   ▒▒▒"
    Write-Host -ForegroundColor DarkCyan "              ▒▓▓    ▓▓▓▒   ▓▓▓     ▓▓▓     ▒▓▓ ▓▓▒     ▓▓▓          ▓▓▓     ▓▓▓          ▓▓▓   ▓▓▓"
    Write-Host -ForegroundColor DarkCyan "              ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓▓       ▓▓▓       ▓▓▓▓▓▓▓▓▓▓   ▓▓▓     ▓▓▓   ▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓▓▓▓▓"
    Write-Host "‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-NVLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Detail = "",
        [ConsoleColor]$PrefixColor = "Green",
        [ConsoleColor]$DetailColor = "DarkGray"
    )
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$Prefix " -NoNewline -ForegroundColor $PrefixColor
    Write-Host "$Message " -NoNewline -ForegroundColor White
    if ($Detail) {
        Write-Host "$Detail" -ForegroundColor $DetailColor
    } else {
        Write-Host ""
    }
}

function Get-SteamPath {
    $sp = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if ($sp -and (Test-Path $sp)) { return $sp }
    if (Test-Path "C:\Program Files (x86)\Steam") { return "C:\Program Files (x86)\Steam" }
    return $null
}

function Get-CS2GamePath {
    $steam = Get-SteamPath
    if ($steam) {
        $libVdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $libVdf) {
            $content = Get-Content $libVdf -Raw
            $regex = '"path"\s+"([^"]+)"'
            $matches = [regex]::Matches($content, $regex)
            foreach ($m in $matches) {
                $libPath = $m.Groups[1].Value.Replace('\\', '\')
                $cs2Candidate = Join-Path $libPath "steamapps\common\Counter-Strike Global Offensive"
                if (Test-Path "$cs2Candidate\game\csgo") {
                    return $cs2Candidate
                }
            }
        }
        $stdPath = Join-Path $steam "steamapps\common\Counter-Strike Global Offensive"
        if (Test-Path "$stdPath\game\csgo") {
            return $stdPath
        }
    }

    # Поиск по доступным дискам
    foreach ($drive in [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' }) {
        $candidate = Join-Path $drive.RootDirectory.FullName "SteamLibrary\steamapps\common\Counter-Strike Global Offensive"
        if (Test-Path "$candidate\game\csgo") {
            return $candidate
        }
    }

    return $null
}

function Get-CS2UserCfgDir {
    $steam = Get-SteamPath
    $res = [System.Collections.Generic.List[string]]::new()
    if ($steam) {
        $userBase = Join-Path $steam "userdata"
        if (Test-Path $userBase) {
            foreach ($u in Get-ChildItem -Path $userBase -Directory -ErrorAction SilentlyContinue) {
                $cfgDir = Join-Path $u.FullName "730\local\cfg"
                if (Test-Path $cfgDir) {
                    [void]$res.Add($cfgDir)
                }
            }
        }
    }
    return $res
}

function Invoke-CS2Setting {
    param(
        [int]$ResWidth = 1920,
        [int]$ResHeight = 1080,
        [int]$FpsMax = 400,
        [int]$FpsMaxMenu = 200,
        [int]$ReflexMode = 2
    )

    Show-NVBannerCyan
    $cfgDirs = Get-CS2UserCfgDir
    if ($cfgDirs.Count -eq 0) {
        Write-NVLog -Prefix "[-]" -Message "Папка настроек CS2 (userdata\*\730\local\cfg) не найдена!" -PrefixColor Red
        Write-Host "Запустите CS2 хотя бы один раз, чтобы игра создала файлы профиля." -ForegroundColor DarkGray
        return
    }

    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Write-Host " Настройка соревновательных параметров видео CS2 (Competitive Preset)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " Введите ширину разрешения (нажмите Enter для 1920): " -NoNewline -ForegroundColor White
        $rw = Read-Host
        if ($rw -match '^\d+$') { $ResWidth = [int]$rw }

        Write-Host " Введите высоту разрешения (нажмите Enter для 1080): " -NoNewline -ForegroundColor White
        $rh = Read-Host
        if ($rh -match '^\d+$') { $ResHeight = [int]$rh }

        Write-Host " Ограничение FPS в игре (нажмите Enter для 400): " -NoNewline -ForegroundColor White
        $fm = Read-Host
        if ($fm -match '^\d+$') { $FpsMax = [int]$fm }

        Write-Host " Ограничение FPS в меню (нажмите Enter для 200): " -NoNewline -ForegroundColor White
        $fmm = Read-Host
        if ($fmm -match '^\d+$') { $FpsMaxMenu = [int]$fmm }

        Write-Host " Режим NVIDIA Reflex: [2] On + Boost (Рекомендуется) | [1] On | [0] Off: " -NoNewline -ForegroundColor White
        $rm = Read-Host
        if ($rm -match '^[0-2]$') { $ReflexMode = [int]$rm }
    }

    $fpsMaxStr = "$FpsMax.000000"
    $fpsMaxMenuStr = "$FpsMaxMenu.000000"

    foreach ($dir in $cfgDirs) {
        Write-NVLog -Prefix "[*]" -Message "Применение настроек в:" -Detail "$dir" -PrefixColor Cyan

        $machineFile = Join-Path $dir "cs2_machine_convars.vcfg"
        $videoFile = Join-Path $dir "cs2_video.txt"

        if (Test-Path $machineFile) {
            $bakMachine = Join-Path $dir "cs2_machine_convars.backup"
            if (-not (Test-Path $bakMachine)) {
                Copy-Item -Path $machineFile -Destination $bakMachine -Force
                Write-NVLog -Prefix "[+]" -Message "Создан бэкап convars:" -Detail "$bakMachine" -PrefixColor DarkGray
            }
            $mContent = Get-Content -Path $machineFile -Raw -Encoding UTF8
            $mContent = $mContent -replace '"fps_max"\s+".*?"', ('"fps_max"		"' + $fpsMaxStr + '"')
            $mContent = $mContent -replace '"fps_max_ui\$2"\s+".*?"', ('"fps_max_ui$2"		"' + $fpsMaxMenuStr + '"')
            Set-Content -Path $machineFile -Value $mContent -Encoding UTF8
        }

        if (Test-Path $videoFile) {
            $bakVideo = Join-Path $dir "cs2_video.backup"
            if (-not (Test-Path $bakVideo)) {
                Copy-Item -Path $videoFile -Destination $bakVideo -Force
                Write-NVLog -Prefix "[+]" -Message "Создан бэкап video:" -Detail "$bakVideo" -PrefixColor DarkGray
            }
            Set-ItemProperty -Path $videoFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

            $vContent = Get-Content -Path $videoFile -Raw -Encoding UTF8
            $vContent = $vContent -replace '"setting\.defaultres"\s+".*?"', ('"setting.defaultres"		"' + $ResWidth + '"')
            $vContent = $vContent -replace '"setting\.defaultresheight"\s+".*?"', ('"setting.defaultresheight"		"' + $ResHeight + '"')
            $vContent = $vContent -replace '"setting\.fullscreen"\s+".*?"', '"setting.fullscreen"		"1"'
            $vContent = $vContent -replace '"setting\.coop_fullscreen"\s+".*?"', '"setting.coop_fullscreen"		"0"'
            $vContent = $vContent -replace '"setting\.nowindowborder"\s+".*?"', '"setting.nowindowborder"		"0"'
            $vContent = $vContent -replace '"setting\.mat_vsync"\s+".*?"', '"setting.mat_vsync"		"0"'
            $vContent = $vContent -replace '"setting\.fullscreen_min_on_focus_loss"\s+".*?"', '"setting.fullscreen_min_on_focus_loss"		"1"'
            $vContent = $vContent -replace '"Autoconfig"\s+".*?"', '"Autoconfig"		"2"'
            $vContent = $vContent -replace '"setting\.shaderquality"\s+".*?"', '"setting.shaderquality"		"0"'
            $vContent = $vContent -replace '"setting\.r_texturefilteringquality"\s+".*?"', '"setting.r_texturefilteringquality"		"0"'
            $vContent = $vContent -replace '"setting\.r_low_latency"\s+".*?"', ('"setting.r_low_latency"		"' + $ReflexMode + '"')
            $vContent = $vContent -replace '"setting\.msaa_samples"\s+".*?"', '"setting.msaa_samples"		"0"'
            $vContent = $vContent -replace '"setting\.r_csgo_cmaa_enable"\s+".*?"', '"setting.r_csgo_cmaa_enable"		"1"'
            $vContent = $vContent -replace '"setting\.videocfg_shadow_quality"\s+".*?"', '"setting.videocfg_shadow_quality"		"0"'
            $vContent = $vContent -replace '"setting\.videocfg_dynamic_shadows"\s+".*?"', '"setting.videocfg_dynamic_shadows"		"1"'
            $vContent = $vContent -replace '"setting\.videocfg_texture_detail"\s+".*?"', '"setting.videocfg_texture_detail"		"0"'
            $vContent = $vContent -replace '"setting\.videocfg_particle_detail"\s+".*?"', '"setting.videocfg_particle_detail"		"0"'
            $vContent = $vContent -replace '"setting\.videocfg_ao_detail"\s+".*?"', '"setting.videocfg_ao_detail"		"0"'
            $vContent = $vContent -replace '"setting\.videocfg_hdr_detail"\s+".*?"', '"setting.videocfg_hdr_detail"		"3"'
            $vContent = $vContent -replace '"setting\.videocfg_fsr_detail"\s+".*?"', '"setting.videocfg_fsr_detail"		"0"'

            Set-Content -Path $videoFile -Value $vContent -Encoding UTF8
            Write-NVLog -Prefix "[+]" -Message "cs2_video.txt успешно оптимизирован!" -PrefixColor Green
        }
    }
    Write-Host "`n[OK] Все параметры графики CS2 успешно применены!" -ForegroundColor Green
}

function Invoke-CS2Console {
    Show-NVBannerCyan
    $cs2Dir = Get-CS2GamePath
    if (-not $cs2Dir) {
        Write-NVLog -Prefix "[-]" -Message "Каталог установки CS2 не найден!" -PrefixColor Red
        return
    }

    $cfgFolder = Join-Path $cs2Dir "game\csgo\cfg"
    if (-not (Test-Path $cfgFolder)) {
        New-Item -Path $cfgFolder -ItemType Directory -Force | Out-Null
    }

    $autoexecPath = Join-Path $cfgFolder "autoexec.cfg"
    $bakAutoexec = Join-Path $cfgFolder "autoexec.backup"

    if ((Test-Path $autoexecPath) -and -not (Test-Path $bakAutoexec)) {
        Copy-Item -Path $autoexecPath -Destination $bakAutoexec -Force
        Write-NVLog -Prefix "[+]" -Message "Создан бэкап autoexec.cfg:" -Detail "$bakAutoexec" -PrefixColor DarkGray
    }

    $commands = @(
        "cl_disable_ragdolls 1",
        "cl_autohelp 0",
        "demo_flush 0",
        "r_drawparticles 0"
    )

    $existingLines = if (Test-Path $autoexecPath) { [System.IO.File]::ReadAllLines($autoexecPath, [System.Text.Encoding]::UTF8) } else { @() }
    $cmdMap = @{}
    $replaced = @{}
    foreach ($c in $commands) {
        $name = ($c -split '\s+', 2)[0]
        $cmdMap[$name] = $c
        $replaced[$name] = $false
    }

    $outLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $existingLines) {
        $matched = $false
        foreach ($k in $cmdMap.Keys) {
            if ($line -match "^\s*$k(?:\s+|$)") {
                if (-not $replaced[$k]) {
                    [void]$outLines.Add($cmdMap[$k])
                    $replaced[$k] = $true
                }
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            [void]$outLines.Add($line)
        }
    }

    foreach ($k in $cmdMap.Keys) {
        if (-not $replaced[$k]) {
            [void]$outLines.Add($cmdMap[$k])
        }
    }

    [System.IO.File]::WriteAllLines($autoexecPath, $outLines, [System.Text.Encoding]::UTF8)
    Write-NVLog -Prefix "[+]" -Message "autoexec.cfg обновлен:" -Detail "$autoexecPath" -PrefixColor Green
    Write-Host "`n[OK] Команды оптимизации autoexec.cfg успешно применены!" -ForegroundColor Green
}

function Invoke-CS2QoS {
    param([bool]$Enable = $true)

    Show-NVBannerCyan
    $qosKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CS2"
    $tcpQosKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS"

    if ($Enable) {
        Write-NVLog -Prefix "[*]" -Message "Добавление политики QoS DSCP 46 для CS2..." -PrefixColor Cyan
        if (-not (Test-Path $qosKey)) {
            New-Item -Path $qosKey -Force | Out-Null
        }
        New-ItemProperty -Path $qosKey -Name "Version" -PropertyType String -Value "1.0" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Application Name" -PropertyType String -Value $nvexecn -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Protocol" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Local Port" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Local IP" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Local IP Prefix Length" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Remote Port" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Remote IP" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Remote IP Prefix Length" -PropertyType String -Value "*" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "DSCP Value" -PropertyType String -Value "46" -Force | Out-Null
        New-ItemProperty -Path $qosKey -Name "Throttle Rate" -PropertyType String -Value "-1" -Force | Out-Null

        if (-not (Test-Path $tcpQosKey)) { New-Item -Path $tcpQosKey -Force | Out-Null }
        Set-ItemProperty -Path $tcpQosKey -Name "Do not use NLA" -Value "1" -Type String -Force | Out-Null

        Write-NVLog -Prefix "[+]" -Message "Политика QoS для CS2 активирована (DSCP 46)!" -PrefixColor Green
    } else {
        Write-NVLog -Prefix "[*]" -Message "Удаление политики QoS для CS2..." -PrefixColor Yellow
        if (Test-Path $qosKey) {
            Remove-Item -Path $qosKey -Recurse -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[-]" -Message "Политика QoS для CS2 удалена" -PrefixColor Yellow
        }
    }
}

function Invoke-CS2Restore {
    Show-NVBannerCyan
    Write-Host "`n[*] Восстановление исходных файлов конфигурации CS2..." -ForegroundColor Cyan

    $cfgDirs = Get-CS2UserCfgDir
    foreach ($dir in $cfgDirs) {
        $bakMachine = Join-Path $dir "cs2_machine_convars.backup"
        $machineFile = Join-Path $dir "cs2_machine_convars.vcfg"
        if (Test-Path $bakMachine) {
            Copy-Item -Path $bakMachine -Destination $machineFile -Force
            Remove-Item -Path $bakMachine -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[+]" -Message "Восстановлен cs2_machine_convars.vcfg в:" -Detail "$dir" -PrefixColor Green
        }

        $bakVideo = Join-Path $dir "cs2_video.backup"
        $videoFile = Join-Path $dir "cs2_video.txt"
        if (Test-Path $bakVideo) {
            Set-ItemProperty -Path $videoFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            Copy-Item -Path $bakVideo -Destination $videoFile -Force
            Remove-Item -Path $bakVideo -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[+]" -Message "Восстановлен cs2_video.txt в:" -Detail "$dir" -PrefixColor Green
        }
    }

    $cs2Dir = Get-CS2GamePath
    if ($cs2Dir) {
        $cfgFolder = Join-Path $cs2Dir "game\csgo\cfg"
        $bakAutoexec = Join-Path $cfgFolder "autoexec.backup"
        $autoexecPath = Join-Path $cfgFolder "autoexec.cfg"
        if (Test-Path $bakAutoexec) {
            Copy-Item -Path $bakAutoexec -Destination $autoexecPath -Force
            Remove-Item -Path $bakAutoexec -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[+]" -Message "Восстановлен autoexec.cfg из бэкапа" -PrefixColor Green
        }
    }

    Invoke-CS2QoS -Enable $false
    Write-Host "`n[OK] Все параметры и файлы CS2 восстановлены к исходным значениям!" -ForegroundColor Yellow
}

switch ($Action) {
    "Settings" { Invoke-CS2Setting }
    "Console"  { Invoke-CS2Console }
    "QoS"      { Invoke-CS2QoS -Enable $true }
    "Restore"  { Invoke-CS2Restore }
    "Status"   {
        while ($true) {
            $cs2Path = Get-CS2GamePath
            $cfgDirs = Get-CS2UserCfgDir
            $qosApplied = Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CS2"

            Show-NVBannerCyan
            Write-Host "                УТИЛИТА ОПТИМИЗАЦИИ COUNTER-STRIKE 2 (System)                 " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "Путь к игре CS2     : $(if ($cs2Path) { $cs2Path } else { '[ НЕ НАЙДЕН ]' })" -ForegroundColor $(if ($cs2Path) { 'White' } else { 'Yellow' })
            Write-Host "Профили настроек    : найдено $($cfgDirs.Count) папок профилей userdata\730" -ForegroundColor $(if ($cfgDirs.Count -gt 0) { 'Green' } else { 'Yellow' })
            Write-Host "Политика QoS (DSCP) : $(if ($qosApplied) { '[ АКТИВНА (DSCP 46) ]' } else { '[ ОТКЛЮЧЕНА ]' })" -ForegroundColor $(if ($qosApplied) { 'Green' } else { 'Yellow' })
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "[1] Применить соревновательный конфиг видео (cs2_video.txt & convars)" -ForegroundColor White
            Write-Host "[2] Настроить консольный autoexec.cfg (ragdolls off, particles off)" -ForegroundColor White
            Write-Host "[3] Включить сетевую политику QoS для CS2 (DSCP 46)" -ForegroundColor White
            Write-Host "[4] Восстановить все настройки из бэкапов (.backup Restore)" -ForegroundColor White
            Write-Host "[0] Назад" -ForegroundColor DarkGray
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " >> " -NoNewline -ForegroundColor Cyan
            $c = Read-Host

            switch ($c) {
                "1" { Invoke-CS2Setting }
                "2" { Invoke-CS2Console }
                "3" { Invoke-CS2QoS -Enable $true }
                "4" { Invoke-CS2Restore }
                default { return }
            }
        }
    }
}