<#
================================================================================
Имя твика:              Запуск Панели управления NVIDIA по требованию (nvcpl.ps1)
Что делает:             1. Отключает фоновые службы контейнеров NVIDIA:
                           - NVDisplay.ContainerLocalSystem
                           - NvContainerLocalSystem
                           - NvTelemetryContainer
                           и переводит их тип запуска в Disabled, предотвращая фоновую активность и сбор телеметрии.
                        2. Находит локальный исполняемый файл Панели управления NVIDIA (nvcplui.exe)
                           в стандартных каталогах драйвера или пакетах WindowsApps DCH.
                        3. Создаёт фоновый скрипт-обертку NV-nvcpl.ps1 в каталоге %LOCALAPPDATA%\Noverse.
                        4. Размещает ярлык Nvcpl.lnk на Рабочем столе:
                           - При клике на ярлык: временно запускаются службы NVIDIA Container, после чего открывается Панель управления.
                           - При закрытии окна панели: скрипт автоматически останавливает службы и возвращает их в состояние Disabled.
                        5. Поддерживает функцию полного отката (-Restore):
                           - Удаляет ярлык с Рабочего стола и скрипт NV-nvcpl.ps1.
                           - Возвращает службам NVIDIA Container стандартный автозапуск (Automatic) и запускает их.
Зачем нужно:            Полностью исключает фоновую нагрузку от фоновых процессов NVIDIA (до 150 МБ ОЗУ и периодические
                        опросы телеметрии таймеров процессора во время игр), сохраняя возможность в любой момент
                        открыть панель управления видеокартой в один клик.
Значение по умолчанию:  Службы NVIDIA Display Container и телеметрия непрерывно работают в фоне Windows.
Значение после твика:   Службы NVIDIA отключены в фоне и активируются исключительно во время работы панели управления.
Источник:               Официальное руководство noverse.dev и репозиторий github.com/nohuto/nohuto/tree/main/tweaks
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = "Create")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Create", "Restore", "Status")]
    [string]$Action = "Create",

    [Parameter(ParameterSetName = "Create")]
    [switch]$Create,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status
)

if ($Create)  { $Action = "Create" }
if ($Restore) { $Action = "Restore" }
if ($Status)  { $Action = "Status" }

$ErrorActionPreference = "SilentlyContinue"

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

function Get-NvidiaServices {
    $known = @("NVDisplay.ContainerLocalSystem", "NvContainerLocalSystem", "NvTelemetryContainer")
    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $known) {
        if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
            $found.Add($name)
        }
    }
    return $found
}

function Find-NvcplExecutable {
    # 1. Стандартный каталог классического драйвера
    $stdPath = "C:\Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
    if (Test-Path $stdPath) { return $stdPath }

    # 2. Поиск в DCH AppxPackage
    try {
        $pkg = Get-AppxPackage -Name "*NVIDIAControlPanel*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $candidate = Join-Path $pkg.InstallLocation "nvcplui.exe"
            if (Test-Path $candidate) { return $candidate }
        }
    } catch {}

    # 3. Поиск по каталогу WindowsApps
    $waDirs = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Filter "NVIDIACorp.NVIDIAControlPanel_*" -Directory -ErrorAction SilentlyContinue
    foreach ($wa in $waDirs) {
        $candidate = Join-Path $wa.FullName "nvcplui.exe"
        if (Test-Path $candidate) { return $candidate }
    }

    # 4. Каталог System32
    $sys32Path = "C:\Windows\System32\nvcplui.exe"
    if (Test-Path $sys32Path) { return $sys32Path }

    # 5. Локальный кэш Noverse
    $cached = Join-Path $env:LOCALAPPDATA "Noverse\nvcplui.exe"
    if (Test-Path $cached) { return $cached }

    # 6. Fallback загрузка официального клиента при отсутствии локального
    $nvlocal = Join-Path $env:LOCALAPPDATA "Noverse"
    if (-not (Test-Path $nvlocal)) {
        New-Item -ItemType Directory -Path $nvlocal -Force | Out-Null
    }
    try {
        Write-NVLog "[~]" "Загрузка вспомогательного модуля nvcplui.exe с репозитория..." -PrefixColor Yellow
        Invoke-WebRequest -Uri "https://github.com/nohuto/Files/releases/download/driver/nvcplui.exe" -OutFile $cached -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
        if (Test-Path $cached) { return $cached }
    } catch {}

    return $null
}

function Find-NvcplIcon {
    $cachedIcon = Join-Path $env:LOCALAPPDATA "Noverse\Nvcpl.ico"
    if (Test-Path $cachedIcon) { return $cachedIcon }

    $nvlocal = Join-Path $env:LOCALAPPDATA "Noverse"
    if (-not (Test-Path $nvlocal)) {
        New-Item -ItemType Directory -Path $nvlocal -Force | Out-Null
    }

    try {
        Invoke-WebRequest -Uri "https://github.com/nohuto/Files/releases/download/driver/Nvcpl.ico" -OutFile $cachedIcon -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
        if (Test-Path $cachedIcon) { return $cachedIcon }
    } catch {}

    if (Test-Path "C:\Windows\System32\nvcpl.dll") {
        return "C:\Windows\System32\nvcpl.dll,0"
    }

    return "shell32.dll,41"
}

function Invoke-NvcplCreate {
    Write-NVLog "[~]" "Настройка режима запуска Панели управления NVIDIA по требованию..." -PrefixColor Yellow

    # Отключение служб в фоне
    $services = Get-NvidiaServices
    if ($services.Count -eq 0) {
        Write-NVLog "[!]" "Службы NVIDIA Container не обнаружены в системе" -PrefixColor Yellow
    } else {
        foreach ($s in $services) {
            Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            Write-NVLog "[+]" "Фоновая служба $s остановлена и отключена" -PrefixColor Green
        }
    }

    $nvcplExe = Find-NvcplExecutable
    if (-not $nvcplExe) {
        Write-NVLog "[-]" "Исполняемый файл nvcplui.exe не найден. Убедитесь, что драйвер NVIDIA установлен." -PrefixColor Red
        return
    }
    Write-NVLog "[+]" "Обнаружен исполняемый файл NVCPL:" "$nvcplExe" -PrefixColor Green

    $iconPath = Find-NvcplIcon
    $nvlocal = Join-Path $env:LOCALAPPDATA "Noverse"
    if (-not (Test-Path $nvlocal)) {
        New-Item -ItemType Directory -Path $nvlocal -Force | Out-Null
    }

    # Генерация фонового управляющего скрипта
    $launcherPath = Join-Path $nvlocal "NV-nvcpl.ps1"
    $srvListString = ($services | ForEach-Object { "'$_'" }) -join ", "
    if (-not $srvListString) { $srvListString = "'NVDisplay.ContainerLocalSystem', 'NvContainerLocalSystem'" }

    $launcherScript = @"
`$ErrorActionPreference = "SilentlyContinue"
`$services = @($srvListString)

foreach (`$s in `$services) {
    if (Get-Service -Name `$s -ErrorAction SilentlyContinue) {
        Set-Service -Name `$s -StartupType Manual -ErrorAction SilentlyContinue
        `$svc = Get-Service -Name `$s -ErrorAction SilentlyContinue
        if (`$svc.Status -ne 'Running') {
            Start-Service -Name `$s -ErrorAction SilentlyContinue
        }
    }
}

Start-Process -FilePath "$nvcplExe" -Wait

foreach (`$s in `$services) {
    if (Get-Service -Name `$s -ErrorAction SilentlyContinue) {
        `$svc = Get-Service -Name `$s -ErrorAction SilentlyContinue
        if (`$svc.Status -eq 'Running') {
            Stop-Service -Name `$s -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name `$s -StartupType Disabled -ErrorAction SilentlyContinue
    }
}
"@

    [System.IO.File]::WriteAllText($launcherPath, $launcherScript, [System.Text.Encoding]::ASCII)
    Write-NVLog "[+]" "Скрипт управления контейнерами сохранён:" "$launcherPath" -PrefixColor Green

    # Создание ярлыка на Рабочем столе
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop "Nvcpl.lnk"

    try {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`""
        $shortcut.WorkingDirectory = $nvlocal
        $shortcut.IconLocation = $iconPath
        $shortcut.Save()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
        Write-NVLog "[+]" "Ярлык NVCPL успешно создан на Рабочем столе:" "$shortcutPath" -PrefixColor Green
    } catch {
        Write-NVLog "[-]" "Ошибка создания ярлыка WScript.Shell: $($_.Exception.Message)" -PrefixColor Red
    }
}

function Invoke-NvcplRestore {
    Write-NVLog "[~]" "Откат режима запуска Панели управления NVIDIA..." -PrefixColor Yellow

    # Удаление ярлыка
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop "Nvcpl.lnk"
    if (Test-Path $shortcutPath) {
        Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Ярлык Nvcpl.lnk удалён с Рабочего стола" -PrefixColor Green
    }

    # Удаление управляющего скрипта
    $launcherPath = Join-Path $env:LOCALAPPDATA "Noverse\NV-nvcpl.ps1"
    if (Test-Path $launcherPath) {
        Remove-Item -Path $launcherPath -Force -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Скрипт NV-nvcpl.ps1 удалён" -PrefixColor Green
    }

    # Возврат стандартного автозапуска служб
    $services = Get-NvidiaServices
    foreach ($s in $services) {
        Set-Service -Name $s -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $s -ErrorAction SilentlyContinue
        Write-NVLog "[+]" "Служба $s возвращена в режим Automatic и запущена" -PrefixColor Green
    }

    Write-NVLog "[+]" "Откат настроек NVCPL успешно завершён!" -PrefixColor Green
}

function Get-NvcplStatus {
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "             СТАТУС ПАНЕЛИ УПРАВЛЕНИЯ NVIDIA И ФОНОВЫХ СЛУЖБ                  " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host ""

    $nvcplExe = Find-NvcplExecutable
    if ($nvcplExe) {
        Write-Host " [√] Исполняемый файл nvcplui.exe: " -NoNewline -ForegroundColor Green
        Write-Host "$nvcplExe" -ForegroundColor White
    } else {
        Write-Host " [-] Исполняемый файл nvcplui.exe: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Не обнаружен" -ForegroundColor DarkGray
    }

    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop "Nvcpl.lnk"
    if (Test-Path $shortcutPath) {
        Write-Host " [√] Ярлык запуска по требованию: " -NoNewline -ForegroundColor Green
        Write-Host "Присутствует на Рабочем столе" -ForegroundColor White
    } else {
        Write-Host " [-] Ярлык запуска по требованию: " -NoNewline -ForegroundColor DarkGray
        Write-Host "Отсутствует" -ForegroundColor DarkGray
    }

    $services = Get-NvidiaServices
    if ($services.Count -gt 0) {
        Write-Host "`n Состояние служб NVIDIA Container:" -ForegroundColor Yellow
        foreach ($s in $services) {
            $svc = Get-Service -Name $s
            $color = if ($svc.StartType -eq "Disabled") { "Green" } else { "DarkGray" }
            Write-Host "   - $($svc.Name): " -NoNewline -ForegroundColor White
            Write-Host "Статус = $($svc.Status), Тип запуска = $($svc.StartType)" -ForegroundColor $color
        }
    } else {
        Write-Host " [-] Службы NVIDIA Container в системе не зарегистрированы" -ForegroundColor DarkGray
    }
    Write-Host ""
}

switch ($Action) {
    "Create"  { Invoke-NvcplCreate }
    "Restore" { Invoke-NvcplRestore }
    "Status"  { Get-NvcplStatus }
}