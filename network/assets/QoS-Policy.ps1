# ==============================================================================
# Noverse Research - Управление политиками качества обслуживания (Policy-based QoS & DSCP)
# Документация: https://noverse.dev/docs/win-config/network/qos-policy/
# Официальный источник: Nohuto (https://github.com/nohuto/win-config/blob/main/network/qos-policy.md)
# ==============================================================================
# Назначение:
#   Создает групповые политики качества обслуживания (Policy-based QoS) на уровне ядра Windows.
#   Присваивает исходящему сетевому трафику выбранной игры метку DSCP 46 (Expedited Forwarding),
#   обеспечивающую наивысший приоритет маршрутизации пакетов в сетевом оборудовании.
#
# Параметры политики (HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\<PolicyName>):
#   - Version = "1.0" (REG_SZ)
#   - Application Name = "<AppName.exe>" (REG_SZ) : исполняемый файл процесса
#   - Protocol = "*" (REG_SZ) : фильтрация для всех протоколов (TCP и UDP)
#   - Local Port = "*" (REG_SZ) : любой локальный порт отправителя
#   - Local IP = "*" (REG_SZ) : любой локальный IP-адрес интерфейса
#   - Local IP Prefix Length = "*" (REG_SZ)
#   - Remote Port = "*" (REG_SZ) : любой удаленный порт игрового сервера
#   - Remote IP = "*" (REG_SZ) : любой удаленный IP-адрес сервера
#   - Remote IP Prefix Length = "*" (REG_SZ)
#   - DSCP Value = "46" (REG_SZ) : метка наивысшего приоритета Expedited Forwarding (EF)
#   - Throttle Rate = "-1" (REG_SZ) : отключение ограничения скорости передачи
#
# Системный параметр (HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS):
#   - Do not use NLA = "1" (REG_SZ) : отключение зависимости от Network Location Awareness,
#     позволяющее применять политики DSCP в домашних и рабочих группах (Workgroup), а не только в домене AD.
# ==============================================================================

param (
    [string]$PolicyName,
    [string]$ApplicationName,
    [string]$DSCP = "46",
    [switch]$List,
    [switch]$Remove,
    [switch]$Restore
)

$qosBasePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS"
$tcpipQosPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS"

# ------------------------------------------------------------------------------
# Функция вывода списка активных политик QoS
# ------------------------------------------------------------------------------
function Get-QoSPolicyList {
    if (-not (Test-Path $qosBasePath)) {
        Write-Host " [i] Активные политики QoS отсутствуют в реестре." -ForegroundColor DarkGray
        return @()
    }
    $policies = Get-ChildItem -Path $qosBasePath -ErrorAction SilentlyContinue
    if (-not $policies -or $policies.Count -eq 0) {
        Write-Host " [i] Активные политики QoS отсутствуют в реестре." -ForegroundColor DarkGray
        return @()
    }
    $res = foreach ($p in $policies) {
        $props = Get-ItemProperty -Path $p.PSPath -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            PolicyName      = $p.PSChildName
            ApplicationName = $props."Application Name"
            DSCPValue       = $props."DSCP Value"
            Protocol        = $props.Protocol
            ThrottleRate    = $props."Throttle Rate"
        }
    }
    $res
}

# ------------------------------------------------------------------------------
# Функция создания политики QoS
# ------------------------------------------------------------------------------
function Add-QoSPolicyInternal {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$AppExe,
        [string]$DscpVal = "46"
    )

    $policyPath = Join-Path $qosBasePath $Name
    if (-not (Test-Path $policyPath)) {
        New-Item -Path $qosBasePath -Name $Name -Force | Out-Null
    }

    Set-ItemProperty -Path $policyPath -Name "Version" -Value "1.0" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Application Name" -Value $AppExe -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Protocol" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Local Port" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Local IP" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Local IP Prefix Length" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Remote Port" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Remote IP" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Remote IP Prefix Length" -Value "*" -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "DSCP Value" -Value $DscpVal -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "Throttle Rate" -Value "-1" -Type String -Force

    # Включение поддержки QoS без контроллера домена (Workgroup / NLA)
    if (-not (Test-Path $tcpipQosPath)) {
        New-Item -Path $tcpipQosPath -Force | Out-Null
    }
    Set-ItemProperty -Path $tcpipQosPath -Name "Do not use NLA" -Type String -Value "1" -Force

    Write-Host " [+] Политика QoS '$Name' успешно создана:" -ForegroundColor Green
    Write-Host "     Исполняемый файл: $AppExe" -ForegroundColor Cyan
    Write-Host "     Значение DSCP:    $DscpVal (Expedited Forwarding, наивысший приоритет)" -ForegroundColor Cyan
    Write-Host "     Параметр NLA:     Do not use NLA = 1 (включено)" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# Вспомогательная функция удаления политики QoS
# ------------------------------------------------------------------------------
function Invoke-QoSPolicyRemoval {
    param([Parameter(Mandatory=$true)][string]$Name)
    $policyPath = Join-Path $qosBasePath $Name
    if (Test-Path $policyPath) {
        Remove-Item -Path $policyPath -Recurse -Force
        Write-Host " [+] Политика QoS '$Name' успешно удалена." -ForegroundColor Yellow
    } else {
        Write-Host " [!] Политика QoS '$Name' не найдена в реестре." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# Режимы автоматизации (CLI)
# ------------------------------------------------------------------------------
if ($List) {
    Write-Host ">>> Список активных политик QoS в реестре Windows:" -ForegroundColor Cyan
    Get-QoSPolicyList | Format-Table -AutoSize
    return
}

if ($Restore) {
    Write-Host "`n[ОТКАТ] Удаление всех пользовательских политик QoS..." -ForegroundColor Yellow
    if (Test-Path $qosBasePath) {
        Remove-Item -Path $qosBasePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " [+] Раздел групповых политик QoS очищен." -ForegroundColor Green
    }
    if (Test-Path $tcpipQosPath) {
        Remove-ItemProperty -Path $tcpipQosPath -Name "Do not use NLA" -ErrorAction SilentlyContinue
        Write-Host " [+] Параметр 'Do not use NLA' удален." -ForegroundColor Green
    }
    Write-Host "`n[✓] Откат политик QoS завершен!" -ForegroundColor Green
    return
}

if ($Remove -and $PolicyName) {
    Invoke-QoSPolicyRemoval -Name $PolicyName
    return
}

if ($PolicyName -and $ApplicationName) {
    if (-not $ApplicationName.ToLower().EndsWith(".exe")) {
        $ApplicationName = "$ApplicationName.exe"
    }
    Add-QoSPolicyInternal -Name $PolicyName -AppExe $ApplicationName -DscpVal $DSCP
    return
}

# ------------------------------------------------------------------------------
# Интерактивное меню настройки (при запуске без аргументов)
# ------------------------------------------------------------------------------
while ($true) {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "       НАСТРОЙКА ПРИОРИТЕТА ИГРОВОГО ТРАФИКА (QoS / DSCP 46 EF)              " -ForegroundColor Cyan
    Write-Host "        Документация: noverse.dev/docs/win-config/network/qos-policy/        " -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan

    $active = Get-QoSPolicyList
    if ($active.Count -gt 0) {
        Write-Host "Активные политики в системе:" -ForegroundColor Yellow
        $active | Format-Table -AutoSize
    } else {
        Write-Host "Активные политики QoS в данный момент отсутствуют.`n" -ForegroundColor DarkGray
    }

    Write-Host "Выберите готовый игровой профиль или введите свой процесс:" -ForegroundColor White
    Write-Host " [1]  Counter-Strike 2 (cs2.exe)" -ForegroundColor White
    Write-Host " [2]  VALORANT (VALORANT-Win64-Shipping.exe)" -ForegroundColor White
    Write-Host " [3]  Fortnite (FortniteClient-Win64-Shipping.exe)" -ForegroundColor White
    Write-Host " [4]  Apex Legends (r5apex.exe)" -ForegroundColor White
    Write-Host " [5]  Overwatch 2 (Overwatch.exe)" -ForegroundColor White
    Write-Host " [6]  Ввести имя процесса вручную (e.g. Discord.exe, Dota2.exe)" -ForegroundColor White
    Write-Host " [7]  Удалить существующую политику QoS" -ForegroundColor White
    Write-Host " [8]  Сбросить все политики QoS (Откат)" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " [0]  Назад / Выход" -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan

    $choice = Read-Host "Выберите действие [0-8]"
    switch ($choice) {
        "1" { Add-QoSPolicyInternal -Name "CS2" -AppExe "cs2.exe" -DscpVal "46"; Start-Sleep -Milliseconds 1500 }
        "2" { Add-QoSPolicyInternal -Name "VALORANT" -AppExe "VALORANT-Win64-Shipping.exe" -DscpVal "46"; Start-Sleep -Milliseconds 1500 }
        "3" { Add-QoSPolicyInternal -Name "Fortnite" -AppExe "FortniteClient-Win64-Shipping.exe" -DscpVal "46"; Start-Sleep -Milliseconds 1500 }
        "4" { Add-QoSPolicyInternal -Name "ApexLegends" -AppExe "r5apex.exe" -DscpVal "46"; Start-Sleep -Milliseconds 1500 }
        "5" { Add-QoSPolicyInternal -Name "Overwatch" -AppExe "Overwatch.exe" -DscpVal "46"; Start-Sleep -Milliseconds 1500 }
        "6" {
            $pName = Read-Host "`nВведите краткое имя политики (например, CustomGame)"
            $pExe = Read-Host "Введите точное имя исполняемого файла (например, game.exe)"
            if (-not [string]::IsNullOrWhiteSpace($pName) -and -not [string]::IsNullOrWhiteSpace($pExe)) {
                if (-not $pExe.ToLower().EndsWith(".exe")) { $pExe = "$pExe.exe" }
                Add-QoSPolicyInternal -Name $pName -AppExe $pExe -DscpVal "46"
            } else {
                Write-Host " [-] Имя политики или файла не может быть пустым." -ForegroundColor Red
            }
            Start-Sleep -Milliseconds 1500
        }
        "7" {
            $delName = Read-Host "`nВведите имя политики для удаления"
            if (-not [string]::IsNullOrWhiteSpace($delName)) {
                Invoke-QoSPolicyRemoval -Name $delName
            }
            Start-Sleep -Milliseconds 1200
        }
        "8" {
            if (Test-Path $qosBasePath) { Remove-Item -Path $qosBasePath -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tcpipQosPath) { Remove-ItemProperty -Path $tcpipQosPath -Name "Do not use NLA" -ErrorAction SilentlyContinue }
            Write-Host "`n[+] Все политики QoS удалены, дефолт восстановлен." -ForegroundColor Green
            Start-Sleep -Milliseconds 1500
        }
        "0" { return }
    }
}