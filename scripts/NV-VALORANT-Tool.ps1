<#
================================================================================
Имя твика:              Оптимизация VALORANT (NV-VALORANT-Tool)
Что делает:             1. Настраивает GameUserSettings.ini:
                           - Принудительный полноэкранный режим (PreferredFullscreenMode=0).
                           - Отключение вертикальной синхронизации (bUseVSync=False).
                           - Отключение динамического разрешения (bUseDynamicResolution=False).
                           - Кастомное соревновательное разрешение и лимит FPS.
                        2. Настраивает RiotUserSettings.ini:
                           - Включение NVIDIA Reflex Low Latency (On + Boost: NvidiaReflexLowLatencySetting=2).
                           - Отключение теней, виньетирования, искажений и эффектов (ShadowsEnabled=False, BloomQuality=0).
                           - Включение пространственного звука HRTF (EnableHRTF=True).
                           - Включение аппаратных графиков FPS, задержки RTT и потери пакетов.
                           - Отключение отображения крови и тел для максимальной стабильности 0.1% Low FPS.
                        3. Настраивает сетевую политику QoS (DSCP 46) для процесса VALORANT-Win64-Shipping.exe.
                        4. Поддерживает мгновенный откат всех настроек из резервных копий (.backup).
Зачем нужно:            Снижает сетевой джиттер и задержки пакетов в матчах, минимизирует инпутлаг рендеринга Unreal Engine 4,
                        устраняет просадки FPS в дымах и при использовании ультимейтов.
Значение по умолчанию:  Стандартные пресеты качества графики Riot Games, вертикальная синхронизация может быть включена,
                        динамическое разрешение активно, сетевой приоритет QoS отсутствует.
Значение после твика:   Графика настроена на соревновательную производительность, Reflex On+Boost, сетевые пакеты DSCP 46.
Источник:               Официальный репозиторий Optimizer / System (github.com/system-optimizer
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Settings", "QoS", "Restore", "Status")]
    [string]$Action = "Status",

    [Parameter(ParameterSetName = "Settings")]
    [switch]$Settings,

    [Parameter(ParameterSetName = "QoS")]
    [switch]$QoS,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore
)

if ($Settings) { $Action = "Settings" }
if ($QoS)      { $Action = "QoS" }
if ($Restore)  { $Action = "Restore" }

$nvexecn = "VALORANT-Win64-Shipping.exe"

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

function Get-ValorantConfigDir {
    $localVal = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
    $res = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $localVal) {
        $clients = Get-ChildItem -Path $localVal -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "WindowsClient" -and (Test-Path (Join-Path $_.FullName "GameUserSettings.ini")) }
        foreach ($c in $clients) {
            [void]$res.Add($c.FullName)
        }
    }
    return $res
}

function Invoke-ValorantSetting {
    param(
        [int]$ResWidth = 1920,
        [int]$ResHeight = 1080,
        [int]$FpsLimit = 0,
        [int]$EnemyColor = 0,
        [int]$ReflexMode = 2
    )

    Show-NVBannerCyan
    $configDirs = Get-ValorantConfigDir
    if ($configDirs.Count -eq 0) {
        Write-NVLog -Prefix "[-]" -Message "Папка настроек VALORANT не найдена в %LOCALAPPDATA%\VALORANT!" -PrefixColor Red
        Write-Host "Запустите VALORANT хотя бы один раз для генерации файлов профиля." -ForegroundColor DarkGray
        return
    }

    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Write-Host " Настройка соревновательных параметров видео VALORANT (Competitive Preset)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " Введите ширину разрешения (нажмите Enter для 1920): " -NoNewline -ForegroundColor White
        $rw = Read-Host
        if ($rw -match '^\d+$') { $ResWidth = [int]$rw }

        Write-Host " Введите высоту разрешения (нажмите Enter для 1080): " -NoNewline -ForegroundColor White
        $rh = Read-Host
        if ($rh -match '^\d+$') { $ResHeight = [int]$rh }

        Write-Host " Ограничение FPS (0 = без ограничений, или введите значение, например 240): " -NoNewline -ForegroundColor White
        $fl = Read-Host
        if ($fl -match '^\d+$') { $FpsLimit = [int]$fl }

        Write-Host " Цвет подсветки врагов: [0] Красный (Дефолт) | [1] Фиолетовый | [2] Желтый: " -NoNewline -ForegroundColor White
        $ec = Read-Host
        if ($ec -match '^[0-3]$') { $EnemyColor = [int]$ec }

        Write-Host " Режим NVIDIA Reflex: [2] On + Boost (Рекомендуется) | [1] On | [0] Off: " -NoNewline -ForegroundColor White
        $rm = Read-Host
        if ($rm -match '^[0-2]$') { $ReflexMode = [int]$rm }
    }

    $fpsChoice = if ($FpsLimit -gt 0) { "True" } else { "False" }

    foreach ($dir in $configDirs) {
        Write-NVLog -Prefix "[*]" -Message "Применение настроек в:" -Detail "$dir" -PrefixColor Cyan

        $gameUserIni = Join-Path $dir "GameUserSettings.ini"
        $riotUserIni = Join-Path $dir "RiotUserSettings.ini"

        # 1. Модификация GameUserSettings.ini
        if (Test-Path $gameUserIni) {
            $bakGame = Join-Path $dir "GameUserSettings.backup"
            if (-not (Test-Path $bakGame)) {
                Copy-Item -Path $gameUserIni -Destination $bakGame -Force
                Write-NVLog -Prefix "[+]" -Message "Создан бэкап GameUserSettings:" -Detail "$bakGame" -PrefixColor DarkGray
            }
            Set-ItemProperty -Path $gameUserIni -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

            $gameSettings = @{
                "bShouldLetterbox" = "True"
                "bLastConfirmedShouldLetterbox" = "True"
                "bUseVSync" = "False"
                "bUseDynamicResolution" = "False"
                "ResolutionSizeX" = "$ResWidth"
                "ResolutionSizeY" = "$ResHeight"
                "LastUserConfirmedResolutionSizeX" = "$ResWidth"
                "LastUserConfirmedResolutionSizeY" = "$ResHeight"
                "WindowPosX" = "0"
                "WindowPosY" = "0"
                "LastConfirmedFullscreenMode" = "0"
                "PreferredFullscreenMode" = "0"
                "AudioQualityLevel" = "0"
                "LastConfirmedAudioQualityLevel" = "0"
                "FrameRateLimit" = "$FpsLimit"
                "DesiredScreenWidth" = "$ResWidth"
                "DesiredScreenHeight" = "$ResHeight"
                "LastUserConfirmedDesiredScreenWidth" = "$ResWidth"
                "LastUserConfirmedDesiredScreenHeight" = "$ResHeight"
                "bUseDesiredScreenHeight" = "False"
            }

            $lines = [System.IO.File]::ReadAllLines($gameUserIni, [System.Text.Encoding]::UTF8)
            $outLines = [System.Collections.Generic.List[string]]::new()
            $handledKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

            foreach ($line in $lines) {
                if ($line -match "^\s*([^=]+)=(.*)$") {
                    $k = $Matches[1].Trim()
                    if ($gameSettings.ContainsKey($k)) {
                        [void]$outLines.Add("$k=$($gameSettings[$k])")
                        [void]$handledKeys.Add($k)
                    } else {
                        [void]$outLines.Add($line)
                    }
                } else {
                    [void]$outLines.Add($line)
                }
            }

            foreach ($k in $gameSettings.Keys) {
                if (-not $handledKeys.Contains($k)) {
                    [void]$outLines.Add("$k=$($gameSettings[$k])")
                }
            }

            [System.IO.File]::WriteAllLines($gameUserIni, $outLines, [System.Text.Encoding]::UTF8)
            Write-NVLog -Prefix "[+]" -Message "GameUserSettings.ini успешно оптимизирован!" -PrefixColor Green
        }

        # 2. Модификация RiotUserSettings.ini
        if (Test-Path $riotUserIni) {
            $bakRiot = Join-Path $dir "RiotUserSettings.backup"
            if (-not (Test-Path $bakRiot)) {
                Copy-Item -Path $riotUserIni -Destination $bakRiot -Force
                Write-NVLog -Prefix "[+]" -Message "Создан бэкап RiotUserSettings:" -Detail "$bakRiot" -PrefixColor DarkGray
            }
            Set-ItemProperty -Path $riotUserIni -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

            $riotSettings = @{
                "EAresIntSettingName::PlayerPerfShowFrameRate" = "1"
                "EAresIntSettingName::PlayerPerfShowNetworkRtt" = "1"
                "EAresIntSettingName::PlayerPerfShowPacketLossPercentage" = "1"
                "EAresBoolSettingName::EnableHRTF" = "True"
                "EAresBoolSettingName::AlwaysShowInventoryWidgets" = "True"
                "EAresBoolSettingName::EnableInstabilityIndicators" = "False"
                "EAresBoolSettingName::LimitFramerateOnBattery" = "$fpsChoice"
                "EAresBoolSettingName::ShowBlood" = "False"
                "EAresBoolSettingName::ShowCorpses" = "False"
                "EAresBoolSettingName::SpectatorCountWidgetVisible" = "False"
                "EAresBoolSettingName::AutoEquipSkipsMelee" = "True"
                "EAresBoolSettingName::ShowKeybindsOnMinimap" = "False"
                "EAresIntSettingName::NvidiaReflexLowLatencySetting" = "$ReflexMode"
                "EAresIntSettingName::MaterialQuality" = "0"
                "EAresIntSettingName::TextureQuality" = "0"
                "EAresIntSettingName::DetailQuality" = "0"
                "EAresIntSettingName::UIQuality" = "0"
                "EAresBoolSettingName::VignetteEnabled" = "False"
                "EAresIntSettingName::AntiAliasing" = "1"
                "EAresBoolSettingName::ShadowsEnabled" = "False"
                "EAresBoolSettingName::DisableDistortion" = "True"
                "EAresIntSettingName::AnisotropicFiltering" = "2"
                "EAresIntSettingName::BloomQuality" = "0"
                "EAresBoolSettingName::LimitFramerateInMenu" = "$fpsChoice"
                "EAresBoolSettingName::LimitFramerateInBackground" = "$fpsChoice"
                "EAresBoolSettingName::LimitFramerateAlways" = "$fpsChoice"
                "EAresBoolSettingName::ShowBulletTracers" = "False"
                "EAresFloatSettingName::MaxFramerateOnBattery" = "$FpsLimit"
                "EAresFloatSettingName::MaxFramerateInMenu" = "$FpsLimit"
                "EAresFloatSettingName::MaxFramerateInBackground" = "$FpsLimit"
                "EAresFloatSettingName::MaxFramerateAlways" = "$FpsLimit"
                "EAresIntSettingName::ColorBlindMode" = "$EnemyColor"
            }

            $rLines = [System.IO.File]::ReadAllLines($riotUserIni, [System.Text.Encoding]::UTF8)
            $rOutLines = [System.Collections.Generic.List[string]]::new()
            $rHandled = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

            foreach ($line in $rLines) {
                if ($line -match "^\s*([^=]+)=(.*)$") {
                    $k = $Matches[1].Trim()
                    if ($riotSettings.ContainsKey($k)) {
                        [void]$rOutLines.Add("$k=$($riotSettings[$k])")
                        [void]$rHandled.Add($k)
                    } else {
                        [void]$rOutLines.Add($line)
                    }
                } else {
                    [void]$rOutLines.Add($line)
                }
            }

            foreach ($k in $riotSettings.Keys) {
                if (-not $rHandled.Contains($k)) {
                    [void]$rOutLines.Add("$k=$($riotSettings[$k])")
                }
            }

            [System.IO.File]::WriteAllLines($riotUserIni, $rOutLines, [System.Text.Encoding]::UTF8)
            Write-NVLog -Prefix "[+]" -Message "RiotUserSettings.ini успешно оптимизирован!" -PrefixColor Green
        }
    }
    Write-Host "`n[OK] Все параметры графики VALORANT успешно применены!" -ForegroundColor Green
}

function Invoke-ValorantQoS {
    param([bool]$Enable = $true)

    Show-NVBannerCyan
    $qosKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\VALORANT"
    $tcpQosKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS"

    if ($Enable) {
        Write-NVLog -Prefix "[*]" -Message "Добавление политики QoS DSCP 46 для VALORANT..." -PrefixColor Cyan
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

        Write-NVLog -Prefix "[+]" -Message "Политика QoS для VALORANT активирована (DSCP 46)!" -PrefixColor Green
    } else {
        Write-NVLog -Prefix "[*]" -Message "Удаление политики QoS для VALORANT..." -PrefixColor Yellow
        if (Test-Path $qosKey) {
            Remove-Item -Path $qosKey -Recurse -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[-]" -Message "Политика QoS для VALORANT удалена" -PrefixColor Yellow
        }
    }
}

function Invoke-ValorantRestore {
    Show-NVBannerCyan
    Write-Host "`n[*] Восстановление исходных файлов конфигурации VALORANT..." -ForegroundColor Cyan

    $configDirs = Get-ValorantConfigDir
    foreach ($dir in $configDirs) {
        $bakGame = Join-Path $dir "GameUserSettings.backup"
        $gameUserIni = Join-Path $dir "GameUserSettings.ini"
        if (Test-Path $bakGame) {
            Set-ItemProperty -Path $gameUserIni -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            Copy-Item -Path $bakGame -Destination $gameUserIni -Force
            Remove-Item -Path $bakGame -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[+]" -Message "Восстановлен GameUserSettings.ini в:" -Detail "$dir" -PrefixColor Green
        }

        $bakRiot = Join-Path $dir "RiotUserSettings.backup"
        $riotUserIni = Join-Path $dir "RiotUserSettings.ini"
        if (Test-Path $bakRiot) {
            Set-ItemProperty -Path $riotUserIni -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            Copy-Item -Path $bakRiot -Destination $riotUserIni -Force
            Remove-Item -Path $bakRiot -Force -ErrorAction SilentlyContinue
            Write-NVLog -Prefix "[+]" -Message "Восстановлен RiotUserSettings.ini в:" -Detail "$dir" -PrefixColor Green
        }
    }

    Invoke-ValorantQoS -Enable $false
    Write-Host "`n[OK] Все параметры и файлы VALORANT восстановлены к исходным значениям!" -ForegroundColor Yellow
}

switch ($Action) {
    "Settings" { Invoke-ValorantSetting }
    "QoS"      { Invoke-ValorantQoS -Enable $true }
    "Restore"  { Invoke-ValorantRestore }
    "Status"   {
        while ($true) {
            $configDirs = Get-ValorantConfigDir
            $qosApplied = Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\VALORANT"

            Show-NVBannerCyan
            Write-Host "                    УТИЛИТА ОПТИМИЗАЦИИ VALORANT (System)                     " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "Профили настроек    : найдено $($configDirs.Count) каталогов WindowsClient" -ForegroundColor $(if ($configDirs.Count -gt 0) { 'Green' } else { 'Yellow' })
            Write-Host "Политика QoS (DSCP) : $(if ($qosApplied) { '[ АКТИВНА (DSCP 46) ]' } else { '[ ОТКЛЮЧЕНА ]' })" -ForegroundColor $(if ($qosApplied) { 'Green' } else { 'Yellow' })
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "[1] Применить соревновательный конфиг графики (GameUserSettings & RiotUserSettings)" -ForegroundColor White
            Write-Host "[2] Включить сетевую политику QoS для VALORANT (DSCP 46)" -ForegroundColor White
            Write-Host "[3] Восстановить все настройки из бэкапов (.backup Restore)" -ForegroundColor White
            Write-Host "[0] Назад" -ForegroundColor DarkGray
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " >> " -NoNewline -ForegroundColor Cyan
            $c = Read-Host

            switch ($c) {
                "1" { Invoke-ValorantSetting }
                "2" { Invoke-ValorantQoS -Enable $true }
                "3" { Invoke-ValorantRestore }
                default { return }
            }
        }
    }
}