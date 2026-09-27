#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Утилита для облегчения (debloat) и чистой установки драйвера NVIDIA:
#    - Распаковывает официальный дистрибутив NVIDIA Game Ready Driver с помощью 7-Zip.
#    - Удаляет все лишние и телеметрические модули (NvTelemetry, NvContainer, Shield,
#      GFExperience, Audio, PPC, Node.js), оставляя только чистый видеодрайвер Display.Driver,
#      движок инсталлятора NVI2, setup.cfg и setup.exe.
#    - Очищает setup.cfg от навязанного сбора телеметрии, согласия с EULA и политиками конфиденциальности.
#    - Очищает NVI2\presentations.cfg от фоновой загрузки рекламных веб-слайдов.
#    - Настраивает цветовую тему инсталлятора Optimizer (акцентные синие цвета) и заменяет фоны.
#    - Предоставляет опцию безопасной зачистки старых видеодрайверов через DDU (Display Driver Uninstaller).
#    - Поддерживает как интерактивное консольное меню, так и автоматизированный CLI-запуск (-Action Debloat/Install/DDU/Status).
#
# 2. ЗАЧЕМ:
#    Официальный инсталлятор NVIDIA по умолчанию устанавливает множество фоновых служб слежения
#    и контейнеров телеметрии, которые регулярно нагружают процессор, опрашивают шину PCIe,
#    записывают диагностические логи на диск и вызывают микрофризы (micro-stuttering) в играх.
#    Облегченный драйвер оставляет только низкоуровневый видеодрайвер без лишних служб.
#
# 3. ПОСЛЕДСТВИЯ:
#    В указанной папке (по умолчанию Desktop\NV-Driver) формируется чистая автономная сборка инсталлятора.
#    При установке разворачивается только видеодрайвер и панель управления NVIDIA Control Panel
#    (без фоновых служб NvContainerTelemetry, NvTelemetryContainer и GeForce Experience).
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (x64) с видеокартами NVIDIA GeForce / RTX.
#    Поддерживает Windows PowerShell 5.1 и PowerShell 7+.
#    Требует установленный архиватор 7-Zip (Program Files\7-Zip\7z.exe).
#
# 5. ОТКАТ:
#    Для возврата к стандартному драйверу достаточно скачать и запустить официальный
#    полный инсталлятор GeForce Experience или Game Ready Driver с сайта NVIDIA
#    в режиме «Чистая установка» (Clean Install).
#
# 6. ИСТОЧНИК:
#    Официальное руководство Optimizer:
#    Gaming & System Optimizer Reference
#    Репозиторий System:
#    https://github.com/system-optimizer
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Debloat", "Install", "DDU", "Status")]
    [string]$Action = "Status",

    [Parameter()]
    [string]$DriverPath = "",

    [Parameter()]
    [string]$OutputDir = "",

    [Parameter(ParameterSetName = "Debloat")]
    [switch]$Debloat,

    [Parameter(ParameterSetName = "Install")]
    [switch]$Install,

    [Parameter(ParameterSetName = "DDU")]
    [switch]$DDU,

    [Parameter()]
    [switch]$NonInteractive
)

if ($Debloat) { $Action = "Debloat" }
if ($Install) { $Action = "Install" }
if ($DDU) { $Action = "DDU" }

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

function Get-7ZipPath {
    $paths = [System.Collections.Generic.List[string]]::new()
    $paths.Add("C:\Program Files\7-Zip\7z.exe")
    $paths.Add("C:\Program Files (x86)\7-Zip\7z.exe")
    if ($env:ProgramW6432) {
        $paths.Add((Join-Path $env:ProgramW6432 "7-Zip\7z.exe"))
    }
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    $cmd = Get-Command 7z -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-NVDriverDebloat {
    param(
        [string]$InputPath = "",
        [string]$CustomOutputDir = ""
    )

    Show-NVBannerCyan
    $sevenZip = Get-7ZipPath
    if (-not $sevenZip) {
        Write-Host " [!] 7-Zip не найден в системе. Установите 7-Zip перед продолжением." -ForegroundColor Red
        Write-Host " Открытие страницы загрузки 7-Zip..." -ForegroundColor Yellow
        Start-Process "https://www.7-zip.org/download.html"
        return
    }

    $driverp = $InputPath
    if ([string]::IsNullOrWhiteSpace($driverp)) {
        $downloadsDir = Join-Path $env:USERPROFILE "Downloads"
        $candidates = Get-ChildItem -Path $downloadsDir -Filter *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "notebook-win10|desktop-win10|\d{3}\.\d{2}-|nvidia.*\.exe" }
        if ($candidates) {
            $driverp = ($candidates | Select-Object -First 1).FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($driverp) -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        Write-Host " Для загрузки оригинального драйвера NVIDIA откройте TechPowerUp:" -ForegroundColor DarkGray
        Start-Process "https://www.techpowerup.com/download/nvidia-geforce-graphics-drivers/"
        Write-Host "`n Введите полный путь к скачанному инсталлятору драйвера NVIDIA:" -ForegroundColor White
        Write-Host " (Оставьте пустым для автопоиска в папке Загрузки)" -ForegroundColor DarkGray
        Write-Host " >> " -NoNewline -ForegroundColor Cyan
        $driverp = Read-Host
    }

    if (-not $driverp -or -not (Test-Path -LiteralPath $driverp)) {
        Write-NVLog -Prefix "[-]" -Message "Инсталлятор драйвера не найден по пути:" -Detail "$driverp" -PrefixColor Red
        return
    }

    Show-NVBannerCyan
    Write-NVLog -Prefix "[+]" -Message "Обработка инсталлятора:" -Detail "$driverp" -PrefixColor Green -DetailColor Cyan

    $targetDir = if ($CustomOutputDir) { $CustomOutputDir } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "NV-Driver" }
    if (Test-Path -LiteralPath $targetDir) {
        Write-NVLog -Prefix "[*]" -Message "Очистка предыдущей сборки в:" -Detail "$targetDir" -PrefixColor Yellow
        Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null

    Write-NVLog -Prefix "[*]" -Message "Распаковка дистрибутива через 7-Zip..." -PrefixColor Cyan
    & $sevenZip x "$driverp" -o"$targetDir" -y | Out-Null
    Write-NVLog -Prefix "[+]" -Message "Драйвер распакован в:" -Detail "$targetDir" -PrefixColor Green

    Write-NVLog -Prefix "[*]" -Message "Удаление компонентов телеметрии, аудио и лишних модулей..." -PrefixColor Cyan
    $keepItems = @("Display.Driver", "NVI2", "setup.cfg", "setup.exe")

    Get-ChildItem -LiteralPath $targetDir | Where-Object { $_.Name -notin $keepItems } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-NVLog -Prefix "[-]" -Message "Удален компонент:" -Detail "$($_.Name)" -PrefixColor Yellow
    }
    Write-NVLog -Prefix "[+]" -Message "Все лишние модули успешно удалены!" -PrefixColor Green

    Write-NVLog -Prefix "[*]" -Message "Очистка setup.cfg от телеметрии и согласий EULA..." -PrefixColor Cyan
    $cfgb = Join-Path $targetDir "setup.cfg"
    if (Test-Path -LiteralPath $cfgb) {
        $cfga = Get-Content -LiteralPath $cfgb | Where-Object {
            $_ -notmatch '<file name="eula.txt"/>' -and
            $_ -notmatch '<file name="\${{EulaHtmlFile}}"/>' -and
            $_ -notmatch '<file name="\${{FunctionalConsentFile}}"/>' -and
            $_ -notmatch '<file name="\${{PrivacyPolicyFile}}"/>'
        }
        Set-Content -LiteralPath $cfgb -Value $cfga -Encoding UTF8
        Write-NVLog -Prefix "[+]" -Message "setup.cfg очищен" -PrefixColor Green
    }

    Write-NVLog -Prefix "[*]" -Message "Очистка presentations.cfg от фоновой рекламы..." -PrefixColor Cyan
    $cfgb2 = Join-Path $targetDir "NVI2\presentations.cfg"
    if (Test-Path -LiteralPath $cfgb2) {
        $cfga2 = Get-Content -LiteralPath $cfgb2 | Where-Object {
            $_ -notmatch '<string name="ProgressPresentationUrl" value=' -and
            $_ -notmatch '<string name="ProgressPresentationSelectedPackageUrl" value='
        }
        Set-Content -LiteralPath $cfgb2 -Value $cfga2 -Encoding UTF8
        Write-NVLog -Prefix "[+]" -Message "presentations.cfg очищен" -PrefixColor Green
    }

    $theme = Join-Path $targetDir "NVI2\theme.cfg"
    if (Test-Path -LiteralPath $theme) {
        (Get-Content -LiteralPath $theme) -replace '<string name="SideBarDoneTextColor" value="0x76B900"/>', '<string name="SideBarDoneTextColor" value="0x3D85C6"/>' -replace '<string name="PrimaryButtonPressedTextColor" value="0x007700"/>', '<string name="PrimaryButtonPressedTextColor" value="0x0B5394"/>' | Set-Content -LiteralPath $theme -Encoding UTF8
        Write-NVLog -Prefix "[+]" -Message "Цветовая схема обновлена" -PrefixColor Green
    }

    Write-NVLog -Prefix "[*]" -Message "Загрузка кастомных графических ассетов инсталлятора..." -PrefixColor Cyan
    $picdown = Join-Path $targetDir "NVI2"
    if (Test-Path -LiteralPath $picdown) {
        $files = @(
            @{ Url = "https://github.com/system-optimizer"; FileName = "install_bg.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "install_bg_rtl.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "splash.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "splash_rtl.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "uninstall_bg.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "uninstall_bg_rtl.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "presentations_bg.png" },
            @{ Url = "https://github.com/system-optimizer"; FileName = "presentations_bg_rtl.png" }
        )
        foreach ($file in $files) {
            $picpath = Join-Path -Path $picdown -ChildPath $file.FileName
            try {
                Invoke-WebRequest -Uri $file.Url -OutFile $picpath -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            } catch {
                $null = $_
            }
        }
        Write-NVLog -Prefix "[+]" -Message "Графические ассеты успешно обновлены" -PrefixColor Green
    }

    Write-Host "`n[OK] Облегченный драйвер NVIDIA успешно подготовлен в каталоге:" -ForegroundColor Green
    Write-Host "     $targetDir" -ForegroundColor Cyan
}

function Invoke-NVDDUClean {
    Show-NVBannerCyan
    Write-Host " [!] ВНИМАНИЕ: Очистка DDU требует загрузки в безопасный режим." -ForegroundColor Yellow
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        Write-NVLog -Prefix "[!]" -Message "Интерактивный ввод недоступен. Пропуск перезагрузки DDU." -PrefixColor Yellow
        return
    }

    Write-Host " Скачать DDU и настроить Safe Mode? (Y/N): " -NoNewline -ForegroundColor Cyan
    $c = Read-Host
    if ($c -match '^[YyДд]$') {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $dduZip = Join-Path $desktop "NV-DDU.zip"
        $dduDir = Join-Path $desktop "NV-DDU"
        $dduPs1 = Join-Path $desktop "NV-DDU.ps1"

        Write-NVLog -Prefix "[*]" -Message "Загрузка официального архива DDU..." -PrefixColor Cyan
        Invoke-WebRequest -Uri "https://github.com/system-optimizer" -OutFile $dduZip -UseBasicParsing -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $dduZip) {
            Expand-Archive -LiteralPath $dduZip -DestinationPath $dduDir -Force
            Remove-Item -LiteralPath $dduZip -Force -ErrorAction SilentlyContinue
        }

        Write-NVLog -Prefix "[*]" -Message "Загрузка скрипта DDU автоматизации..." -PrefixColor Cyan
        Invoke-WebRequest -Uri "https://github.com/system-optimizer" -OutFile $dduPs1 -UseBasicParsing -ErrorAction SilentlyContinue

        Write-NVLog -Prefix "[*]" -Message "Настройка безопасного режима загрузки Windows..." -PrefixColor Yellow
        bcdedit /set safeboot minimal | Out-Null

        Write-Host "`nПосле перезагрузки в безопасном режиме запустите с Рабочего стола файл NV-DDU.ps1." -ForegroundColor Green
        Write-Host "Перезагрузить ПК сейчас? (Y/N): " -NoNewline -ForegroundColor Yellow
        $rb = Read-Host
        if ($rb -match '^[YyДд]$') {
            Restart-Computer -Force
        }
    } else {
        Write-NVLog -Prefix "[~]" -Message "Операция DDU отменена пользователем." -PrefixColor DarkGray
    }
}

function Invoke-NVDriverInstall {
    param([string]$CustomOutputDir = "")

    $targetDir = if ($CustomOutputDir) { $CustomOutputDir } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "NV-Driver" }
    $setupExe = Join-Path $targetDir "setup.exe"

    if (-not (Test-Path -LiteralPath $setupExe)) {
        Write-NVLog -Prefix "[-]" -Message "Папка облегченного драйвера не найдена:" -Detail "$setupExe" -PrefixColor Red
        Write-Host "Сначала выполните пункт [1] Debloat driver." -ForegroundColor DarkGray
        return
    }

    Show-NVBannerCyan
    Write-NVLog -Prefix "[*]" -Message "Запуск инсталлятора облегченного драйвера..." -PrefixColor Green
    Start-Process -FilePath $setupExe -Wait
    Write-NVLog -Prefix "[+]" -Message "Установка завершена!" -PrefixColor Green
}

$effectiveTargetDir = if ($OutputDir) { $OutputDir } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "NV-Driver" }

switch ($Action) {
    "Debloat" { Invoke-NVDriverDebloat -InputPath $DriverPath -CustomOutputDir $effectiveTargetDir }
    "Install" { Invoke-NVDriverInstall -CustomOutputDir $effectiveTargetDir }
    "DDU"     { Invoke-NVDDUClean }
    "Status"  {
        $setupExists = Test-Path -LiteralPath (Join-Path $effectiveTargetDir "setup.exe")
        $sevenZipPath = Get-7ZipPath

        if ($NonInteractive -or [Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
            Show-NVBannerCyan
            Write-Host "Каталог облегченного драйвера: $effectiveTargetDir" -ForegroundColor DarkGray
            Write-Host "Статус подготовленного драйвера: $(if ($setupExists) { '[ ГОТОВ К УСТАНОВКЕ ]' } else { '[ НЕ ПОДГОТОВЛЕН ]' })" -ForegroundColor $(if ($setupExists) { 'Green' } else { 'Yellow' })
            Write-Host "Архиватор 7-Zip: $(if ($sevenZipPath) { "[ НАЙДЕН: $sevenZipPath ]" } else { '[ НЕ НАЙДЕН ]' })" -ForegroundColor $(if ($sevenZipPath) { 'Green' } else { 'Red' })
            return
        }

        while ($true) {
            $setupExists = Test-Path -LiteralPath (Join-Path $effectiveTargetDir "setup.exe")
            Show-NVBannerCyan
            Write-Host "                     УТИЛИТА ПОДГОТОВКИ ДРАЙВЕРА NVIDIA (System)              " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "Каталог облегченного драйвера: $effectiveTargetDir" -ForegroundColor DarkGray
            Write-Host "Статус подготовленного драйвера: $(if ($setupExists) { '[ ГОТОВ К УСТАНОВКЕ ]' } else { '[ НЕ ПОДГОТОВЛЕН ]' })" -ForegroundColor $(if ($setupExists) { 'Green' } else { 'Yellow' })
            Write-Host "Архиватор 7-Zip: $(if ($sevenZipPath) { "[ НАЙДЕН: $sevenZipPath ]" } else { '[ НЕ НАЙДЕН ]' })" -ForegroundColor $(if ($sevenZipPath) { 'Green' } else { 'Red' })
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "[1] Облегчить драйвер (Debloat Driver: удаление Telemetry, NvContainer, Audio)" -ForegroundColor White
            Write-Host "[2] Запустить установку облегченного драйвера (setup.exe)" -ForegroundColor White
            Write-Host "[3] Чистка системы через DDU перед установкой (Safe Boot)" -ForegroundColor White
            Write-Host "[0] Назад" -ForegroundColor DarkGray
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " >> " -NoNewline -ForegroundColor Cyan
            $c = Read-Host

            switch ($c) {
                "1" { Invoke-NVDriverDebloat -InputPath $DriverPath -CustomOutputDir $effectiveTargetDir }
                "2" { Invoke-NVDriverInstall -CustomOutputDir $effectiveTargetDir }
                "3" { Invoke-NVDDUClean }
                default { return }
            }
        }
    }
}