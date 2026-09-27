<#
================================================================================
Имя твика:              Оптимизация и переключатель служб Logitech G HUB (LGHUB-Tweaks)
Что делает:             Позволяет выборочно включать или полностью отключать фоновые компоненты ПО Logitech:
                           - Службу обновления LGHUBUpdaterService (lghub_updater.exe)
                           - Виртуальный драйвер шины ввода logi_joy_bus_enum
                           - Виртуальный драйвер устройств ввода logi_joy_vir_hid
                           - Запись автозагрузки приложения в реестре Run
                           - Активные фоновые процессы lghub.exe, lghub_agent.exe, logi_lamparray_service.exe
Зачем нужно:            ПО Logitech G HUB держит в постоянной работе тяжелые Node.js/Electron процессы,
                        виртуальные шины трансляции ввода и службу обновления, которые создают фоновую
                        нагрузку на CPU, вызывают лишние прерывания DPC/ISR и расходуют сотни мегабайт ОЗУ.
                        Твик позволяет активировать сервисы только по необходимости (например, для настройки
                        гарнитуры/мыши), а во время игр держать их отключенными.
Значение по умолчанию:  Служба LGHUBUpdaterService включена (Start=2 Automatic); драйверы logi_joy_bus_enum и
                        logi_joy_vir_hid активны (Start=1 или 3); автозапуск в Run активен.
Значение после твика:   Служба и драйверы отключены (Start=4 Disabled); автозапуск удален; фоновые процессы завершены.
                        При включении (Enable) служба переводится в Manual (Start=3) и запускается.
Источник / Категория:   Gaming & System Optimizer: Peripherals & Drivers Tuning
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Enable", "Disable", "Restore", "Status")]
    [string]$Action,

    [Parameter()]
    [switch]$Enable,

    [Parameter()]
    [switch]$Disable,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

if ($Enable)  { $Action = "Enable" }
if ($Disable) { $Action = "Disable" }
if ($Restore) { $Action = "Restore" }

$svcKey      = "HKLM:\SYSTEM\CurrentControlSet\Services"
$updaterSvc  = "LGHUBUpdaterService"
$busEnum     = "logi_joy_bus_enum"
$virHid      = "logi_joy_vir_hid"

$lghubProgramDirs = @(
    "${env:ProgramFiles}\LGHUB",
    "${env:ProgramFiles(x86)}\LGHUB"
)
$lghubInstallDir = $lghubProgramDirs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$lghubAppDataDir = Join-Path $env:LOCALAPPDATA "LGHUB"
$backupFile      = if (Test-Path -LiteralPath $lghubAppDataDir) {
    Join-Path $lghubAppDataDir "lghub_state_backup.json"
} else {
    Join-Path $env:ProgramData "LGHUB\lghub_state_backup.json"
}

# ------------------------------------------------------------------------------
# 1. Проверка наличия приложения и служб в системе
# ------------------------------------------------------------------------------
function Test-LGHUBInstalled {
    $hasSvc = (Test-Path -LiteralPath "$svcKey\$updaterSvc") -or `
              (Test-Path -LiteralPath "$svcKey\$busEnum") -or `
              (Test-Path -LiteralPath "$svcKey\$virHid")
    $hasDir = ($null -ne $lghubInstallDir) -or (Test-Path -LiteralPath $lghubAppDataDir)
    $hasRun = $false
    $runPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
    foreach ($rp in $runPaths) {
        if (Test-Path -LiteralPath $rp) {
            $val = Get-ItemProperty -Path $rp -Name "LGHUB" -ErrorAction SilentlyContinue
            if ($val -and $val.LGHUB) { $hasRun = $true; break }
        }
    }
    return ($hasSvc -or $hasDir -or $hasRun)
}

if (-not (Test-LGHUBInstalled)) {
    if (-not $Quiet) {
        Write-Host "[-] Logitech G HUB не обнаружен в системе, пропуск твика." -ForegroundColor Yellow
    }
    return
}

# По умолчанию в неинтерактивном режиме с пустым Action применяем Disable (твик производительности)
if ([string]::IsNullOrEmpty($Action)) {
    $Action = "Disable"
}

function Write-LogMsg {
    param(
        [string]$Prefix,
        [string]$Message,
        [string]$Detail = "",
        [ConsoleColor]$PrefixColor = "Green",
        [ConsoleColor]$DetailColor = "DarkGray"
    )
    if ($Quiet) { return }
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

function Stop-LGHUBProcess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    $procNames = @("lghub", "lghub_agent", "lghub_updater", "logi_lamparray_service")
    foreach ($p in $procNames) {
        $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($procs) {
            if ($PSCmdlet.ShouldProcess($p, "Stop active process")) {
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            Write-LogMsg -Prefix "[-]" -Message "Завершен активный процесс" -Detail $p -PrefixColor Yellow
        }
    }
}

function Save-LGHUBBackup {
    $parentDir = Split-Path -Path $backupFile -Parent
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if ((Test-Path -LiteralPath $parentDir) -and -not (Test-Path -LiteralPath $backupFile)) {
        try {
            $state = [ordered]@{
                UpdaterStart = $null
                BusEnumStart = $null
                VirHidStart  = $null
                RunHKCU      = $null
                RunHKLM      = $null
            }
            if (Test-Path -LiteralPath "$svcKey\$updaterSvc") {
                $state.UpdaterStart = (Get-ItemProperty -Path "$svcKey\$updaterSvc" -Name "Start" -ErrorAction SilentlyContinue).Start
            }
            if (Test-Path -LiteralPath "$svcKey\$busEnum") {
                $state.BusEnumStart = (Get-ItemProperty -Path "$svcKey\$busEnum" -Name "Start" -ErrorAction SilentlyContinue).Start
            }
            if (Test-Path -LiteralPath "$svcKey\$virHid") {
                $state.VirHidStart = (Get-ItemProperty -Path "$svcKey\$virHid" -Name "Start" -ErrorAction SilentlyContinue).Start
            }
            $hkcuRun = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LGHUB" -ErrorAction SilentlyContinue
            if ($hkcuRun -and $hkcuRun.LGHUB) { $state.RunHKCU = $hkcuRun.LGHUB }
            $hklmRun = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LGHUB" -ErrorAction SilentlyContinue
            if ($hklmRun -and $hklmRun.LGHUB) { $state.RunHKLM = $hklmRun.LGHUB }

            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupFile -Encoding UTF8
        } catch {
            Write-Verbose "Не удалось сохранить резервный снимок: $_"
        }
    }
}

function Enable-LGHUBComponent {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not $Quiet) {
        Write-Host "`n[*] Включение Logitech G HUB..." -ForegroundColor Cyan
    }

    $svc = Get-Service -Name $updaterSvc -ErrorAction SilentlyContinue
    if ($svc) {
        if ($PSCmdlet.ShouldProcess($updaterSvc, "Set startup type to Manual")) {
            Set-Service -Name $updaterSvc -StartupType Manual -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[+]" -Message "Тип запуска установлен в Manual" -Detail $updaterSvc -PrefixColor Green

        if ($PSCmdlet.ShouldProcess($updaterSvc, "Start service")) {
            Start-Service -Name $updaterSvc -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[+]" -Message "Служба запущена" -Detail $updaterSvc -PrefixColor Green
    } else {
        Write-LogMsg -Prefix "[!]" -Message "Служба не найдена в системе" -Detail $updaterSvc -PrefixColor Yellow
    }

    if (-not $Quiet) {
        Write-Host "`n[OK] Logitech G HUB активирован (служба обновления запущена в ручном режиме)!" -ForegroundColor Green
    }
}

function Disable-LGHUBComponent {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not $Quiet) {
        Write-Host "`n[*] Отключение Logitech G HUB (Оптимизация производительности)..." -ForegroundColor Cyan
    }

    # 1. Сохранение резервной копии
    Save-LGHUBBackup

    # 2. Остановка активных процессов
    Stop-LGHUBProcess

    # 3. Остановка и отключение службы обновления
    $svc = Get-Service -Name $updaterSvc -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        if ($PSCmdlet.ShouldProcess($updaterSvc, "Stop service")) {
            Stop-Service -Name $updaterSvc -Force -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[-]" -Message "Служба остановлена" -Detail $updaterSvc -PrefixColor Yellow
    }

    $updaterKey = "$svcKey\$updaterSvc"
    if (Test-Path -LiteralPath $updaterKey) {
        if ($PSCmdlet.ShouldProcess($updaterKey, "Set Start=4 (Disabled)")) {
            Set-ItemProperty -Path $updaterKey -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[+]" -Message "Служба отключена (Start=4)" -Detail $updaterSvc -PrefixColor Green
    }

    # 4. Отключение виртуальных драйверов ввода
    $busKey = "$svcKey\$busEnum"
    if (Test-Path -LiteralPath $busKey) {
        if ($PSCmdlet.ShouldProcess($busKey, "Set Start=4 (Disabled)")) {
            Set-ItemProperty -Path $busKey -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[+]" -Message "Драйвер отключен (Start=4)" -Detail $busEnum -PrefixColor Green
    }

    $hidKey = "$svcKey\$virHid"
    if (Test-Path -LiteralPath $hidKey) {
        if ($PSCmdlet.ShouldProcess($hidKey, "Set Start=4 (Disabled)")) {
            Set-ItemProperty -Path $hidKey -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-LogMsg -Prefix "[+]" -Message "Драйвер отключен (Start=4)" -Detail $virHid -PrefixColor Green
    }

    # 5. Удаление автозапуска из Run
    $runPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
    foreach ($rp in $runPaths) {
        if (Test-Path -LiteralPath $rp) {
            $val = Get-ItemProperty -Path $rp -Name "LGHUB" -ErrorAction SilentlyContinue
            if ($val -and $val.LGHUB) {
                if ($PSCmdlet.ShouldProcess($rp, "Remove LGHUB autostart")) {
                    Remove-ItemProperty -Path $rp -Name "LGHUB" -ErrorAction SilentlyContinue
                }
                Write-LogMsg -Prefix "[+]" -Message "Удалена запись автозапуска" -Detail $rp -PrefixColor Green
            }
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[OK] Logitech G HUB полностью отключен (фоновая нагрузка устранена)!" -ForegroundColor Green
    }
}

function Restore-LGHUBComponent {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not $Quiet) {
        Write-Host "`n[*] Восстановление исходных параметров Logitech G HUB..." -ForegroundColor Cyan
    }

    if (Test-Path -LiteralPath $backupFile) {
        try {
            $backupData = Get-Content -LiteralPath $backupFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $backupData.UpdaterStart -and (Test-Path -LiteralPath "$svcKey\$updaterSvc")) {
                Set-ItemProperty -Path "$svcKey\$updaterSvc" -Name "Start" -Value $backupData.UpdaterStart -Type DWord -ErrorAction SilentlyContinue
                Write-LogMsg -Prefix "[+]" -Message "Служба восстановлена" -Detail "Start=$($backupData.UpdaterStart)" -PrefixColor Green
            }
            if ($null -ne $backupData.BusEnumStart -and (Test-Path -LiteralPath "$svcKey\$busEnum")) {
                Set-ItemProperty -Path "$svcKey\$busEnum" -Name "Start" -Value $backupData.BusEnumStart -Type DWord -ErrorAction SilentlyContinue
                Write-LogMsg -Prefix "[+]" -Message "Драйвер bus_enum восстановлен" -Detail "Start=$($backupData.BusEnumStart)" -PrefixColor Green
            }
            if ($null -ne $backupData.VirHidStart -and (Test-Path -LiteralPath "$svcKey\$virHid")) {
                Set-ItemProperty -Path "$svcKey\$virHid" -Name "Start" -Value $backupData.VirHidStart -Type DWord -ErrorAction SilentlyContinue
                Write-LogMsg -Prefix "[+]" -Message "Драйвер vir_hid восстановлен" -Detail "Start=$($backupData.VirHidStart)" -PrefixColor Green
            }
            if ($backupData.RunHKCU) {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LGHUB" -Value $backupData.RunHKCU -Type String -Force
                Write-LogMsg -Prefix "[+]" -Message "Автозапуск в HKCU Run восстановлен" -Detail $backupData.RunHKCU -PrefixColor Green
            }
            if ($backupData.RunHKLM) {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LGHUB" -Value $backupData.RunHKLM -Type String -Force
                Write-LogMsg -Prefix "[+]" -Message "Автозапуск в HKLM Run восстановлен" -Detail $backupData.RunHKLM -PrefixColor Green
            }
            Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Ошибка при чтении резервной копии: $_"
        }
    } else {
        # Fallback на стандартные заводские дефолты
        $updaterKey = "$svcKey\$updaterSvc"
        if (Test-Path -LiteralPath $updaterKey) {
            Set-ItemProperty -Path $updaterKey -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            Write-LogMsg -Prefix "[+]" -Message "Служба восстановлена в Automatic (Start=2)" -Detail $updaterSvc -PrefixColor Green
        }
        $busKey = "$svcKey\$busEnum"
        if (Test-Path -LiteralPath $busKey) {
            Set-ItemProperty -Path $busKey -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
            Write-LogMsg -Prefix "[+]" -Message "Драйвер восстановлен в Demand/Manual (Start=3)" -Detail $busEnum -PrefixColor Green
        }
        $hidKey = "$svcKey\$virHid"
        if (Test-Path -LiteralPath $hidKey) {
            Set-ItemProperty -Path $hidKey -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
            Write-LogMsg -Prefix "[+]" -Message "Драйвер восстановлен в Demand/Manual (Start=3)" -Detail $virHid -PrefixColor Green
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[OK] Параметры Logitech G HUB возвращены к стандартным значениям!" -ForegroundColor Yellow
    }
}

function Get-LGHUBState {
    $state = @{
        Installed             = $false
        UpdaterServiceExists  = $false
        UpdaterServiceStart   = "Unknown"
        UpdaterServiceRunning = $false
        BusEnumExists         = $false
        BusEnumStart          = "Unknown"
        VirHidExists          = $false
        VirHidStart           = "Unknown"
        AutostartExists       = $false
    }

    $updaterKey = "$svcKey\$updaterSvc"
    if (Test-Path -LiteralPath $updaterKey) {
        $state.Installed = $true
        $state.UpdaterServiceExists = $true
        $val = (Get-ItemProperty -Path $updaterKey -Name "Start" -ErrorAction SilentlyContinue).Start
        $state.UpdaterServiceStart = "$val"
    }

    $svc = Get-Service -Name $updaterSvc -ErrorAction SilentlyContinue
    if ($svc) {
        $state.UpdaterServiceRunning = ($svc.Status -eq "Running")
    }

    $busKey = "$svcKey\$busEnum"
    if (Test-Path -LiteralPath $busKey) {
        $state.Installed = $true
        $state.BusEnumExists = $true
        $val = (Get-ItemProperty -Path $busKey -Name "Start" -ErrorAction SilentlyContinue).Start
        $state.BusEnumStart = "$val"
    }

    $hidKey = "$svcKey\$virHid"
    if (Test-Path -LiteralPath $hidKey) {
        $state.Installed = $true
        $state.VirHidExists = $true
        $val = (Get-ItemProperty -Path $hidKey -Name "Start" -ErrorAction SilentlyContinue).Start
        $state.VirHidStart = "$val"
    }

    $runPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
    foreach ($rp in $runPaths) {
        if (Test-Path -LiteralPath $rp) {
            $val = Get-ItemProperty -Path $rp -Name "LGHUB" -ErrorAction SilentlyContinue
            if ($val -and $val.LGHUB) { $state.AutostartExists = $true }
        }
    }

    return $state
}

switch ($Action) {
    "Enable"  { Enable-LGHUBComponent }
    "Disable" { Disable-LGHUBComponent }
    "Restore" { Restore-LGHUBComponent }
    "Status"  {
        while ($true) {
            $st = Get-LGHUBState

            Write-Host "`n==============================================================================" -ForegroundColor DarkCyan
            Write-Host "           ПЕРЕКЛЮЧАТЕЛЬ LOGITECH G HUB (Gaming & System Optimizer)           " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "Установлен в системе : $(if ($st.Installed) { '[ ОБНАРУЖЕН ]' } else { '[ НЕ НАЙДЕН ]' })" -ForegroundColor $(if ($st.Installed) { 'Green' } else { 'Yellow' })
            Write-Host "LGHUBUpdaterService  : $(if ($st.UpdaterServiceStart -eq '4') { '[ ОТКЛЮЧЕНА (Start=4) ]' } elseif ($st.UpdaterServiceStart -eq '3') { '[ ВРУЧНУЮ (Start=3) ]' } elseif ($st.UpdaterServiceStart -eq '2') { '[ АВТО (Start=2) ]' } else { '[ НЕ УСТАНОВЛЕНА ]' }) $(if ($st.UpdaterServiceRunning) { '(РАБОТАЕТ)' } else { '(ОСТАНОВЛЕНА)' })" -ForegroundColor $(if ($st.UpdaterServiceStart -eq '4') { 'Green' } else { 'Yellow' })
            Write-Host "logi_joy_bus_enum    : $(if ($st.BusEnumStart -eq '4') { '[ ОТКЛЮЧЕН (Start=4) ]' } else { '[ АКТИВЕН / Start=' + $st.BusEnumStart + ' ]' })" -ForegroundColor $(if ($st.BusEnumStart -eq '4') { 'Green' } else { 'Yellow' })
            Write-Host "logi_joy_vir_hid     : $(if ($st.VirHidStart -eq '4') { '[ ОТКЛЮЧЕН (Start=4) ]' } else { '[ АКТИВЕН / Start=' + $st.VirHidStart + ' ]' })" -ForegroundColor $(if ($st.VirHidStart -eq '4') { 'Green' } else { 'Yellow' })
            Write-Host "Автозапуск в Run     : $(if ($st.AutostartExists) { '[ ВКЛЮЧЕН ]' } else { '[ ОТКЛЮЧЕН ]' })" -ForegroundColor $(if (-not $st.AutostartExists) { 'Green' } else { 'Yellow' })
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "[1] Включить LGHUB (Включить службу обновления в режим Manual и запустить)" -ForegroundColor White
            Write-Host "[2] Отключить LGHUB (Остановить службу, процессы и драйверы bus_enum / vir_hid)" -ForegroundColor White
            Write-Host "[3] Восстановить стандартные параметры служб и драйверов (Restore)" -ForegroundColor White
            Write-Host "[Q] Назад" -ForegroundColor DarkGray
            Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " >> " -NoNewline -ForegroundColor Cyan
            $c = Read-Host

            switch ($c) {
                "1" { Enable-LGHUBComponent }
                "2" { Disable-LGHUBComponent }
                "3" { Restore-LGHUBComponent }
                default { return }
            }
        }
    }
}
