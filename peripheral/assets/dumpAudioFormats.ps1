#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Сканирует системный реестр Windows Core Audio (MMDevices) для потоков воспроизведения
#    (Render) и записи (Capture), извлекает и декодирует бинарные структуры
#    WAVEFORMATEXTENSIBLE, сопоставляет GUID эндпоинтов с понятными именами устройств
#    и статусом их подключения (Active, Disabled, Unplugged).
#
# 2. ЗАЧЕМ:
#    Для углубленной диагностики текущих форматов звука (частота дискретизации в Гц,
#    разрядность, количество каналов, размер блока, битрейт), выявления скрытых
#    настроек драйверов (Realtek, USB DAC, HDMI/DP) и проверки согласованности
#    потока (AvgBytesPerSec == Hz * BlockAlign) перед оптимизацией задержек DPC/ISR.
#
# 3. ПОСЛЕДСТВИЯ:
#    Выводит в консоль или конвейер детальные объекты аудиотрактов. Не вносит
#    изменений в систему и реестр (информационный режим Read-Only).
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+.
#
# 5. ОТКАТ:
#    Не требуется (утилита только для чтения).
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий Nohuto / win-config:
#    https://github.com/nohuto/win-config/blob/main/scripts/dumpAudioFormats.ps1
#    Документация Noverse:
#    https://noverse.dev/win-config/misc/
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('All', 'Render', 'Capture')]
    [string]$Flow = 'All',

    [Parameter()]
    [switch]$ActiveOnly
)

$ErrorActionPreference = "Stop"

$base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'

$values = @(
    '{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},2',
    '{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},3',
    '{624f56de-fd24-473e-814a-de40aacaed16},3',
    '{e4870e26-3cc5-4cd2-ba46-ca0a9a70ed04},0',
    '{f19f064d-082c-4e27-bc73-6882a1bb8e4c},0'
)

$propertyTags = @{
    '{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},2' = 'DeviceFormat'
    '{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},3' = 'OEMFormat'
    '{624f56de-fd24-473e-814a-de40aacaed16},3' = 'EndpointFormat'
    '{e4870e26-3cc5-4cd2-ba46-ca0a9a70ed04},0' = 'ExclusiveFormat'
    '{f19f064d-082c-4e27-bc73-6882a1bb8e4c},0' = 'FormFactorFormat'
}

$flowsToScan = if ($Flow -ieq 'All') { @('Render', 'Capture') } else { @($Flow) }

$results = [System.Collections.Generic.List[psobject]]::new()

foreach ($flowItem in $flowsToScan) {
    $flowPath = Join-Path $base $flowItem
    if (-not (Test-Path -LiteralPath $flowPath)) { continue }

    foreach ($endpoint in Get-ChildItem -LiteralPath $flowPath -ErrorAction SilentlyContinue) {
        $propsPath = Join-Path $endpoint.PSPath 'Properties'
        if (-not (Test-Path -LiteralPath $propsPath)) { continue }

        $endpointProps = Get-ItemProperty -LiteralPath $endpoint.PSPath -ErrorAction SilentlyContinue
        $deviceStateCode = if ($endpointProps -and ($null -ne $endpointProps.DeviceState)) { [int]$endpointProps.DeviceState } else { 0 }

        if ($ActiveOnly -and $deviceStateCode -ne 1) {
            continue
        }

        $deviceStateStr = switch ($deviceStateCode) {
            1 { 'Active' }
            2 { 'Disabled' }
            4 { 'NotPresent' }
            8 { 'Unplugged' }
            default { "Code ($deviceStateCode)" }
        }

        $props = Get-ItemProperty -LiteralPath $propsPath -ErrorAction SilentlyContinue
        if (-not $props) { continue }

        $friendlyName = $props.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
        if ([string]::IsNullOrWhiteSpace($friendlyName)) {
            $friendlyName = $props.'{a45c254e-df1c-4efd-8020-67d146a850e0},14'
        }
        if ([string]::IsNullOrWhiteSpace($friendlyName)) {
            $friendlyName = $props.'{b3f8fa53-0004-438e-9002-9d4e466ac424},6'
        }
        if ([string]::IsNullOrWhiteSpace($friendlyName)) {
            $friendlyName = 'Generic Audio Endpoint'
        }

        foreach ($name in $values) {
            $prop = $props.PSObject.Properties[$name]
            if ($null -eq $prop -or $prop.Value -isnot [byte[]]) { continue }

            $bytes = [byte[]]$prop.Value
            if ($bytes.Length -ne 48 -or [BitConverter]::ToUInt16($bytes, 8) -ne 0xFFFE) { continue }

            $channels   = [BitConverter]::ToUInt16($bytes, 10)
            $sampleRate = [BitConverter]::ToUInt32($bytes, 12)
            $avgBytes   = [BitConverter]::ToUInt32($bytes, 16)
            $blockAlign = [BitConverter]::ToUInt16($bytes, 20)
            $bits       = [BitConverter]::ToUInt16($bytes, 22)
            $tag        = if ($propertyTags.ContainsKey($name)) { $propertyTags[$name] } else { 'CustomFormat' }

            $results.Add([pscustomobject]@{
                Flow                   = $flowItem
                DeviceName             = $friendlyName
                State                  = $deviceStateStr
                Hz                     = $sampleRate
                Channels               = $channels
                Bits                   = $bits
                BlockAlign             = $blockAlign
                AvgBytesPerSec         = $avgBytes
                ExpectedAvgBytesPerSec = $sampleRate * $blockAlign
                Consistent             = ($avgBytes -eq ($sampleRate * $blockAlign))
                PropertyTag            = $tag
                Value                  = $name
                Endpoint               = $endpoint.PSChildName
            })
        }
    }
}

return $results
