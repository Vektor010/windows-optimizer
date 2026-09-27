#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Выполняет глубокий аудит и экспорт полного перечня заданий планировщика Windows
#    (Task Scheduler) в структурированный файл формата JSON (scheduled-tasks.json).
#    Парсит метаданные заданий, текущий статус (State: Ready, Running, Disabled),
#    XML-манифесты (Export-ScheduledTask), принципалы безопасности (Principals),
#    триггеры запуска (Triggers), параметры расписания и обслуживания (Settings),
#    исполняемые действия (Actions) и динамически разрешает локализованные строковые
#    ресурсы MUI через Windows API (SHLoadIndirectString из shlwapi.dll).
#
# 2. ЗАЧЕМ:
#    Необходим для комплексного аудита телеметрии, скрытых автозагрузок, фоновых
#    служб обслуживания и шпионских задач Windows. Позволяет детально изучить
#    поведение каждого задания, права запуска (RunLevel, UserId), триггеры пробуждения
#    (WakeToRun) и ограничения времени (ExecutionTimeLimit) перед их отключением.
#
# 3. ПОСЛЕДСТВИЯ:
#    Диагностический режим только для чтения (Read-Only). Не вносит изменений
#    в реестр, службы или конфигурации планировщика. Создаёт/обновляет файл отчёта
#    в формате JSON с гарантированной кодировкой UTF-8 без повреждения спецсимволов.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+. Не требует повышенных привилегий для базового
#    аудита (хотя запуск от Администратора позволяет прочесть защищённые системные задачи).
#
# 5. ОТКАТ:
#    Не требуется, так как скрипт является диагностическим инструментом только
#    для чтения (Read-Only). Для удаления отчёта достаточно удалить сгенерированный
#    файл scheduled-tasks.json.
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
    [Parameter(Position = 0)]
    [string]$OutputPath = 'scheduled-tasks.json',

    [Parameter()]
    [string]$TaskPath = '*',

    [Parameter()]
    [string]$TaskName = '*',

    [Parameter()]
    [ValidateSet('Any', 'Ready', 'Running', 'Disabled')]
    [string]$State = 'Any',

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Quiet
)

# Безопасное подключение Win32 API SHLoadIndirectString для разрешения MUI-строк
if (-not ([System.Management.Automation.PSTypeName]'ind').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ind {
    [DllImport("Shlwapi.dll", CharSet=CharSet.Unicode)]
    public static extern int SHLoadIndirectString(string pszSource, StringBuilder pszOutBuf, int cchOutBuf, IntPtr pvReserved);
}
'@ -ErrorAction SilentlyContinue | Out-Null
}

function tdesc {
    param([string]$v)
    if ([string]::IsNullOrWhiteSpace($v)) { return $v }
    if ($v -match '^\$\(@(.+)\)$') { $v = '@' + $matches[1] }
    $v = [Environment]::ExpandEnvironmentVariables($v)

    if ($v -notmatch '^@') { return $v }
    $sb = New-Object System.Text.StringBuilder 2048
    $hr = [ind]::SHLoadIndirectString($v, $sb, $sb.Capacity, [IntPtr]::Zero)
    if ($hr -eq 0) { return $sb.ToString() }
    return $v
}

function addv {
    param([hashtable]$h, [string]$n, $v)
    if ($null -eq $v) { return }
    if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) { return }
    if ($v -is [System.Array] -and $v.Count -eq 0) { return }
    $h[$n] = $v
}

function enames {
    param($n)
    if (-not $n) { return @() }
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($c in $n.ChildNodes) {
        if ($c.NodeType -eq 'Element') { $list.Add($c.LocalName) }
    }
    $list.ToArray()
}

function etexts {
    param($n)
    if (-not $n) { return @() }
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($c in $n.ChildNodes) {
        if ($c.NodeType -eq 'Element') { $list.Add([string]$c) }
    }
    $list.ToArray()
}

function prinfo {
    param($pn)
    if (-not $pn) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($p in $pn.Principal) {
        if (-not $p) { continue }
        $item = @{}
        addv $item 'Id' ([string]$p.Id)
        addv $item 'UserId' ([string]$p.UserId)
        addv $item 'GroupId' ([string]$p.GroupId)
        addv $item 'DisplayName' ([string]$p.DisplayName)
        addv $item 'LogonType' ([string]$p.LogonType)
        addv $item 'RunLevel' ([string]$p.RunLevel)
        addv $item 'ProcessTokenSidType' ([string]$p.ProcessTokenSidType)
        if ($p.RequiredPrivileges) {
            $privs = New-Object System.Collections.Generic.List[string]
            foreach ($priv in $p.RequiredPrivileges.Privilege) {
                $text = [string]$priv
                if ($text) { $privs.Add($text) }
            }
            addv $item 'RequiredPrivileges' $privs
        }
        if ($item.Count -gt 0) { $list.Add([pscustomobject]$item) }
    }
    $list.ToArray()
}

function setinfo {
    param($sn)
    if (-not $sn) { return $null }
    $item = @{}
    addv $item 'AllowStartOnDemand' ([string]$sn.AllowStartOnDemand)
    addv $item 'DisallowStartIfOnBatteries' ([string]$sn.DisallowStartIfOnBatteries)
    addv $item 'StopIfGoingOnBatteries' ([string]$sn.StopIfGoingOnBatteries)
    addv $item 'WakeToRun' ([string]$sn.WakeToRun)
    addv $item 'RunOnlyIfNetworkAvailable' ([string]$sn.RunOnlyIfNetworkAvailable)
    addv $item 'RunOnlyIfIdle' ([string]$sn.RunOnlyIfIdle)
    addv $item 'StartWhenAvailable' ([string]$sn.StartWhenAvailable)
    addv $item 'Enabled' ([string]$sn.Enabled)
    addv $item 'Hidden' ([string]$sn.Hidden)
    addv $item 'ExecutionTimeLimit' ([string]$sn.ExecutionTimeLimit)
    addv $item 'Priority' ([string]$sn.Priority)
    addv $item 'MultipleInstancesPolicy' ([string]$sn.MultipleInstancesPolicy)
    addv $item 'UseUnifiedSchedulingEngine' ([string]$sn.UseUnifiedSchedulingEngine)

    if ($sn.IdleSettings) {
        $idle = @{}
        addv $idle 'Duration' ([string]$sn.IdleSettings.Duration)
        addv $idle 'WaitTimeout' ([string]$sn.IdleSettings.WaitTimeout)
        addv $idle 'StopOnIdleEnd' ([string]$sn.IdleSettings.StopOnIdleEnd)
        addv $idle 'RestartOnIdle' ([string]$sn.IdleSettings.RestartOnIdle)
        if ($idle.Count -gt 0) { $item['IdleSettings'] = $idle }
    }

    if ($sn.NetworkSettings) {
        $net = @{}
        addv $net 'Name' ([string]$sn.NetworkSettings.Name)
        addv $net 'Id' ([string]$sn.NetworkSettings.Id)
        if ($net.Count -gt 0) { $item['NetworkSettings'] = $net }
    }

    if ($sn.MaintenanceSettings) {
        $maint = @{}
        addv $maint 'Period' ([string]$sn.MaintenanceSettings.Period)
        addv $maint 'Deadline' ([string]$sn.MaintenanceSettings.Deadline)
        addv $maint 'Exclusive' ([string]$sn.MaintenanceSettings.Exclusive)
        if ($maint.Count -gt 0) { $item['MaintenanceSettings'] = $maint }
    }

    if ($sn.RestartOnFailure) {
        $rof = @{}
        addv $rof 'Interval' ([string]$sn.RestartOnFailure.Interval)
        addv $rof 'Count' ([string]$sn.RestartOnFailure.Count)
        if ($rof.Count -gt 0) { $item['RestartOnFailure'] = $rof }
    }

    if ($item.Count -gt 0) { [pscustomobject]$item } else { $null }
}

function triginfo {
    param($tn)
    if (-not $tn) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($t in $tn.ChildNodes) {
        if ($t.NodeType -ne 'Element') { continue }
        $item = @{}
        addv $item 'Type' $t.LocalName
        addv $item 'Enabled' ([string]$t.Enabled)
        addv $item 'StartBoundary' ([string]$t.StartBoundary)
        addv $item 'EndBoundary' ([string]$t.EndBoundary)
        addv $item 'ExecutionTimeLimit' ([string]$t.ExecutionTimeLimit)
        addv $item 'Delay' ([string]$t.Delay)
        addv $item 'RandomDelay' ([string]$t.RandomDelay)
        addv $item 'UserId' ([string]$t.UserId)
        addv $item 'LogonType' ([string]$t.LogonType)
        addv $item 'StateChange' ([string]$t.StateChange)
        addv $item 'Subscription' ([string]$t.Subscription)

        if ($t.Repetition) {
            $rep = @{}
            addv $rep 'Interval' ([string]$t.Repetition.Interval)
            addv $rep 'Duration' ([string]$t.Repetition.Duration)
            addv $rep 'StopAtDurationEnd' ([string]$t.Repetition.StopAtDurationEnd)
            if ($rep.Count -gt 0) { $item['Repetition'] = $rep }
        }

        if ($t.ScheduleByDay) {
            addv $item 'DaysInterval' ([string]$t.ScheduleByDay.DaysInterval)
        }

        if ($t.ScheduleByWeek) {
            $week = @{}
            addv $week 'WeeksInterval' ([string]$t.ScheduleByWeek.WeeksInterval)
            addv $week 'DaysOfWeek' (enames $t.ScheduleByWeek.DaysOfWeek)
            if ($week.Count -gt 0) { $item['ScheduleByWeek'] = $week }
        }

        if ($t.ScheduleByMonth) {
            $month = @{}
            addv $month 'DaysOfMonth' (etexts $t.ScheduleByMonth.DaysOfMonth)
            addv $month 'Months' (enames $t.ScheduleByMonth.Months)
            if ($month.Count -gt 0) { $item['ScheduleByMonth'] = $month }
        }

        if ($t.ScheduleByMonthDayOfWeek) {
            $mdw = @{}
            addv $mdw 'DaysOfWeek' (enames $t.ScheduleByMonthDayOfWeek.DaysOfWeek)
            addv $mdw 'WeeksOfMonth' (enames $t.ScheduleByMonthDayOfWeek.WeeksOfMonth)
            addv $mdw 'Months' (enames $t.ScheduleByMonthDayOfWeek.Months)
            if ($mdw.Count -gt 0) { $item['ScheduleByMonthDayOfWeek'] = $mdw }
        }

        if ($item.Count -gt 0) { $list.Add([pscustomobject]$item) }
    }
    $list.ToArray()
}

function actinfo {
    param($an)
    if (-not $an) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($a in $an.ChildNodes) {
        if ($a.NodeType -ne 'Element') { continue }
        $item = @{}
        addv $item 'Type' $a.LocalName
        addv $item 'Id' ([string]$a.Id)
        addv $item 'Command' ([string]$a.Command)
        addv $item 'Arguments' ([string]$a.Arguments)
        addv $item 'WorkingDirectory' ([string]$a.WorkingDirectory)
        addv $item 'ClassId' ([string]$a.ClassId)
        addv $item 'Data' ([string]$a.Data)
        addv $item 'To' ([string]$a.To)
        addv $item 'From' ([string]$a.From)
        addv $item 'Subject' ([string]$a.Subject)
        addv $item 'Body' ([string]$a.Body)
        addv $item 'Server' ([string]$a.Server)
        addv $item 'Header' ([string]$a.Header)
        addv $item 'Attachment' ([string]$a.Attachment)
        if ($item.Count -gt 0) { $list.Add([pscustomobject]$item) }
    }
    $list.ToArray()
}

# Сбор запланированных задач с учётом фильтрации
$taskParams = @{}
if ($TaskPath -ne '*' -and -not [string]::IsNullOrWhiteSpace($TaskPath)) {
    $taskParams['TaskPath'] = $TaskPath
}
if ($TaskName -ne '*' -and -not [string]::IsNullOrWhiteSpace($TaskName)) {
    $taskParams['TaskName'] = $TaskName
}

$tasks = Get-ScheduledTask @taskParams
if ($State -ne 'Any') {
    $tasks = $tasks | Where-Object { $_.State.ToString() -eq $State }
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($t in $tasks) {
    $xt = $null
    $x = $null
    try {
        $xt = Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
        $x = [xml]$xt
    }
    catch {
        # Исключения подавляются для защищённых/виртуальных системных задач Windows
        $null = $_
    }

    $reg = if ($x) { $x.Task.RegistrationInfo } else { $null }
    $raw = if ($reg -and $reg.Description) { $reg.Description } else { $t.Description }

    $rows.Add([pscustomobject]@{
        Name             = $t.TaskName
        Path             = $t.TaskPath
        State            = $t.State.ToString()
        Description      = (tdesc $raw)
        Author           = if ($reg -and $reg.Author) { [string]$reg.Author } elseif ($t.Author) { [string]$t.Author } else { $null }
        URI              = if ($reg -and $reg.URI) { [string]$reg.URI } elseif ($t.URI) { [string]$t.URI } else { $null }
        RegistrationInfo = if ($reg) {
            $r = @{}
            addv $r 'Author' ([string]$reg.Author)
            addv $r 'URI' ([string]$reg.URI)
            addv $r 'Date' ([string]$reg.Date)
            addv $r 'SecurityDescriptor' ([string]$reg.SecurityDescriptor)
            addv $r 'Source' ([string]$reg.Source)
            addv $r 'Version' ([string]$reg.Version)
            if ($r.Count -gt 0) { [pscustomobject]$r } else { $null }
        } else { $null }
        Principals       = if ($x) { prinfo $x.Task.Principals } else { @() }
        Settings         = if ($x) { setinfo $x.Task.Settings } else { $null }
        Triggers         = if ($x) { triginfo $x.Task.Triggers } else { @() }
        Actions          = if ($x) { actinfo $x.Task.Actions } else { @() }
    })
}

# Разрешение пути для сохранения файла
$targetPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} elseif (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    [System.IO.Path]::Combine($PSScriptRoot, $OutputPath)
} else {
    [System.IO.Path]::Combine($PWD.Path, $OutputPath)
}

$targetDir = [System.IO.Path]::GetDirectoryName($targetPath)
if (-not [string]::IsNullOrWhiteSpace($targetDir) -and -not (Test-Path -LiteralPath $targetDir)) {
    [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
}

$json = $rows.ToArray() | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($targetPath, $json, [System.Text.Encoding]::UTF8)

if (-not $Quiet) {
    Write-Host "[+] Экспорт планировщика заданий Windows успешно завершён." -ForegroundColor Green
    Write-Host "[+] Обработано заданий: $($rows.Count)" -ForegroundColor Green
    Write-Host "[i] Файл отчёта (UTF-8): $targetPath" -ForegroundColor Cyan
}

if ($PassThru) {
    return $rows.ToArray()
}
