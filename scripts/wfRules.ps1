#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Управляет политиками, профилями и правилами Брандмауэра Защитника Windows:
#    - Режим -Outbound (-o, --outbound): настраивает строгую блокировку входящего трафика
#      (DefaultInboundAction Block) и разрешает исходящий трафик приложений
#      (DefaultOutboundAction Allow). Включает журналирование заблокированных пакетов.
#    - Режим -Apply (-a, --apply): строгий режим белого списка (блокировка входящего и
#      исходящего трафика), отключает нежелательные встроенные правила телеметрии и фоновых
#      служб Windows (AllJoyn, Cast, Delivery Optimization, mDNS, Teredo и др.),
#      создаёт изолированную группу управляемых правил ($ManagedGroup).
#    - Режим -Reset (-r, --reset): сбрасывает все конфигурации брандмауэра к исходным
#      заводским настройкам Windows по умолчанию (netsh advfirewall reset).
#    - Режим -Status (-s, --status): отображает текущее состояние профилей и число правил группы.
#
# 2. ЗАЧЕМ:
#    Обеспечивает высокий уровень сетевой безопасности и приватности, устраняет
#    уязвимости удалённого доступа, пресекает передачу телеметрии и фоновую сетевую
#    активность встроенных служб Windows без ущерба для скорости соединения.
#
# 3. ПОСЛЕДСТВИЯ:
#    - Режим -Outbound (-o): безопасен для повседневного использования; блокирует
#      входящие соединения извне, сохраняя доступ браузеров и игр в интернет.
#    - Режим -Apply (-a): режим параноидальной безопасности; блокирует ВСЕ исходящие
#      соединения для любых программ, не включённых явно в $rules.
#    - Ведёт системный лог в %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Требуются права Администратора.
#    Полная поддержка Windows PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Запуск скрипта с параметром -Reset (-r, --reset) возвращает политики брандмауэра
#    к исходным системным настройкам Windows.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий System / win-config:
#    https://github.com/system-optimizer
#    Документация Optimizer:
#    Gaming & System Optimizer Reference
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter()]
    [Alias('a', '-apply')]
    [switch]$Apply,

    [Parameter()]
    [Alias('r', 'restore', '-reset')]
    [switch]$Reset,

    [Parameter()]
    [Alias('o', '-outbound')]
    [switch]$Outbound,

    [Parameter()]
    [Alias('s', '-status')]
    [switch]$Status,

    [Parameter()]
    [Alias('g', '-managed-group')]
    [string]$ManagedGroup = 'Optimizer Rules',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

# Проверка повышенных привилегий (Администратор)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Требуются права Администратора для управления Брандмауэром Windows.'
}

# Обработка POSIX-аргументов командной строки (--apply, --reset, --outbound, --status, --managed-group)
if ($Arguments) {
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            '--apply' { $Apply = $true }
            '--reset' { $Reset = $true }
            '--outbound' { $Outbound = $true }
            '--status' { $Status = $true }
            '--managed-group' {
                $i++
                if ($i -ge $Arguments.Count) { throw '--managed-group requires a value' }
                $ManagedGroup = $Arguments[$i]
            }
            default { throw "Unsupported argument: $($Arguments[$i])" }
        }
    }
}

# Шаблоны правил встроенных служб Windows, отключаемых в режиме -Apply
$disableExistingRulePatterns = @(
    @{ Pattern = 'AllJoyn Router*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Cast to Device*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Cloud Identity*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Connected Devices Platform*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Connected User Experiences and Telemetry*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Core Networking - Teredo*'; Direction = 'Outbound' },
    @{ Pattern = 'Delivery Optimization*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'DIAL protocol server*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'File and Printer Sharing*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Core Networking*'; Direction = 'Inbound' },
    @{ Pattern = 'Microsoft Media Foundation Network*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'mDNS*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Network Discovery*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Proximity sharing over TCP*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Recommended Troubleshooting Client*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Remote Assistance*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'WFD ASP Coordination Protocol*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'WFD Driver-only*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Wi-Fi*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Wireless Display*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Windows Device Management*'; Direction = @('Inbound', 'Outbound') },
    @{ Pattern = 'Windows Feature Experience Pack'; Direction = @('Inbound', 'Outbound') }
)

# Автоопределение пути установки Steam
$steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name 'InstallPath' -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Valve\Steam' -Name 'SteamPath' -ErrorAction SilentlyContinue).SteamPath
}
if (-not $steamPath -or -not (Test-Path -LiteralPath $steamPath)) {
    $steamPath = 'C:\Program Files (x86)\Steam'
}

# Пользовательский список разрешённых/заблокированных правил Optimizer
$rules = @(
    # Outbound allow
    @{ DisplayName = 'Git Remote HTTPS'; Direction = 'Outbound'; Action = 'Allow'; Program = 'C:\Program Files\Git\mingw64\libexec\git-core\git-remote-https.exe'; Protocol = 'TCP'; RemotePort = @('443') },
    @{ DisplayName = 'Steam'; Direction = 'Outbound'; Action = 'Allow'; Program = (Join-Path $steamPath 'steam.exe'); Protocol = 'TCP'; RemotePort = @('443') },
    @{ DisplayName = 'Cryptographic Services'; Direction = 'Outbound'; Action = 'Allow'; Program = '%SystemRoot%\System32\svchost.exe'; Service = 'CryptSvc'; Protocol = 'TCP'; RemotePort = @('80') },
    @{ DisplayName = 'svchost HTTP/S'; Direction = 'Outbound'; Action = 'Allow'; Program = '%SystemRoot%\System32\svchost.exe'; Protocol = 'TCP'; RemotePort = @('80', '443'); Enabled = 'False' },

    # Outbound block
    @{ DisplayName = 'Steam CEF'; Direction = 'Outbound'; Action = 'Block'; Program = (Join-Path $steamPath 'bin\cef\cef.win64\steamwebhelper.exe') },

    # Inbound block
    @{ DisplayName = 'Spotify'; Direction = 'Inbound'; Action = 'Block'; Program = '%APPDATA%\Spotify\Spotify.exe' },
    @{ DisplayName = 'Steam CEF'; Direction = 'Inbound'; Action = 'Block'; Program = (Join-Path $steamPath 'bin\cef\cef.win64\steamwebhelper.exe') }
)

function getEnabledFirewallRules {
    Get-NetFirewallRule -PolicyStore ActiveStore -Enabled True -Direction Inbound, Outbound -ErrorAction Stop
}

function convertToStringArray {
    param([object]$value)

    if ($null -eq $value) { return @() }
    if ($value -is [System.Array]) {
        $list = [System.Collections.Generic.List[string]]::new($value.Count)
        foreach ($item in $value) {
            $text = "$item".Trim()
            if ($text) { $list.Add($text) }
        }
        return $list.ToArray()
    }

    $text = "$value".Trim()
    if (-not $text) { return @() }
    return @($text)
}

function testRuleValuePattern {
    param([object]$value, [object]$pattern)

    $patterns = @(convertToStringArray $pattern)
    if (-not $patterns.Count) { return $true }

    $text = if ($null -eq $value) { '' } else { "$value" }
    foreach ($item in $patterns) {
        if ($text -like $item) { return $true }
    }
    return $false
}

function testRuleTextPattern {
    param([Parameter(Mandatory)][object]$rule, [Parameter(Mandatory)][object]$pattern)

    return (
        (testRuleValuePattern -value $rule.Name -pattern $pattern) -or
        (testRuleValuePattern -value $rule.DisplayName -pattern $pattern) -or
        (testRuleValuePattern -value $rule.DisplayGroup -pattern $pattern) -or
        (testRuleValuePattern -value $rule.Group -pattern $pattern)
    )
}

function testRulePattern {
    param([Parameter(Mandatory)][object]$rule, [Parameter(Mandatory)][object]$pattern)

    if ($pattern -is [string]) {
        return (testRuleTextPattern -rule $rule -pattern $pattern)
    }

    if ($pattern -isnot [hashtable]) {
        throw 'Disable patterns must be strings or hashtables'
    }

    foreach ($key in $pattern.Keys) {
        if ($key -eq 'Pattern') {
            if (-not (testRuleTextPattern -rule $rule -pattern $pattern[$key])) {
                return $false
            }
            continue
        }

        switch ($key) {
            'Name' {}
            'DisplayName' {}
            'DisplayGroup' {}
            'Group' {}
            'Direction' {}
            'Action' {}
            default { throw "Unsupported disable pattern key: $key" }
        }

        if (-not (testRuleValuePattern -value $rule.$key -pattern $pattern[$key])) {
            return $false
        }
    }
    return $true
}

function testRuleMatchesDisablePattern {
    param([Parameter(Mandatory)][object]$rule)

    foreach ($pattern in $disableExistingRulePatterns) {
        if (testRulePattern -rule $rule -pattern $pattern) { return $true }
    }
    return $false
}

function writeRuleLog {
    param(
        [Parameter(Mandatory)][object]$rule,
        [string]$status
    )

    $name = if ($rule.DisplayName) { $rule.DisplayName } else { $rule.Name }
    $direction = if ($rule.Direction) { $rule.Direction } else { 'Any' }
    $action = if ($status) { $status } elseif ($rule.Action -eq 'Allow') { 'allowed' } elseif ($rule.Action -eq 'Block') { 'blocked' } else { $rule.Action }
    Write-Host "$name | $direction | $action"
}

function disableExistingRules {
    $disabledRuleNames = @{}
    $matched = $false

    foreach ($rule in (getEnabledFirewallRules)) {
        if (-not (testRuleMatchesDisablePattern -rule $rule)) { continue }

        $matched = $true
        if (-not $disabledRuleNames.ContainsKey($rule.Name)) {
            $null = Disable-NetFirewallRule -Name $rule.Name -ErrorAction Stop
            $disabledRuleNames[$rule.Name] = $true
            writeRuleLog -rule $rule -status 'blocked'
        }
    }

    if (-not $matched) {
        Write-Host 'No enabled firewall rules matched disable patterns'
    }
}

function removeManagedRules {
    $removedRuleNames = @{}
    foreach ($rule in (Get-NetFirewallRule -PolicyStore PersistentStore -ErrorAction SilentlyContinue)) {
        if (($rule.DisplayGroup -ne $ManagedGroup -and $rule.Group -ne $ManagedGroup) -or $removedRuleNames.ContainsKey($rule.Name)) {
            continue
        }

        $null = Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
        $removedRuleNames[$rule.Name] = $true
    }
}

function resolveRulePrograms {
    param([Parameter(Mandatory)][string]$program)

    $expandedProgram = [Environment]::ExpandEnvironmentVariables($program)
    $programs = [System.Collections.Generic.List[string]]::new()

    if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($expandedProgram)) {
        foreach ($item in (Get-ChildItem -Path $expandedProgram -File -ErrorAction SilentlyContinue)) {
            $programs.Add($item.FullName)
        }
        return $programs.ToArray()
    }

    if ([System.IO.File]::Exists($expandedProgram)) {
        $programs.Add([System.IO.Path]::GetFullPath($expandedProgram))
    }

    return $programs.ToArray()
}

function addManagedRules {
    removeManagedRules

    foreach ($rule in $rules) {
        $baseParams = $rule.Clone()
        if (-not $baseParams.ContainsKey('Group')) { $baseParams['Group'] = $ManagedGroup }
        if (-not $baseParams.ContainsKey('Profile')) { $baseParams['Profile'] = 'Any' }
        if (-not $baseParams.ContainsKey('Enabled')) { $baseParams['Enabled'] = 'True' }

        if ($baseParams.ContainsKey('Program')) {
            $resolvedPrograms = resolveRulePrograms -program $baseParams['Program']
            if (-not $resolvedPrograms.Count) {
                Write-Host "Missing EXE: $($baseParams['Program'])"
                continue
            }

            foreach ($resolvedProgram in $resolvedPrograms) {
                $params = $baseParams.Clone()
                $params['Program'] = $resolvedProgram
                $null = New-NetFirewallRule @params
                writeRuleLog -rule $params
            }
            continue
        }

        $null = New-NetFirewallRule @baseParams
        writeRuleLog -rule $baseParams
    }
}

function setBlockedProfiles {
    Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True `
        -DefaultInboundAction Block -DefaultOutboundAction Block `
        -NotifyOnListen False -AllowInboundRules True -AllowLocalFirewallRules True `
        -AllowLocalIPsecRules True -AllowUnicastResponseToMulticast False `
        -EnableStealthModeForIPsec True `
        -LogFileName '%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log' `
        -LogMaxSizeKilobytes 16384 -LogBlocked True -LogIgnored True
}

function setOutboundProfiles {
    Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True `
        -DefaultInboundAction Block -DefaultOutboundAction Allow `
        -NotifyOnListen False -AllowInboundRules False -AllowLocalFirewallRules True `
        -AllowLocalIPsecRules True -AllowUnicastResponseToMulticast False `
        -EnableStealthModeForIPsec True `
        -LogFileName '%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log' `
        -LogMaxSizeKilobytes 16384 -LogBlocked True -LogIgnored True
}

function resetFirewall {
    netsh advfirewall reset | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "netsh advfirewall reset failed with exit code $LASTEXITCODE"
    }
    Write-Host '[+] Брандмауэр Windows успешно сброшен к заводским настройкам по умолчанию.' -ForegroundColor Green
}

function showFirewallStatus {
    Write-Host '=== Состояние профилей Брандмауэра Windows ===' -ForegroundColor Cyan
    $profiles = Get-NetFirewallProfile
    foreach ($p in $profiles) {
        $stateColor = if ($p.Enabled) { 'Green' } else { 'Red' }
        Write-Host ("[{0}] Включен: {1} | Входящий: {2} | Исходящий: {3}" -f $p.Name, $p.Enabled, $p.DefaultInboundAction, $p.DefaultOutboundAction) -ForegroundColor $stateColor
    }

    $managedCount = (Get-NetFirewallRule -PolicyStore PersistentStore -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayGroup -eq $ManagedGroup -or $_.Group -eq $ManagedGroup
    } | Measure-Object).Count

    Write-Host ""
    Write-Host ("Правил в группе '{0}': {1}" -f $ManagedGroup, $managedCount) -ForegroundColor Yellow
}

# Определение выбранного действия
$selectedFlagCount = [int]$Apply.IsPresent + [int]$Reset.IsPresent + [int]$Outbound.IsPresent + [int]$Status.IsPresent

if ($selectedFlagCount -eq 0) {
    showFirewallStatus
    Write-Host ""
    Write-Host "Использование / Usage:" -ForegroundColor Yellow
    Write-Host "  .\wfRules.ps1 -Outbound (-o) : Разрешить исходящий трафик, блокировать входящий (Рекомендуемый режим)" -ForegroundColor Cyan
    Write-Host "  .\wfRules.ps1 -Apply (-a)    : Строгий режим белых списков (блокировка входящего и исходящего)" -ForegroundColor Magenta
    Write-Host "  .\wfRules.ps1 -Reset (-r)    : Сброс брандмауэра к заводским настройкам Windows" -ForegroundColor Gray
    Write-Host "  .\wfRules.ps1 -Status (-s)   : Просмотр текущего состояния профилей и правил" -ForegroundColor Green
    return
}

if ($selectedFlagCount -gt 1) {
    throw 'Укажите только одно действие: -Outbound (-o), -Apply (-a), -Reset (-r) или -Status (-s).'
}

if ($Status) {
    showFirewallStatus
    return
}

if ($Reset) {
    if ($PSCmdlet.ShouldProcess('Windows Firewall', 'Сброс всех профилей и правил к заводским настройкам Windows')) {
        resetFirewall
    }
    return
}

if ($Outbound) {
    if ($PSCmdlet.ShouldProcess('Windows Firewall Profiles', 'Установка политик: Входящие=Block, Исходящие=Allow, Логирование=Вкл')) {
        setOutboundProfiles
        Write-Host '[+] Профили брандмауэра настроены: Входящие блокируются, Исходящие разрешены.' -ForegroundColor Green
    }
    return
}

# Режим -Apply: отключение встроенных правил, добавление белого списка и блокировка
if ($PSCmdlet.ShouldProcess('Windows Firewall', 'Применение строгого режима белых списков (-Apply)')) {
    disableExistingRules
    addManagedRules
    setBlockedProfiles
    Write-Host '[+] Строгий режим брандмауэра (-Apply) активирован.' -ForegroundColor Green
}
