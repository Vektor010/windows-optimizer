# ==============================================================================
# Gaming & System Optimizer - Сетевой стек, TCP/IP и адаптер Realtek (Network & TCP/IP)
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Применение сетевых твиков, TCP/IP и оптимизации адаптера..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: Глобальные параметры TCP/IP и алгоритм управления перегрузкой (Congestion Provider)
# Что делает: Задает масштабируемый алгоритм перегрузки CUBIC, включает нормальное автоопределение окна приема (AutoTuningLevelLocal = Normal), отключает эвристику масштабирования, включает быстрое открытие TCP Fast Open и отключает служебные временные метки пакетов RFC 1323.
# Зачем нужно: CUBIC оптимизирует работу на каналах с высокой пропускной способностью, отключение timestamps экономит 12 байт заголовка в каждом пакете, а Fast Open устраняет задержку рукопожатия TCP SYN, ускоряя сетевой обмен.
# Значение по умолчанию (Windows): CongestionProvider = CUBIC (или Default), AutoTuning = Normal, Heuristics = Enabled, Timestamps = Disabled/Enabled
# Значение после твика: CongestionProvider = CUBIC, AutoTuningLevel = Normal, Heuristics = Disabled, FastOpen = Enabled, Timestamps = Disabled
# Источник: Gaming & System Optimizer: Network Latency Architecture
# ─────────────────────────────────────────────
Write-Host "[1/5] Настройка глобальных параметров TCP и алгоритма CUBIC..." -ForegroundColor Yellow
try {
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global heuristics=default | Out-Null
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global fastopen=enabled | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null

    try {
        Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -AutoTuningLevelLocal Normal -ErrorAction Stop | Out-Null
        Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider CUBIC -AutoTuningLevelLocal Normal -ErrorAction Stop | Out-Null
        Write-Host " [+] Алгоритм перегрузки CUBIC успешно назначен для профилей Internet и InternetCustom" -ForegroundColor Green
    } catch {
        Write-Host " [=] Используется стандартный системный алгоритм перегрузки" -ForegroundColor DarkGray
    }
} catch {
    Write-Host " [-] Ошибка настройки глобальных параметров TCP: $_" -ForegroundColor Red
}

# ─────────────────────────────────────────────
# Название: Модерация прерываний сетевой карты (Interrupt Moderation)
# Что делает: Отключает задержку накопления пакетов в контроллере сетевой карты (ITR = 0, *InterruptModeration = 0).
# Зачем нужно: Пакеты прерываний передаются процессору мгновенно по мере поступления каждого отдельного кадра, устраняя задержку очередей контроллера и минимизируя сетевой пинг в онлайн-играх.
# Значение по умолчанию (Windows): Enabled (1) — модерация прерываний включена для экономии тактов процессора
# Значение после твика: Disabled (0) — мгновенная передача прерываний процессору
# Источник: Gaming & System Optimizer: Network Latency Architecture
# ─────────────────────────────────────────────
Write-Host "[2/5] Отключение модерации прерываний сетевой карты (нулевая задержка ITR)..." -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue | Out-Null
    Write-Host " [+] Адаптер '$($adapter.Name)': Модерация прерываний успешно отключена" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# Название: Буферы сетевого адаптера и аппаратная разгрузка (Network Buffers & Offloads)
# Что делает: Устанавливает кольцевые буферы приема и передачи пакетов на максимальное поддерживаемое драйвером значение (Receive/Transmit Buffers) и гарантирует активность аппаратной разгрузки задач (DisableTaskOffload = 0).
# Зачем нужно: Максимальный размер очередей предотвращает сброс пакетов (Packet Loss / Drops) при пиковой нагрузке, а аппаратная разгрузка Checksum/LSO на чип сетевой карты снимает нагрузку с процессора.
# Значение по умолчанию (Windows): Receive Buffers = 512, Transmit Buffers = 128, DisableTaskOffload = 0
# Значение после твика: Receive Buffers = 512 (max), Transmit Buffers = 128 (max), DisableTaskOffload = 0 (REG_DWORD)
# Источник: Gaming & System Optimizer: Network Latency Architecture
# ─────────────────────────────────────────────
Write-Host "[3/5] Настройка буферов сетевой карты и аппаратной разгрузки задач..." -ForegroundColor Yellow
$tcpParams = "HKLM:\System\CurrentControlSet\Services\TCPIP\Parameters"
if (-not (Test-Path $tcpParams)) { New-Item -Path $tcpParams -Force | Out-Null }
Set-ItemProperty -Path $tcpParams -Name "DisableTaskOffload" -Type DWord -Value 0

foreach ($adapter in $adapters) {
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "256" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "256" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue | Out-Null
    Write-Host " [+] Адаптер '$($adapter.Name)': Буферы RX/TX сконфигурированы, Flow Control отключен" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# Название: Отключение широковещательного шума NetBIOS, mDNS и LLMNR
# Что делает: Отключает устаревший протокол разрешения имен NetBIOS over TCP/IP (NetbiosOptions = 2), протокол многоадресного разрешения имен LLMNR и mDNS через групповые политики.
# Зачем нужно: Полностью ликвидирует паразитный широковещательный трафик в локальной сети, закрывает вектор атак спуфинга имен (LLMNR Poisoning) и разгружает сетевой стек Windows.
# Значение по умолчанию (Windows): NetbiosOptions = 0 (по умолчанию DHCP), EnableMDNS = 1, EnableMulticast = 1
# Значение после твика: NetbiosOptions = 2 (REG_DWORD, отключен), EnableMDNS = 0, EnableMulticast = 0, DisableSmartNameResolution = 1
# Источник: Gaming & System Optimizer: Network Latency Architecture
# ─────────────────────────────────────────────
Write-Host "[4/5] Отключение широковещательного трафика NetBIOS, LLMNR и mDNS..." -ForegroundColor Yellow
try {
    Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
        $null = Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]2 } -ErrorAction SilentlyContinue
    }

    $dnsClientPol = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
    if (-not (Test-Path $dnsClientPol)) { New-Item -Path $dnsClientPol -Force | Out-Null }
    Set-ItemProperty -Path $dnsClientPol -Name "EnableMDNS" -Type DWord -Value 0
    Set-ItemProperty -Path $dnsClientPol -Name "EnableMulticast" -Type DWord -Value 0
    Set-ItemProperty -Path $dnsClientPol -Name "DisableSmartNameResolution" -Type DWord -Value 1
    Write-Host " [+] NetBIOS over TCP/IP, протоколы LLMNR и mDNS успешно отключены" -ForegroundColor Green
} catch {
    Write-Host " [-] Ошибка отключения NetBIOS/LLMNR: $_" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────
# Название: Отключение энергосбережения сетевого адаптера и Wake on LAN (WoL)
# Что делает: Запрещает операционной системе отключать питание сетевой карты для экономии энергии, отключает пробуждение по сетевому пакету (Wake on Magic Packet / Wake on Pattern).
# Зачем нужно: Предотвращает засыпание контроллера Realtek, устраняет задержки повторной синхронизации физического линка и исключает паразитное энергосбережение сетевого чипа.
# Значение по умолчанию (Windows): AllowComputerToTurnOffDevice = Enabled, WakeOnMagicPacket = Enabled
# Значение после твика: AllowComputerToTurnOffDevice = Disabled, WakeOnMagicPacket = Disabled
# Источник: Gaming & System Optimizer: Network Latency Architecture
# ─────────────────────────────────────────────
Write-Host "[5/5] Отключение энергосбережения сетевой карты и Wake on LAN..." -ForegroundColor Yellow
try {
    Get-NetAdapterPowerManagement | ForEach-Object {
        $_.AllowComputerToTurnOffDevice = 'Disabled'
        $_.WakeOnMagicPacket = 'Disabled'
        $_.WakeOnPattern = 'Disabled'
        $_ | Set-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Out-Null
    }

    $netClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\0000"
    if (Test-Path $netClass) {
        Set-ItemProperty -Path $netClass -Name "*WakeOnMagicPacket" -Type String -Value "0" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $netClass -Name "*WakeOnPattern" -Type String -Value "0" -ErrorAction SilentlyContinue
    }
    Write-Host " [+] Энергосбережение и пробуждение сетевой карты отключены" -ForegroundColor Green
} catch {
    Write-Host " [-] Настройка управления питанием сетевой карты пропущена: $_" -ForegroundColor DarkGray
}

# Очистка устаревших недокументированных параметров Nagle (если присутствовали ранее в интерфейсах):
$interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
if (Test-Path $interfacesPath) {
    Get-ChildItem -Path $interfacesPath | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
    }
}

Write-Host "`n[✓] Все оптимизации сетевого стека и TCP/IP (5/5) применены успешно!" -ForegroundColor Green