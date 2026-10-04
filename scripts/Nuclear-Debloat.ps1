# ==============================================================================
# Gaming & System Optimizer - ЯДЕРНАЯ ЗАЧИСТКА (Perfectionist XP Mode)
# ==============================================================================
Write-Host ">>> ЗАПУСК ПОЛНОЙ ЗАЧИСТКИ WINDOWS ДО УРОВНЯ WINDOWS XP..." -ForegroundColor Red
Write-Host "ВНИМАНИЕ: Это отключит обновления, защитник и все фоновые задачи!" -ForegroundColor Yellow

# 1. Удаление ВСЕХ задач в планировщике (ZOICWARE port)
Write-Host "Удаление всех запланированных задач..." -ForegroundColor Yellow
Get-ScheduledTask -TaskPath '*' | 
    Where-Object { $_.TaskName -notin @('SvcRestartTask', 'MsCtfMonitor') } | 
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# 2. Отключение Центра Обновлений Windows
Write-Host "Отключение Windows Update..." -ForegroundColor Yellow
Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service -Name UsoSvc -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service -Name WaaSMedicSvc -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue

# 3. Отключение Защитника Windows (Требуется SafeMode или TrustedInstaller)
Write-Host "Отключение Windows Defender..." -ForegroundColor Yellow
$defReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $defReg)) { New-Item $defReg -Force | Out-Null }
Set-ItemProperty $defReg -Name "DisableAntiSpyware" -Value 1 -Type DWord -ErrorAction SilentlyContinue

# 4. Перевод всех остальных служб в Manual (оставляем только сеть и ядро)
Write-Host "Перевод всех фоновых служб в ручной режим (Manual)..." -ForegroundColor Yellow
$servicesKeep = @(
    'AudioEndpointBuilder', 'Audiosrv', 'EventLog', 'SysMain', 'Themes', 'WSearch',
    'NVDisplay.ContainerLocalSystem', 'WlanSvc', 'BFE', 'BrokerInfrastructure',
    'CoreMessagingRegistrar', 'Dnscache', 'LSM', 'mpssvc', 'RpcEptMapper',
    'Schedule', 'SystemEventsBroker', 'StateRepository', 'TextInputManagementService', 'sppsvc',
    'Dhcp', 'LanmanServer', 'LanmanWorkstation', 'ProfSvc', 'Winmgmt'
)

Get-Service | Where-Object { $_.StartType -like '*Auto*' } | ForEach-Object {
    if ($servicesKeep -notcontains $_.Name) {
        Set-Service -Name $_.Name -StartupType Manual -ErrorAction SilentlyContinue
    }
}

Write-Host "[OK] Система очищена до состояния Windows XP!" -ForegroundColor Green