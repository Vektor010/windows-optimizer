<#
================================================================================
Имя твика:              Системная информация и статус оборудования (NVFetch.ps1)
Что делает:             1. Выводит стилизованный ASCII-логотип и подробную аппаратную сводку системы:
                           - Имя пользователя, имя компьютера и время непрерывной работы (Uptime).
                           - Версия и редакция Windows, разрядность и номер сборки.
                           - Модель монитора (парсинг WMI/EDID), диагональ в дюймах, разрешение,
                             частота обновления (Гц) и тип подключения.
                           - Процессор (модель, сокет, частота в МГц и аппаратный CPU ID).
                           - Видеокарта (NVIDIA-SMI: частоты ядра и памяти, объём VRAM, BPP, P-State и UUID).
                           - Оперативная память (суммарный объём, частота в МГц, вендор и серийные номера планок).
                           - Материнская плата, производитель, версия и дата выпуска BIOS, UUID системы.
                           - Системный накопитель (модель, свободное/занятое место, файловая система, серийный номер).
                           - Сетевой адаптер, локальный IPv4-адрес и состояние службы DHCP.
                        2. Отображает контрольные цветовые блоки консоли для калибровки профиля терминала.
Зачем нужно:            Обеспечивает мгновенный сбор и отображение ключевых технических характеристик ПК,
                        проверку частот XMP/EXPO памяти, частот видеокарты и параметров монитора без необходимости
                        установки тяжелых сторонних утилит (AIDA64, CPU-Z, HWiNFO).
Значение по умолчанию:  Стандартный текстовый вывод systeminfo Windows (медленный, не отображает игровые частоты и герцовку).
Значение после твика:   Высокоскоростной структурированный отчёт о системе с выводом за доли секунды.
Источник:               Официальное руководство Gaming & System Optimizer и репозиторий github.com/system-optimizer
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Blue", "Cyan", "Green", "Magenta", "Red", "Yellow", "White")]
    [string]$Color = "Cyan",

    [Parameter()]
    [switch]$Detailed
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try {
    $Host.UI.RawUI.WindowTitle = "NVFetch - System Information"
} catch {}

function Get-EdidText {
    param([byte[]]$Bytes)
    if ($Bytes) {
        return (-join ($Bytes | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })).Trim()
    }
    return ""
}

function Invoke-NVFetch {
    param([ConsoleColor]$Accent = [ConsoleColor]::$Color)

    function Write-NVLine {
        param(
            [string]$AsciiLeft,
            [string]$AsciiColorPart,
            [string]$AsciiRight,
            [string]$Label,
            [string]$Value
        )
        Write-Host $AsciiLeft -NoNewline -ForegroundColor Gray
        if ($AsciiColorPart) {
            Write-Host $AsciiColorPart -NoNewline -ForegroundColor $Accent
        }
        Write-Host $AsciiRight -NoNewline -ForegroundColor Gray

        if ($Label) {
            Write-Host " $Label" -NoNewline -ForegroundColor Yellow
            Write-Host " >>" -NoNewline -ForegroundColor DarkGray
            Write-Host " $Value" -ForegroundColor White
        } else {
            Write-Host ""
        }
    }

    $userName = $env:USERNAME
    $hostName = $env:COMPUTERNAME
    if (-not $hostName) { $hostName = [System.Net.Dns]::GetHostName() }

    # Заголовок User@Host
    Write-Host '      %                      %    ' -NoNewline -ForegroundColor Gray
    Write-Host " $userName" -NoNewline -ForegroundColor $Accent
    Write-Host "@" -NoNewline -ForegroundColor White
    Write-Host $hostName -ForegroundColor $Accent

    $dividerLen = (" $userName@$hostName").Length
    Write-Host '    #%% ' -NoNewline -ForegroundColor Gray
    Write-Host '=' -NoNewline -ForegroundColor $Accent
    Write-Host '                  %%%    ' -NoNewline -ForegroundColor Gray
    Write-Host (" " + ("─" * ($dividerLen - 1))) -ForegroundColor DarkGray

    # 1. Операционная система
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osText = if ($os) { "$($os.Caption) $($os.OSArchitecture), $($os.Version)" } else { "N/A" }
    Write-NVLine '   %%%% ' '==' '                %%%%    ' "OS" $osText

    # 2. Uptime
    $uptimeText = "N/A"
    if ($os -and $os.LastBootUpTime) {
        $span = (Get-Date) - $os.LastBootUpTime
        $uptimeText = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes
    }
    Write-NVLine '  %%%%% ' '===' '              %%%%%    ' "Uptime" $uptimeText

    # 3. Часовой пояс
    $tz = Get-TimeZone -ErrorAction SilentlyContinue
    $tzText = if ($tz) { $tz.DisplayName } else { "N/A" }
    Write-NVLine ' %%%%%% ' '====  ==' '     %  %%%%%%    ' "Time Zone" $tzText

    # 4. Монитор и разрешение
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    $res = if ($vc -and $vc.CurrentHorizontalResolution -and $vc.CurrentVerticalResolution) {
        "$($vc.CurrentHorizontalResolution)x$($vc.CurrentVerticalResolution)"
    } else { "N/A" }
    $hz = if ($vc -and $vc.CurrentRefreshRate) { "$($vc.CurrentRefreshRate) Hz" } else { "N/A" }

    $monitors = Get-CimInstance -Namespace root\wmi -Class WmiMonitorID -ErrorAction SilentlyContinue | Where-Object { $_.Active }
    $dispText = "$res @ $hz"
    if ($monitors) {
        $basParams = Get-CimInstance -Namespace root\wmi -Class WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
        $conParams = Get-CimInstance -Namespace root\wmi -Class WmiMonitorConnectionParams -ErrorAction SilentlyContinue
        $basMap = @{}
        foreach ($b in $basParams) { $basMap[$b.InstanceName] = $b }
        $conMap = @{}
        foreach ($c in $conParams) { $conMap[$c.InstanceName] = $c }

        $m1 = $monitors | Select-Object -First 1
        $mName = Get-EdidText $m1.UserFriendlyName
        if (-not $mName) { $mName = Get-EdidText $m1.ManufacturerName }
        $bObj = $basMap[$m1.InstanceName]
        $cObj = $conMap[$m1.InstanceName]

        $inchStr = ""
        if ($bObj -and $bObj.MaxHorizontalImageSize -and $bObj.MaxVerticalImageSize) {
            $diag = [math]::Sqrt([math]::Pow(($bObj.MaxHorizontalImageSize / 2.54), 2) + [math]::Pow(($bObj.MaxVerticalImageSize / 2.54), 2))
            $inchStr = ' in {0:N1}"' -f $diag
        }
        $conn = if ($cObj -and $cObj.VideoOutputTechnology -eq 5) { "Internal" } else { "External" }
        $dispText = "$mName $res @ $hz$inchStr [$conn]"
    }
    Write-NVLine ' %%%%%% ' '====== ==' '    %% %%%%%%    ' "Display" $dispText

    # 5. BIOS
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $biosDateStr = if ($bios -and $bios.ReleaseDate) { $bios.ReleaseDate.ToShortDateString() } else { "" }
    $biosText = if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion) ($biosDateStr)" } else { "N/A" }
    Write-NVLine ' %%%%%% ' '======= :=' '   %% %%%%%%    ' "BIOS" $biosText

    # 6. Материнская плата
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $boardText = if ($board) { "$($board.Product), $($board.Manufacturer)" } else { "N/A" }
    Write-NVLine ' %%%%%%   ' '======  =' '  %% %%%%%%    ' "Motherboard" $boardText

    # 7. Процессор
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuText = if ($cpu) {
        $cName = ($cpu.Name).Trim()
        $cSocket = if ($cpu.SocketDesignation) { ($cpu.SocketDesignation).Trim() } else { "" }
        "$cName $cSocket @ $($cpu.MaxClockSpeed)MHz"
    } else { "N/A" }
    Write-NVLine ' %%%%%%  ' ': ======- ==' '%% %%%%%%    ' "CPU" $cpuText

    # 8. Видеокарта (NVIDIA-SMI или CIM)
    $gpuText = "N/A"
    $bpp = if ($vc -and $vc.CurrentBitsPerPixel) { $vc.CurrentBitsPerPixel } else { 32 }
    $smiCmd = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($smiCmd) {
        try {
            $smiOut = & $smiCmd.Source --query-gpu=name,memory.total,memory.used,memory.free,pstate,clocks.mem,clocks.gr --format=csv,noheader,nounits 2>$null
            if ($smiOut) {
                $p = ($smiOut | Select-Object -First 1) -split ',\s*'
                $gName = $p[0]
                $gVram = "$($p[1])MiB"
                $gPState = $p[4]
                $pStateFormatted = if ($gPState -match '^P') { $gPState } else { "P$gPState" }
                $gMemClock = "$($p[5])MHz"
                $gCoreClock = "$($p[6])MHz"
                $gpuText = "$gName @ $gCoreClock, $gMemClock ($gVram, $bpp BPP, State $pStateFormatted)"
            }
        } catch {}
    }
    if ($gpuText -eq "N/A") {
        if ($vc) {
            $gName = if ($vc.Name) { $vc.Name } else { $vc.Caption }
            $cls = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
            $memBytes = Get-ChildItem $cls -ErrorAction SilentlyContinue |
                ForEach-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).'HardwareInformation.qwMemorySize' } |
                Where-Object { $_ } | Select-Object -First 1
            $vramStr = if ($memBytes) { '{0:N0}MiB' -f ([uint64]$memBytes / 1MB) } else { "N/A" }
            $gpuText = "$gName ($vramStr, $bpp BPP)"
        }
    }
    Write-NVLine ' %%%%%% %%' '= ======= =' '%% %%%%%%    ' "GPU" $gpuText

    # 9. Оперативная память
    $ramModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $ramText = "N/A"
    if ($ramModules) {
        $ramTotalGb = [math]::Round(($ramModules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        $firstMod = $ramModules | Select-Object -First 1
        $ramSpeed = if ($firstMod.ConfiguredClockSpeed) { $firstMod.ConfiguredClockSpeed } else { $firstMod.Speed }
        $ramManu = if ($firstMod.Manufacturer) { ($firstMod.Manufacturer).Trim() } else { "Unknown" }
        $ramText = "$ramTotalGb GB @ ${ramSpeed}MHz ($ramManu)"
    }
    Write-NVLine ' %%%%%% %%' '== =======' '    %%%%%%    ' "RAM" $ramText

    # 10. Системный накопитель
    $drive = Get-CimInstance Win32_DiskDrive -Filter "DeviceID='\\\\.\\PHYSICALDRIVE0'" -ErrorAction SilentlyContinue
    $cDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $driveText = "N/A"
    if ($drive -and $cDisk -and $cDisk.Size -and $cDisk.FreeSpace) {
        $dFree = "{0:N2}" -f ($cDisk.FreeSpace / 1GB)
        $dUsed = "{0:N2}" -f (($cDisk.Size - $cDisk.FreeSpace) / 1GB)
        $driveText = "$($drive.Model) ($dUsed GB / $dFree GB, $($cDisk.FileSystem))"
    }
    Write-NVLine ' %%%%%% %%  ' '=  ======' '   %%%%%%    ' "Drive" $driveText

    # 11. Сеть и IP
    $net = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" -ErrorAction SilentlyContinue | Select-Object -First 1
    $netText = "N/A"
    $ipText = "N/A"
    if ($net) {
        $dhcpStr = if ($net.DHCPEnabled) { "On" } else { "Off" }
        $netText = "$($net.Description) (DHCP: $dhcpStr)"
        $ip = ($net.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Select-Object -First 1)
        if ($ip) { $ipText = $ip }
    }
    Write-NVLine ' %%%%%% %%   ' '== =======' ' %%%%%%    ' "Network" $netText
    Write-NVLine ' %%%%%% %%    ' '== ======' ' %%%%%%    ' "IP" $ipText

    # Разделитель
    Write-NVLine ' %%%%%%  %     ' '== -====' ' %%%%%%    ' "" ""

    # 12. Аппаратные идентификаторы (Hardware UUIDs)
    $csProd = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
    $uuid = if ($csProd -and $csProd.UUID) { $csProd.UUID } else { "N/A" }
    Write-NVLine ' %%%%%              ' '===' ' %%%%%     ' "UUID" $uuid

    $mbSn = if ($board -and $board.SerialNumber) { ($board.SerialNumber).Trim() } else { "N/A" }
    Write-NVLine ' %%%%                ' '==' ' %%%%      ' "Motherboard SN" $mbSn

    $cpuId = if ($cpu -and $cpu.ProcessorId) { ($cpu.ProcessorId).Trim() } else { "N/A" }
    Write-NVLine ' %%=                  ' '=' ' %%+       ' "CPU ID" $cpuId

    $ramSns = "N/A"
    if ($ramModules) {
        $snList = ($ramModules | ForEach-Object { if ($_.SerialNumber) { ($_.SerialNumber).Trim() } } | Where-Object { $_ })
        if ($snList) { $ramSns = $snList -join ', ' }
    }
    Write-NVLine ' %                      %         ' '' '' "RAM SNs" $ramSns

    # Drive0 Serial
    $driveSn = "N/A"
    $physMedia = Get-CimInstance Win32_PhysicalMedia -Filter "Tag='\\\\.\\PHYSICALDRIVE0'" -ErrorAction SilentlyContinue
    if ($physMedia -and $physMedia.SerialNumber) {
        $driveSn = ($physMedia.SerialNumber).Trim()
    } elseif ($drive -and $drive.SerialNumber) {
        $driveSn = ($drive.SerialNumber).Trim()
    }
    Write-NVLine '                                  ' '' '' "Drive0 SN" $driveSn

    # GPU UUID
    if ($smiCmd) {
        try {
            $gpuUuids = & $smiCmd.Source --query-gpu=uuid --format=csv,noheader,nounits 2>$null
            if ($gpuUuids) {
                $idx = 0
                foreach ($u in @($gpuUuids)) {
                    $idx++
                    $lbl = if (@($gpuUuids).Count -gt 1) { "GPU $idx UUID" } else { "GPU UUID" }
                    Write-NVLine '                                  ' '' '' $lbl ($u.Trim())
                }
            }
        } catch {}
    }

    Write-Host ""

    # Блок цветовой палитры терминала
    $blockWidth = 3
    $blockHeight = 1
    $indent = ' ' * 35
    $allColors = [ConsoleColor[]][Enum]::GetValues([ConsoleColor])

    foreach ($offset in 0, 8) {
        for ($i = 0; $i -lt $blockHeight; $i++) {
            Write-Host $indent -NoNewline
            for ($c = 0; $c -lt 8; $c++) {
                Write-Host (' ' * $blockWidth) -NoNewline -BackgroundColor $allColors[$offset + $c]
            }
            Write-Host ""
        }
    }
    [Console]::ResetColor()
    Write-Host ""
}

Invoke-NVFetch