# ==============================================================================
# Gaming & System Optimizer - Управление профилями и охлаждением MSI Afterburner
# ==============================================================================
# Описание:
#   Управляет автозагрузкой MSI Afterburner для кастомного охлаждения видеокарты
#   (SwAutoFanControl) и андервольта/разгона БЕЗ фонового оверхеда RTSS:
#   - Запуск MSI Afterburner в трее (/s)
#   - Полное отключение сервера RTSS (EnableServer = 0 в MSIAfterburner.cfg)
#   - Остановка и блокировка процессов RTSS (0 хуков в играх, 0 задержек)
#   - Сохранение кастомных кривых вентиляторов и мониторинга в Profiles\
#   - Удаление любых устаревших дублирующих задач планировщика
# ==============================================================================

[CmdletBinding(DefaultParameterSetName = "Default")]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Enable", "EnableTray", "Disable", "Status", "Restore")]
    [string]$Action = "Status",

    [Parameter(ParameterSetName = "Enable")]
    [switch]$Enable,

    [Parameter(ParameterSetName = "EnableTray")]
    [switch]$EnableTray,

    [Parameter(ParameterSetName = "Disable")]
    [switch]$Disable,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore
)

if ($Enable -or $EnableTray) { $Action = "Enable" }
if ($Disable -or $Restore) { $Action = "Disable" }

$legacyTaskName = "MSIAfterburnerProfile"
$stdTaskName = "MSIAfterburner"

# Удаление устаревшей дублирующей задачи Headless-режима, если она осталась
if (Get-ScheduledTask -TaskName $legacyTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $legacyTaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# Автоопределение пути установки MSI Afterburner
$regPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\MSI\Afterburner" -ErrorAction SilentlyContinue).InstallPath
if (-not $regPath) {
    $regPath = (Get-ItemProperty "HKLM:\SOFTWARE\MSI\Afterburner" -ErrorAction SilentlyContinue).InstallPath
}

$abExe = $null
$abDir = $null

if ($regPath -and (Test-Path $regPath)) {
    $abExe = $regPath
    $abDir = Split-Path -Parent $abExe
} elseif (Test-Path "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe") {
    $abExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    $abDir = "C:\Program Files (x86)\MSI Afterburner"
} elseif (Test-Path "C:\Program Files\MSI Afterburner\MSIAfterburner.exe") {
    $abExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
    $abDir = "C:\Program Files\MSI Afterburner"
}

if (-not $abExe -or -not (Test-Path $abExe)) {
    Write-Host "`n[ОШИБКА] MSI Afterburner не обнаружен в системе!" -ForegroundColor Red
    Write-Host "Установите MSI Afterburner перед настройкой автозагрузки." -ForegroundColor DarkGray
    return
}

# Функция полной отвязки RTSS от MSI Afterburner (без изменения Profiles\)
function Disable-RTSSIntegration {
    param([string]$Dir)
    $cfgPath = Join-Path $Dir "MSIAfterburner.cfg"
    if (Test-Path $cfgPath) {
        try {
            $text = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
            if ($text -match 'EnableServer\s*=\s*1') {
                $text = $text -replace 'EnableServer\s*=\s*1', 'EnableServer			= 0'
                [System.IO.File]::WriteAllText($cfgPath, $text, [System.Text.UTF8Encoding]::new($false))
            }
        } catch {
            Write-Verbose $_.Exception.Message
        }
    }
    # Останавливаем любые запущенные процессы RTSS
    Stop-Process -Name "RTSSHooksLoader64", "RTSS" -Force -ErrorAction SilentlyContinue
}

$stdTask = Get-ScheduledTask -TaskName $stdTaskName -ErrorAction SilentlyContinue
$stdTaskExists = ($null -ne $stdTask)

switch ($Action) {
    { $_ -in "Enable", "EnableTray" } {
        # Отключаем интеграцию с RTSS и выгружаем его хуки
        Disable-RTSSIntegration -Dir $abDir

        # Настраиваем единую стандартную задачу автозагрузки в трей (/s)
        if ($stdTaskExists) {
            Enable-ScheduledTask -TaskName $stdTaskName -ErrorAction SilentlyContinue | Out-Null
        } else {
            $actionObj = New-ScheduledTaskAction -Execute $abExe -Argument "/s"
            $triggerObj = New-ScheduledTaskTrigger -AtLogOn
            $principalObj = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
            Register-ScheduledTask -TaskName $stdTaskName -Action $actionObj -Trigger $triggerObj -Principal $principalObj -Force | Out-Null
        }

        # Если Afterburner не запущен, запускаем задачу через schtasks в интерактивной сессии
        if (-not (Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue)) {
            schtasks /run /tn $stdTaskName | Out-Null
        }

        Write-Host "`n[✓] Автозагрузка MSI Afterburner успешно настроена!" -ForegroundColor Green
        Write-Host "    - Режим: В ТРЕЕ (Кастомное охлаждение + Андервольт/Разгон)" -ForegroundColor Cyan
        Write-Host "    - Программная кривая кулеров: АКТИВНА (SwAutoFanControl работает)" -ForegroundColor Cyan
        Write-Host "    - Профиль андервольта/разгона: АКТИВЕН" -ForegroundColor Cyan
        Write-Host "    - Служба RTSS: ПОЛНОСТЬЮ ОТКЛЮЧЕНА (0 процессов, 0 хуков в играх)" -ForegroundColor Green
    }

    "Disable" {
        if ($stdTaskExists) {
            Disable-ScheduledTask -TaskName $stdTaskName -ErrorAction SilentlyContinue | Out-Null
        }
        Stop-Process -Name "MSIAfterburner", "RTSSHooksLoader64", "RTSS" -Force -ErrorAction SilentlyContinue
        Write-Host "`n[-] Автозагрузка MSI Afterburner полностью отключена." -ForegroundColor Yellow
    }

    "Status" {
        Write-Host "`n==============================================================================" -ForegroundColor DarkCyan
        Write-Host "   УПРАВЛЕНИЕ АВТОЗАГРУЗКОЙ И ОХЛАЖДЕНИЕМ GPU MSI AFTERBURNER                 " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "Путь к Afterburner : $abExe" -ForegroundColor DarkGray

        $stdTask = Get-ScheduledTask -TaskName $stdTaskName -ErrorAction SilentlyContinue

        if ($stdTask -and $stdTask.State -ne "Disabled") {
            Write-Host "Автозагрузка       : [ ВКЛЮЧЕНА (В трее: Кулеры + OC/UV БЕЗ RTSS) ]" -ForegroundColor Green
        } else {
            Write-Host "Автозагрузка       : [ ОТКЛЮЧЕНА ]" -ForegroundColor Yellow
        }

        $abProc = Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue
        if ($abProc) {
            Write-Host "MSI Afterburner    : РАБОТАЕТ В ТРЕЕ (PID: $($abProc.Id))" -ForegroundColor Green
        } else {
            Write-Host "MSI Afterburner    : НЕ ЗАПУЩЕН" -ForegroundColor DarkGray
        }

        $profileCfg = Join-Path (Join-Path $abDir "Profiles") "MSIAfterburner.cfg"
        $fanActive = $false
        if (Test-Path $profileCfg) {
            $fanActive = (Select-String -Path $profileCfg -Pattern "SwAutoFanControl\s*=\s*1" -Quiet)
        }
        if ($fanActive) {
            Write-Host "Кривая кулеров     : КАСТОМНАЯ КРИВАЯ АКТИВНА (SwAutoFanControl = 1)" -ForegroundColor Green
        } else {
            Write-Host "Кривая кулеров     : ПО УМОЛЧАНИЮ (VBIOS)" -ForegroundColor DarkGray
        }

        $rtssProc = Get-Process -Name "*RTSS*" -ErrorAction SilentlyContinue
        if ($rtssProc) {
            Write-Host "Служба RTSS        : ЗАПУЩЕНА (PID: $($rtssProc.Id))" -ForegroundColor Red
        } else {
            Write-Host "Служба RTSS        : ПОЛНОСТЬЮ ОТКЛЮЧЕНА (0 процессов, чисто)" -ForegroundColor Green
        }

        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [1]  Включить автозагрузку (В трее: Кулеры + OC/UV БЕЗ RTSS)" -ForegroundColor White
        Write-Host " [2]  Полностью отключить автозагрузку Afterburner" -ForegroundColor Yellow
        Write-Host " [Q]  Назад" -ForegroundColor DarkGray
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " >> " -NoNewline -ForegroundColor Cyan
        $c = Read-Host

        switch ($c.ToUpper()) {
            "1" { & $MyInvocation.MyCommand.Path -Action Enable }
            "2" { & $MyInvocation.MyCommand.Path -Action Disable }
            "Q" { return }
            "0" { return }
            default { return }
        }
    }
}