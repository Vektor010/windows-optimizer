# Noverse Research - Network & Latency Optimization
# Tailored for Realtek Gigabit Ethernet & Low-Latency Gaming

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Applying Network & TCP/IP Latency Optimizations..." -ForegroundColor Cyan

# 1. Tuning TCP Parameters via NetTCPSetting
Write-Host "[1/5] Configuring TCP Congestion & Window Auto-Tuning..." -ForegroundColor Yellow
try {
    # Set autotuninglevel to normal (fastest throughput and buffer sizing)
    netsh int tcp set global autotuninglevel=normal | Out-Null
    # Disable scaling heuristics
    netsh int tcp set global heuristics=disabled | Out-Null
    # Enable ECN Capability if supported
    netsh int tcp set global ecncapability=enabled | Out-Null
    # Enable RSS globally
    netsh int tcp set global rss=enabled | Out-Null
    # Enable Fast Open
    netsh int tcp set global fastopen=enabled | Out-Null
    # Disable timestamps (saves header bytes)
    netsh int tcp set global timestamps=disabled | Out-Null

    # Set CUBIC or CTCP for Internet template
    Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -AutoTuningLevelLocal Normal -ErrorAction SilentlyContinue | Out-Null
    Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider CUBIC -AutoTuningLevelLocal Normal -ErrorAction SilentlyContinue | Out-Null
    Write-Host " [+] TCP global parameters tuned (AutoTuning=Normal, Heuristics=Off, RSS=On)" -ForegroundColor Green
} catch {
    Write-Host " [-] TCP global settings error: $_" -ForegroundColor Red
}

# 2. Network Adapter Advanced Settings (Realtek PCIe)
Write-Host "[2/5] Configuring Realtek Network Adapter Properties..." -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    # Interrupt Moderation: For competitive gaming, Low or Disabled gives instant packet processing
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
    
    # Increase Transmit / Receive Buffers for peak packet handling
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "1024" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue | Out-Null
    
    # Noverse Network: Disable Flow Control & Energy Efficient Ethernet & LSO
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Large Send Offload v2 (IPv4)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null
    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Large Send Offload v2 (IPv6)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue | Out-Null

    Write-Host " [+] Adapter '$($adapter.Name)': Interrupt Moderation=Disabled, Buffers expanded, FlowControl/EEE/LSO Off" -ForegroundColor Green
}

# 3. Disable Nagle's Algorithm (TcpAckFrequency = 1, TCPNoDelay = 1)
Write-Host "[3/5] Disabling Nagle's Algorithm for Instant Gaming Packets..." -ForegroundColor Yellow
$interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
if (Test-Path $interfacesPath) {
    $subkeys = Get-ChildItem -Path $interfacesPath
    foreach ($key in $subkeys) {
        # Only configure active interfaces with IP addresses
        $ip = (Get-ItemProperty -Path $key.PSPath).IPAddress
        $dhcp = (Get-ItemProperty -Path $key.PSPath).DhcpIPAddress
        if ($ip -or $dhcp) {
            Set-ItemProperty -Path $key.PSPath -Name "TcpAckFrequency" -Type DWord -Value 1
            Set-ItemProperty -Path $key.PSPath -Name "TCPNoDelay" -Type DWord -Value 1
            Set-ItemProperty -Path $key.PSPath -Name "TcpDelAckTicks" -Type DWord -Value 0
        }
    }
    Write-Host " [+] TcpAckFrequency=1 & TCPNoDelay=1 applied (eliminates delayed ACKs in games)" -ForegroundColor Green
}

# 4. Disable NetBIOS over TCP/IP
Write-Host "[4/5] Disabling NetBIOS Broadcasts..." -ForegroundColor Yellow
try {
    Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
        $null = $_.SetTcpipNetbios(2) # 2 = Disabled
    }
    Write-Host " [+] NetBIOS over TCP/IP disabled (prevents network background broadcast chatter)" -ForegroundColor Green
} catch {
    Write-Host " [-] Could not set NetBIOS: $_" -ForegroundColor DarkGray
}

# 5. Disable Network Power Savings / Sleep
Write-Host "[5/5] Disabling Network Adapter Power Throttling..." -ForegroundColor Yellow
try {
    Get-NetAdapterPowerManagement | ForEach-Object {
        $_.AllowComputerToTurnOffDevice = 'Disabled'
        $_.WakeOnMagicPacket = 'Disabled'
        $_ | Set-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Host " [+] Network adapter sleep disabled (NIC stays awake at full power)" -ForegroundColor Green
} catch {
    Write-Host " [-] NetAdapterPowerManagement skipped: $_" -ForegroundColor DarkGray
}

Write-Host "`n[✓] Network latency optimizations completed!" -ForegroundColor Green
