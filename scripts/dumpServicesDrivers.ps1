#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Выполняет полный аудит и экспорт конфигурации всех системных служб (Win32 Services)
#    и драйверов ядра (Kernel/FileSystem Drivers) из реестра
#    HKLM:\SYSTEM\CurrentControlSet\Services в структурированные текстовые отчёты
#    services.txt и drivers.txt.
#
# 2. ЗАЧЕМ:
#    Для глубокого анализа конфигурации служб Windows, фиксации эталонного снимка
#    системы (baseline), поиска скрытых и сторонних драйверов/служб, проверки типов
#    запуска (Boot, System, Automatic, Demand, Disabled), сопоставления процессов и
#    настроек восстановления при сбоях (Failure Actions) перед твикингом.
#
# 3. ПОСЛЕДСТВИЯ:
#    Создаёт файлы services.txt и drivers.txt в указанной директории (по умолчанию
#    в папке скрипта). Не вносит никаких изменений в настройки служб, реестр или драйверы.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (x64, любые редакции). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Не требуется (диагностическая утилита Read-Only). Созданные текстовые файлы
#    могут быть удалены в любой момент.
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
    [Alias('Path', 'Folder', 'Destination')]
    [string]$OutputDir,

    [Parameter()]
    [switch]$ServicesOnly,

    [Parameter()]
    [switch]$DriversOnly,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# Безопасное определение целевой папки
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$servicesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$servicesOut = Join-Path $OutputDir 'services.txt'
$driversOut  = Join-Path $OutputDir 'drivers.txt'

# Компиляция типа для загрузки непрямых MUI-строк
if (-not ([Management.Automation.PSTypeName]'Win32.ShIndirectString').Type) {
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Win32 {
    public static class ShIndirectString {
        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
        public static extern int SHLoadIndirectString(string source, StringBuilder buffer, int bufferSize, IntPtr reserved);
    }
}
'@ -ErrorAction SilentlyContinue
    } catch {
        $null = $_
    }
}

function Format-NvValue {
    param([Parameter(Mandatory = $false)]$Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [array]) { return ($Value -join ', ') }
    return [string]$Value
}

function Resolve-NvText {
    param(
        [Parameter(Mandatory = $false)]$Value,
        [Parameter(Mandatory = $false)]$Fallback
    )
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $Fallback }

    $text = [string]$Value
    if ($text.StartsWith('@')) {
        try {
            $buffer = [System.Text.StringBuilder]::new(4096)
            $status = [Win32.ShIndirectString]::SHLoadIndirectString($text, $buffer, $buffer.Capacity, [IntPtr]::Zero)
            if ($status -eq 0 -and $buffer.Length -gt 0) { return $buffer.ToString() }
        } catch {
            $null = $_
        }
        if ($Fallback) { return $Fallback }
    }
    return $text
}

function Add-NvField {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)]$Value
    )
    $formatted = Format-NvValue -Value $Value
    [void]$Builder.AppendLine(('{0,-24}: {1}' -f $Name, $formatted))
}

function Add-NvBlock {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)]$Text
    )
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine($Title)
    [void]$Builder.AppendLine(('-' * $Title.Length))
    if ($Text) {
        $content = ($Text -join [Environment]::NewLine).Trim()
        [void]$Builder.AppendLine($content)
    }
}

function Get-NvStartName {
    param([Parameter(Mandatory = $true)]$Start)
    switch ([int]$Start) {
        0 { 'Boot' }
        1 { 'System' }
        2 { 'Automatic' }
        3 { 'Demand' }
        4 { 'Disabled' }
        default { "Unknown ($Start)" }
    }
}

function Get-NvErrorControlName {
    param([Parameter(Mandatory = $true)]$ErrorControl)
    switch ([int]$ErrorControl) {
        0 { 'Ignore' }
        1 { 'Normal' }
        2 { 'Severe' }
        3 { 'Critical' }
        default { "Unknown ($ErrorControl)" }
    }
}

function Get-NvTypeName {
    param([Parameter(Mandatory = $true)]$Type)
    $typeValue = [int]$Type
    $names = [System.Collections.Generic.List[string]]::new()
    if ($typeValue -band 0x1)   { $names.Add('Kernel Driver') }
    if ($typeValue -band 0x2)   { $names.Add('File System Driver') }
    if ($typeValue -band 0x4)   { $names.Add('Adapter') }
    if ($typeValue -band 0x8)   { $names.Add('Recognizer Driver') }
    if ($typeValue -band 0x10)  { $names.Add('Win32 Own Process') }
    if ($typeValue -band 0x20)  { $names.Add('Win32 Share Process') }
    if ($typeValue -band 0x40)  { $names.Add('User Service') }
    if ($typeValue -band 0x80)  { $names.Add('User Service Instance') }
    if ($typeValue -band 0x100) { $names.Add('Interactive') }
    if ($names.Count -eq 0)     { return "Unknown ($typeValue)" }
    return ($names -join ', ')
}

function Get-NvBinaryPath {
    param([Parameter(Mandatory = $false)][string]$ImagePath)
    if (-not $ImagePath) { return $null }

    $path = [Environment]::ExpandEnvironmentVariables([string]$ImagePath)
    $path = $path -replace '^\\\?\?\\', ''
    $path = $path -replace '^\\SystemRoot\\', "$env:SystemRoot\"
    $path = $path -replace '^System32\\', "$env:SystemRoot\System32\"

    if ($path -match '^\s*"([^"]+)"') { return $matches[1] }
    if ($path -match '^\s*(.+?\.(exe|sys|dll))(\s|$)') { return $matches[1] }
    return $path
}

function Add-NvFileInfo {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $false)][string]$ImagePath
    )
    $binaryPath = Get-NvBinaryPath -ImagePath $ImagePath
    Add-NvField -Builder $Builder -Name 'Binary Path' -Value $binaryPath

    if (-not $binaryPath -or -not (Test-Path -LiteralPath $binaryPath)) { return }

    try {
        $file = Get-Item -LiteralPath $binaryPath -ErrorAction SilentlyContinue
        if ($file) {
            $version = $file.VersionInfo
            Add-NvField -Builder $Builder -Name 'File Description' -Value $version.FileDescription
            Add-NvField -Builder $Builder -Name 'File Version' -Value $version.FileVersion
            Add-NvField -Builder $Builder -Name 'Company' -Value $version.CompanyName
            Add-NvField -Builder $Builder -Name 'Product Name' -Value $version.ProductName
            Add-NvField -Builder $Builder -Name 'Last Write Time' -Value $file.LastWriteTime
        }
    } catch {
        $null = $_
    }
}

function Invoke-NvSc {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    try {
        & sc.exe @Arguments 2>&1
    } catch {
        $null = $_
    }
}

Write-Host "[*] Сбор информации о службах и системных драйверах..." -ForegroundColor Cyan

$serviceInfo = @{}
try {
    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object { $serviceInfo[$_.Name] = $_ }
} catch {
    $null = $_
}

$driverInfo = @{}
try {
    Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | ForEach-Object { $driverInfo[$_.Name] = $_ }
} catch {
    $null = $_
}

$processInfo = @{}
try {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object { $processInfo[[uint32]$_.ProcessId] = $_ }
} catch {
    $null = $_
}

$serviceBuilder = [System.Text.StringBuilder]::new()
$driverBuilder  = [System.Text.StringBuilder]::new()

$servicesCount = 0
$driversCount  = 0
$summaryList   = [System.Collections.Generic.List[psobject]]::new()

Get-ChildItem -LiteralPath $servicesKey -ErrorAction SilentlyContinue | Sort-Object PSChildName | ForEach-Object {
    $key = $_
    $props = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
    if (-not $props -or $null -eq $props.Type) { return }

    $type = [int]$props.Type
    $isDriver  = ($type -band 0xF) -ne 0
    $isService = ($type -band 0x30) -ne 0

    if (-not $isDriver -and -not $isService) { return }
    if ($ServicesOnly -and -not $isService) { return }
    if ($DriversOnly  -and -not $isDriver)  { return }

    $builder = if ($isDriver) { $driverBuilder } else { $serviceBuilder }
    if ($isDriver) { $driversCount++ } else { $servicesCount++ }

    $name = $key.PSChildName
    $cim = if ($isDriver) { $driverInfo[$name] } else { $serviceInfo[$name] }
    $process = if ($cim -and $cim.ProcessId) { $processInfo[[uint32]$cim.ProcessId] } else { $null }

    $displayName = Resolve-NvText -Value $props.DisplayName -Fallback $(if ($cim) { $cim.DisplayName } else { $null })
    $description = Resolve-NvText -Value $props.Description -Fallback $(if ($cim) { $cim.Description } else { $null })
    $startMode   = if ($null -ne $props.Start) { "$(Get-NvStartName -Start $props.Start) ($($props.Start))" } else { 'Unknown' }
    $state       = if ($cim -and $cim.State) { $cim.State } else { 'N/A' }

    [void]$builder.AppendLine(('=' * 70))
    Add-NvField -Builder $builder -Name 'Name' -Value $name
    Add-NvField -Builder $builder -Name 'Display Name' -Value $displayName
    Add-NvField -Builder $builder -Name 'Description' -Value $description
    Add-NvField -Builder $builder -Name 'Type' -Value "$(Get-NvTypeName -Type $props.Type) ($($props.Type))"
    Add-NvField -Builder $builder -Name 'Start' -Value $startMode
    if ($null -ne $props.ErrorControl) {
        Add-NvField -Builder $builder -Name 'Error Control' -Value "$(Get-NvErrorControlName -ErrorControl $props.ErrorControl) ($($props.ErrorControl))"
    }
    if ($cim -and $cim.State) {
        Add-NvField -Builder $builder -Name 'State' -Value $cim.State
    }
    Add-NvField -Builder $builder -Name 'Group' -Value $props.Group
    Add-NvField -Builder $builder -Name 'Tag' -Value $props.Tag
    Add-NvField -Builder $builder -Name 'Object Name' -Value $props.ObjectName
    Add-NvField -Builder $builder -Name 'Image Path' -Value $props.ImagePath
    Add-NvFileInfo -Builder $builder -ImagePath $props.ImagePath
    Add-NvField -Builder $builder -Name 'Depend On Service' -Value $props.DependOnService
    Add-NvField -Builder $builder -Name 'Depend On Group' -Value $props.DependOnGroup
    Add-NvField -Builder $builder -Name 'Required Privileges' -Value $props.RequiredPrivileges
    Add-NvField -Builder $builder -Name 'Service SID Type' -Value $props.ServiceSidType
    if ($null -ne $props.DelayedAutoStart) {
        Add-NvField -Builder $builder -Name 'Delayed Auto Start' -Value $props.DelayedAutoStart
    }
    Add-NvField -Builder $builder -Name 'Failure Actions' -Value $(if ($props.FailureActions) { 'Present' } else { 'None' })

    if ($process) {
        Add-NvField -Builder $builder -Name 'Command Line' -Value $process.CommandLine
        Add-NvField -Builder $builder -Name 'Process ID' -Value $process.ProcessId
        Add-NvField -Builder $builder -Name 'Thread Count' -Value $process.ThreadCount
        Add-NvField -Builder $builder -Name 'Handle Count' -Value $process.HandleCount
        Add-NvField -Builder $builder -Name 'Working Set' -Value $process.WorkingSetSize
    }

    if (Test-Path -LiteralPath "$($key.PSPath)\TriggerInfo") {
        Add-NvBlock -Builder $builder -Title 'Triggers' -Text (Invoke-NvSc -Arguments @('qtriggerinfo', $name))
    } else {
        Add-NvField -Builder $builder -Name 'Triggers' -Value 'None registered'
    }

    if ($props.FailureActions) {
        Add-NvBlock -Builder $builder -Title 'Failure Action Details' -Text (Invoke-NvSc -Arguments @('qfailure', $name))
    }

    [void]$builder.AppendLine()

    if ($PassThru) {
        $summaryList.Add([pscustomobject]@{
            Category    = if ($isDriver) { 'Driver' } else { 'Service' }
            Name        = $name
            DisplayName = $displayName
            StartMode   = $startMode
            State       = $state
            ImagePath   = $props.ImagePath
        })
    }
}

if (-not $DriversOnly) {
    [System.IO.File]::WriteAllText($servicesOut, $serviceBuilder.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "[+] Экспортировано $servicesCount служб в файл: $servicesOut" -ForegroundColor Green
}

if (-not $ServicesOnly) {
    [System.IO.File]::WriteAllText($driversOut, $driverBuilder.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "[+] Экспортировано $driversCount драйверов в файл: $driversOut" -ForegroundColor Green
}

if ($PassThru) {
    return $summaryList
}