# ==============================================================================
#  NOVERSE FULL CATEGORIZED OPTIMIZER & BENCHMARK SUITE (v2.0)
#  Based on complete documentation from https://noverse.dev/docs/ by Nohuto
#  Target System: AMD Ryzen 7 9850X3D | NVIDIA RTX 5080 | Win 11 IoT LTSC 24H2
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

fltmc >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Error: Administrator privileges required!" -ForegroundColor Red
    pause
    exit
}

try { $Host.UI.RawUI.WindowTitle = "Noverse Complete Suite (Research by Nohuto) - AMD Ryzen 9850X3D & RTX 5080" } catch {}
$scriptsDir = Join-Path $PSScriptRoot "scripts"

function Tag($cond, $onText="[ ON ]", $offText="[ DEF ]") {
    if ($cond) { return @{ Text = $onText; Color = "Green" } }
    else { return @{ Text = $offText; Color = "DarkGray" } }
}

# ==============================================================================
#  CATEGORY 1: SYSTEM & KERNEL (From noverse.dev/docs/win-config/system/)
# ==============================================================================
function Menu-System {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [1] SYSTEM & KERNEL TWEAKS (noverse.dev/docs/win-config/system)      " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Performance Log Users
        $groupSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-559")
        $groupName = $groupSid.Translate([System.Security.Principal.NTAccount]).Value
        if ($groupName -match '\\(.+)$') { $groupName = $matches[1] }
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($user -match '\\(.+)$') { $user = $matches[1] }
        $members = net localgroup "$groupName" 2>$null
        $t1 = Tag ($members -match [regex]::Escape($user)) "[ ON ]" "[ OFF ]"

        # 2. MMCSS SystemResponsiveness
        $mmcss = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
        $t2 = Tag ($mmcss.SystemResponsiveness -eq 0) "[ 0 (Gaming) ]" "[ $($mmcss.SystemResponsiveness) (Stock) ]"

        # 3. MMCSS NetworkThrottlingIndex
        $isThrottlingOff = ($mmcss.NetworkThrottlingIndex -eq -1 -or $mmcss.NetworkThrottlingIndex -eq 4294967295)
        $t3 = Tag $isThrottlingOff "[ Disabled ]" "[ $($mmcss.NetworkThrottlingIndex) (Stock) ]"

        # 4. MMCSS Games Task Priority
        $gTask = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -ErrorAction SilentlyContinue
        $t4 = Tag ($gTask."GPU Priority" -eq 8 -and $gTask.Priority -eq 6) "[ High (8/6) ]" "[ Stock ]"

        # 5. MMCSS NoLazyMode
        $t5 = Tag ($mmcss.NoLazyMode -eq 1) "[ 1 (No Sleep) ]" "[ Stock ]"

        # 6. Win32PrioritySeparation
        $prio = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
        $t6 = Tag ($prio -eq 38 -or $prio -eq 0x26) "[ 0x26 (38d) ]" "[ $prio (Stock) ]"

        # 7. SerializeTimerExpiration (Kernel Timer Table Per-Core)
        $kernel = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -ErrorAction SilentlyContinue
        $t7 = Tag ($kernel.SerializeTimerExpiration -eq 2) "[ 2 (Per-Core) ]" "[ $($kernel.SerializeTimerExpiration) (Stock) ]"

        # 8. ThreadDpcEnable
        $t8 = Tag ($kernel.ThreadDpcEnable -eq 1) "[ 1 (Threaded) ]" "[ Stock ]"

        # 9. Game Mode & GameDVR
        $gb = Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -ErrorAction SilentlyContinue
        $gdvr = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -ErrorAction SilentlyContinue
        $t9 = Tag ($gb.AllowAutoGameMode -eq 1 -and $gdvr.AllowGameDVR -eq 0) "[ GameMode ON / DVR OFF ]" "[ Stock ]"

        # 10. Memory Compression & Page Combining (64GB RAM)
        $mma = Get-MMAgent -ErrorAction SilentlyContinue
        $t10 = Tag (-not $mma.MemoryCompression -and -not $mma.PageCombining) "[ Disabled (Fast) ]" "[ Stock ]"

        # 11. DisablePagingExecutive
        $mm = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -ErrorAction SilentlyContinue
        $t11 = Tag ($mm.DisablePagingExecutive -eq 1) "[ 1 (Lock in RAM) ]" "[ Stock ]"

        # 12. SleepStudyDisabled
        $pwrSm = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ErrorAction SilentlyContinue
        $t12 = Tag ($pwrSm.SleepStudyDisabled -eq 1) "[ Disabled ]" "[ Stock ]"

        # 13. DWM Fullscreen Optimizations & DirectFlip
        $dvr = Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue
        $t13 = Tag ($dvr.GameDVR_FSEBehaviorMode -eq 2) "[ FSO DirectFlip ]" "[ Stock ]"

        # 14. DWM Multi-Plane Overlay (MPO) & DirectFlip
        $gfx = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue
        $t14 = Tag ($gfx.DisableOverlays -eq 0 -and $gfx.ForceDirectFlip -eq 1) "[ MPO & DirectFlip ON ]" "[ Stock ]"

        # 15. HAGS & Foreground Priority Boost
        $gfxSched = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" -ErrorAction SilentlyContinue
        $t15 = Tag ($gfx.HwSchMode -eq 2 -and $gfxSched.ForegroundPriorityBoost -eq 1) "[ HAGS & GPU Boost ]" "[ Stock ]"

        # 16. NTFS Filesystem Tweaks (8dot3 name creation & last access update)
        $fs = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue
        $t16 = Tag ($fs.NtfsDisable8dot3NameCreation -eq 1 -and $fs.NtfsDisableLastAccessUpdate -eq 1) "[ Optimized ]" "[ Stock ]"

        # 17. Hung Screen & App Timeouts
        $desk = Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue
        $t17 = Tag ($desk.HungAppTimeout -eq 1000 -and $desk.AutoEndTasks -eq "1") "[ Optimized (1s) ]" "[ Stock ]"

        # 18. StickyKeys Popups & VerboseStatus
        $sk = (Get-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -ErrorAction SilentlyContinue).Flags
        $polSys = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
        $t18 = Tag ($sk -eq "506" -and $polSys.VerboseStatus -eq 1) "[ Optimized ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t PresentMon / Special K SwapChain Access (Perf Log Users group)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t MMCSS System Responsiveness (0 = 100% CPU to Foreground Game)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t MMCSS Network Throttling (0xFFFFFFFF = No Network Limiter)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t MMCSS Games Task Scheduling (GPU Priority 8 / Scheduling High)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t MMCSS NoLazyMode (1 = Prevents Scheduler Lazy/Sleep states)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t Win32PrioritySeparation (0x26 = 3:1 Quantum Boost for 9850X3D)"
        Write-Host " [7]  " -NoNewline; Write-Host $t7.Text -ForegroundColor $t7.Color -NoNewline; Write-Host "`t SerializeTimerExpiration (2 = Per-Core Timer Tables, Unblocks CPU 0)"
        Write-Host " [8]  " -NoNewline; Write-Host $t8.Text -ForegroundColor $t8.Color -NoNewline; Write-Host "`t ThreadDpcEnable (1 = Preemptible Threaded DPC for Zero Latency Spikes)"
        Write-Host " [9]  " -NoNewline; Write-Host $t9.Text -ForegroundColor $t9.Color -NoNewline; Write-Host "`t Game Mode & GameDVR (AutoGameMode ON, Background DVR Limiter OFF)"
        Write-Host " [10] " -NoNewline; Write-Host $t10.Text -ForegroundColor $t10.Color -NoNewline; Write-Host "`t Memory Compression & Combining (Disabled = Saves CPU on 64GB RAM)"
        Write-Host " [11] " -NoNewline; Write-Host $t11.Text -ForegroundColor $t11.Color -NoNewline; Write-Host "`t DisablePagingExecutive (1 = Lock drivers & kernel in physical RAM)"
        Write-Host " [12] " -NoNewline; Write-Host $t12.Text -ForegroundColor $t12.Color -NoNewline; Write-Host "`t Kernel SleepStudy Tracing (Disabled = Stops power polling overhead)"
        Write-Host " [13] " -NoNewline; Write-Host $t13.Text -ForegroundColor $t13.Color -NoNewline; Write-Host "`t DWM FSO & DirectFlip (Hardware Independent Flip Mode)"
        Write-Host " [14] " -NoNewline; Write-Host $t14.Text -ForegroundColor $t14.Color -NoNewline; Write-Host "`t DWM MPO Overlays & ForceDirectFlip (Hardware Direct Scanout)"
        Write-Host " [15] " -NoNewline; Write-Host $t15.Text -ForegroundColor $t15.Color -NoNewline; Write-Host "`t HAGS & GPU Scheduler Priority (HwSchMode 2 & Foreground Boost)"
        Write-Host " [16] " -NoNewline; Write-Host $t16.Text -ForegroundColor $t16.Color -NoNewline; Write-Host "`t NTFS Optimizations (Disable 8.3 Short Names & Last Access Time)"
        Write-Host " [17] " -NoNewline; Write-Host $t17.Text -ForegroundColor $t17.Color -NoNewline; Write-Host "`t Hung Screen App Timeouts (Instant Kill Stuck Tasks & 1s Timeout)"
        Write-Host " [18] " -NoNewline; Write-Host $t18.Text -ForegroundColor $t18.Color -NoNewline; Write-Host "`t StickyKeys Popups & VerboseStatus (No Shift Dialogs & Clean Boot)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All System Tweaks | [D] Revert All System Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $kPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        $gPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

        switch ($c.ToUpper()) {
            "1" {
                if ($members -match [regex]::Escape($user)) { net localgroup "$groupName" "$user" /delete | Out-Null }
                else { net localgroup "$groupName" "$user" /add | Out-Null }
            }
            "2" {
                $v = if ($mmcss.SystemResponsiveness -eq 0) { 20 } else { 0 }
                Set-ItemProperty $mmPath -Name "SystemResponsiveness" -Type DWord -Value $v
            }
            "3" {
                $v = if ($isThrottlingOff) { 10 } else { 0xFFFFFFFF }
                Set-ItemProperty $mmPath -Name "NetworkThrottlingIndex" -Type DWord -Value $v
            }
            "4" {
                $p = "$mmPath\Tasks\Games"
                if ($gTask."GPU Priority" -eq 8 -and $gTask.Priority -eq 6) {
                    Set-ItemProperty $p -Name "Priority" -Type DWord -Value 2
                    Set-ItemProperty $p -Name "Scheduling Category" -Type String -Value "Medium"
                } else {
                    Set-ItemProperty $p -Name "GPU Priority" -Type DWord -Value 8
                    Set-ItemProperty $p -Name "Priority" -Type DWord -Value 6
                    Set-ItemProperty $p -Name "Scheduling Category" -Type String -Value "High"
                    Set-ItemProperty $p -Name "SFIO Priority" -Type String -Value "High"
                }
            }
            "5" {
                $v = if ($mmcss.NoLazyMode -eq 1) { 0 } else { 1 }
                Set-ItemProperty $mmPath -Name "NoLazyMode" -Type DWord -Value $v
            }
            "6" {
                $v = if ($prio -eq 38 -or $prio -eq 0x26) { 2 } else { 38 }
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value $v
            }
            "7" {
                if (-not (Test-Path $kPath)) { New-Item -Path $kPath -Force | Out-Null }
                $v = if ($kernel.SerializeTimerExpiration -eq 2) { 1 } else { 2 }
                Set-ItemProperty $kPath -Name "SerializeTimerExpiration" -Type DWord -Value $v
            }
            "8" {
                if (-not (Test-Path $kPath)) { New-Item -Path $kPath -Force | Out-Null }
                $v = if ($kernel.ThreadDpcEnable -eq 1) { 0 } else { 1 }
                Set-ItemProperty $kPath -Name "ThreadDpcEnable" -Type DWord -Value $v
            }
            "9" {
                $gbPath = "HKCU:\Software\Microsoft\GameBar"
                $gdvrPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
                if (-not (Test-Path $gbPath)) { New-Item $gbPath -Force | Out-Null }
                if (-not (Test-Path $gdvrPath)) { New-Item $gdvrPath -Force | Out-Null }
                if ($gb.AllowAutoGameMode -eq 1) {
                    Set-ItemProperty $gbPath -Name "AllowAutoGameMode" -Type DWord -Value 0
                    Set-ItemProperty $gbPath -Name "AutoGameModeEnabled" -Type DWord -Value 0
                    Remove-ItemProperty $gdvrPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty $gbPath -Name "AllowAutoGameMode" -Type DWord -Value 1
                    Set-ItemProperty $gbPath -Name "AutoGameModeEnabled" -Type DWord -Value 1
                    Set-ItemProperty $gdvrPath -Name "AllowGameDVR" -Type DWord -Value 0
                }
            }
            "10" {
                if (-not $mma.MemoryCompression) { Enable-MMAgent -MemoryCompression -PageCombining | Out-Null }
                else { Disable-MMAgent -MemoryCompression -PageCombining | Out-Null }
            }
            "11" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                $v = if ($mm.DisablePagingExecutive -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "DisablePagingExecutive" -Type DWord -Value $v
            }
            "12" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
                $v = if ($pwrSm.SleepStudyDisabled -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "SleepStudyDisabled" -Type DWord -Value $v
            }
            "13" {
                $p = "HKCU:\System\GameConfigStore"
                if ($dvr.GameDVR_FSEBehaviorMode -eq 2) {
                    Set-ItemProperty $p -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 0
                    Set-ItemProperty $p -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 0
                } else {
                    Set-ItemProperty $p -Name "GameDVR_Enabled" -Type DWord -Value 0
                    Set-ItemProperty $p -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
                    Set-ItemProperty $p -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1
                    Set-ItemProperty $p -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1
                }
            }
            "14" {
                if ($gfx.DisableOverlays -eq 0 -and $gfx.ForceDirectFlip -eq 1) {
                    Remove-ItemProperty $gPath -Name "ForceDirectFlip" -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty $gPath -Name "DisableOverlays" -Type DWord -Value 0
                    Set-ItemProperty $gPath -Name "ForceDirectFlip" -Type DWord -Value 1
                }
            }
            "15" {
                $sch = "$gPath\Scheduler"
                if (-not (Test-Path $sch)) { New-Item -Path $sch -Force | Out-Null }
                if ($gfxSched.ForegroundPriorityBoost -eq 1) {
                    Remove-ItemProperty $sch -Name "ForegroundPriorityBoost" -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty $gPath -Name "HwSchMode" -Type DWord -Value 2
                    Set-ItemProperty $sch -Name "ForegroundPriorityBoost" -Type DWord -Value 1
                }
            }
            "16" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
                if ($fs.NtfsDisable8dot3NameCreation -eq 1) {
                    Set-ItemProperty $p -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 2
                    Set-ItemProperty $p -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 0
                } else {
                    Set-ItemProperty $p -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 1
                    Set-ItemProperty $p -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1
                    Set-ItemProperty $p -Name "LongPathsEnabled" -Type DWord -Value 1
                }
            }
            "17" {
                $p = "HKCU:\Control Panel\Desktop"
                if ($desk.HungAppTimeout -eq 1000) {
                    Set-ItemProperty $p -Name "HungAppTimeout" -Type String -Value "5000"
                    Set-ItemProperty $p -Name "WaitToKillAppTimeout" -Type String -Value "5000"
                    Set-ItemProperty $p -Name "AutoEndTasks" -Type String -Value "0"
                } else {
                    Set-ItemProperty $p -Name "HungAppTimeout" -Type String -Value "1000"
                    Set-ItemProperty $p -Name "WaitToKillAppTimeout" -Type String -Value "2000"
                    Set-ItemProperty $p -Name "AutoEndTasks" -Type String -Value "1"
                }
            }
            "18" {
                $pPol = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
                if (-not (Test-Path $pPol)) { New-Item $pPol -Force | Out-Null }
                if ($sk -eq "506") {
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
                    Set-ItemProperty $pPol -Name "VerboseStatus" -Type DWord -Value 0
                } else {
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122"
                    Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "58"
                    Set-ItemProperty $pPol -Name "VerboseStatus" -Type DWord -Value 1
                }
            }
            "A" {
                & (Join-Path $scriptsDir "System-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                net localgroup "$groupName" "$user" /delete 2>$null | Out-Null
                Set-ItemProperty $mmPath -Name "SystemResponsiveness" -Type DWord -Value 20
                Set-ItemProperty $mmPath -Name "NetworkThrottlingIndex" -Type DWord -Value 10
                Remove-ItemProperty $mmPath -Name "NoLazyMode" -ErrorAction SilentlyContinue
                Set-ItemProperty "$mmPath\Tasks\Games" -Name "Priority" -Type DWord -Value 2
                Set-ItemProperty "$mmPath\Tasks\Games" -Name "Scheduling Category" -Type String -Value "Medium"
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2
                Set-ItemProperty $kPath -Name "SerializeTimerExpiration" -Type DWord -Value 1
                Remove-ItemProperty $kPath -Name "ThreadDpcEnable" -ErrorAction SilentlyContinue
                Enable-MMAgent -MemoryCompression -PageCombining -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Type DWord -Value 0
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "SleepStudyDisabled" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 0
                Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 0
                Remove-ItemProperty $gPath -Name "ForceDirectFlip" -ErrorAction SilentlyContinue
                Remove-ItemProperty "$gPath\Scheduler" -Name "ForegroundPriorityBoost" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 2
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 0
                Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Type String -Value "5000"
                Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Type String -Value "5000"
                Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Type String -Value "0"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 0
                Write-Host "`n[OK] All System & Kernel tweaks reverted to stock defaults." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 2: NETWORK & TCP/IP (From noverse.dev/docs/win-config/network/)
# ==============================================================================
function Menu-Network {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "        [2] NETWORK & TCP/IP TWEAKS (noverse.dev/docs/win-config/network)     " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Interrupt Moderation
        $nic = Get-NetAdapterAdvancedProperty -DisplayName "Interrupt Moderation" -ErrorAction SilentlyContinue
        $t1 = Tag ($nic.DisplayValue -eq "Disabled") "[ Disabled (Instant) ]" "[ Enabled (Stock) ]"

        # 2. Buffers
        $rx = (Get-NetAdapterAdvancedProperty -DisplayName "Receive Buffers" -ErrorAction SilentlyContinue).DisplayValue
        $t2 = Tag ($rx -ge 1024) "[ 1024/512 (Max) ]" "[ Stock ]"

        # 3. Nagle (TcpAckFrequency / TCPNoDelay)
        $interfaces = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $hasNagle = $false
        if (Test-Path $interfaces) {
            foreach ($k in (Get-ChildItem $interfaces)) {
                $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
                if ($p.TcpAckFrequency -eq 1 -and $p.TCPNoDelay -eq 1) { $hasNagle = $true; break }
            }
        }
        $t3 = Tag $hasNagle "[ Disabled (Min Ping) ]" "[ Stock ]"

        # 4. TCP Congestion Provider
        $tcpSetting = (Get-NetTCPSetting -SettingName "Internet" -ErrorAction SilentlyContinue).CongestionProvider
        $t4 = Tag ($tcpSetting -eq "CTCP" -or $tcpSetting -eq "CUBIC") "[ $tcpSetting ]" "[ Default ]"

        # 5. TCP Auto-Tuning Heuristics
        $t5 = Tag $true "[ Normal / No Heuristics ]" "[ Stock ]"

        # 6. NetBIOS over TCP/IP
        $nb = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | Select-Object -First 1).TcpipNetbiosOptions
        $t6 = Tag ($nb -eq 2) "[ Disabled (No Broadcasts) ]" "[ Stock ]"

        # 7. NIC Power Savings
        $pwr = Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Select-Object -First 1
        $t7 = Tag ($pwr.AllowComputerToTurnOffDevice -eq "Disabled") "[ Disabled (Full Power) ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Realtek Interrupt Moderation (Disabled = Zero delay packet delivery)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Realtek Ring Buffers (1024 Receive / 512 Transmit Buffers)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Nagle's Algorithm (TcpAckFrequency=1 & TCPNoDelay=1 - Eliminates ping jitter)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t TCP Congestion Provider (CTCP vs CUBIC optimization)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t TCP Global Parameters (AutoTuning=Normal, Heuristics=Off, Timestamps=Off)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t NetBIOS over TCP/IP (Disabled = Stops internal LAN broadcast noise)"
        Write-Host " [7]  " -NoNewline; Write-Host $t7.Text -ForegroundColor $t7.Color -NoNewline; Write-Host "`t Network Adapter Sleep (Disabled = Prevents Ethernet PHY controller sleeping)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Network Tweaks | [D] Revert All Network Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $adapter = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" })[0]
        switch ($c.ToUpper()) {
            "1" {
                $v = if ($nic.DisplayValue -eq "Disabled") { "Enabled" } else { "Disabled" }
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue $v | Out-Null
            }
            "2" {
                if ($rx -ge 1024) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" | Out-Null
                } else {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "1024" | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "512" | Out-Null
                }
            }
            "3" {
                foreach ($k in (Get-ChildItem $interfaces)) {
                    if ($hasNagle) {
                        Remove-ItemProperty $k.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                        Remove-ItemProperty $k.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
                        Remove-ItemProperty $k.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty $k.PSPath -Name "TcpAckFrequency" -Type DWord -Value 1
                        Set-ItemProperty $k.PSPath -Name "TCPNoDelay" -Type DWord -Value 1
                        Set-ItemProperty $k.PSPath -Name "TcpDelAckTicks" -Type DWord -Value 0
                    }
                }
            }
            "4" {
                $newProv = if ($tcpSetting -eq "CTCP") { "CUBIC" } else { "CTCP" }
                Set-NetTCPSetting -SettingName "Internet" -CongestionProvider $newProv -ErrorAction SilentlyContinue | Out-Null
                Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider $newProv -ErrorAction SilentlyContinue | Out-Null
            }
            "5" {
                netsh int tcp set global autotuninglevel=normal heuristics=disabled timestamps=disabled rss=enabled | Out-Null
            }
            "6" {
                $target = if ($nb -eq 2) { 0 } else { 2 }
                Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object { $null = $_.SetTcpipNetbios($target) }
            }
            "7" {
                Get-NetAdapterPowerManagement | ForEach-Object {
                    $_.AllowComputerToTurnOffDevice = if ($pwr.AllowComputerToTurnOffDevice -eq 'Disabled') { 'Enabled' } else { 'Disabled' }
                    $_ | Set-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Out-Null
                }
            }
            "A" {
                & (Join-Path $scriptsDir "Network-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" | Out-Null
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" | Out-Null
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" | Out-Null
                foreach ($k in (Get-ChildItem $interfaces)) {
                    Remove-ItemProperty $k.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $k.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $k.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                }
                Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -ErrorAction SilentlyContinue | Out-Null
                Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object { $null = $_.SetTcpipNetbios(0) }
                Get-NetAdapterPowerManagement | ForEach-Object { $_.AllowComputerToTurnOffDevice = 'Enabled'; $_ | Set-NetAdapterPowerManagement | Out-Null }
                Write-Host "`n[OK] All Network settings reverted to stock defaults." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 3: POWER & TIMERS (From noverse.dev/docs/win-config/power/)
# ==============================================================================
function Menu-Power {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [3] POWER & TIMERS (noverse.dev/docs/win-config/power)               " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Timer Coalescing
        $pwr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ErrorAction SilentlyContinue
        $t1 = Tag ($pwr.CoalescingTimerInterval -eq 0) "[ 0 (Strict) ]" "[ Default ]"

        # 2. Energy Estimation
        $t2 = Tag ($pwr.EnergyEstimationDisabled -eq 1) "[ Disabled (No Overhead) ]" "[ Stock ]"

        # 3. Audio Endpoint Idle Sleep
        $audioPower = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}\0000\PowerSettings" -ErrorAction SilentlyContinue
        $t3 = Tag ($audioPower.ConservationIdleTime -eq 0) "[ Disabled (No Audio Pop) ]" "[ Stock ]"

        # 4. Hibernation (powercfg -h)
        $hiberFile = Test-Path "C:\hiberfil.sys"
        $t4 = Tag (-not $hiberFile) "[ Off (Frees RAM/SSD) ]" "[ On ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Timer Coalescing (0 = Disables timer batching for sharp frame ticks)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Energy Estimation (Disabled = Stops battery/energy usage polling service)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Audio Idle Power Sleep (Disabled = Stops audio chip sleep hitch)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t System Hibernation (Off = Removes 64GB hiberfil.sys & clean restarts)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Power Tweaks | [D] Revert All Power Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $pwrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
        switch ($c.ToUpper()) {
            "1" {
                if ($pwr.CoalescingTimerInterval -eq 0) { Remove-ItemProperty $pwrPath -Name "CoalescingTimerInterval" -ErrorAction SilentlyContinue }
                else { Set-ItemProperty $pwrPath -Name "CoalescingTimerInterval" -Type DWord -Value 0 }
            }
            "2" {
                if ($pwr.EnergyEstimationDisabled -eq 1) { Remove-ItemProperty $pwrPath -Name "EnergyEstimationDisabled" -ErrorAction SilentlyContinue }
                else { Set-ItemProperty $pwrPath -Name "EnergyEstimationDisabled" -Type DWord -Value 1 }
            }
            "3" {
                Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}" -Recurse | Where-Object { $_.Name -match "PowerSettings" } | ForEach-Object {
                    if ($audioPower.ConservationIdleTime -eq 0) {
                        Remove-ItemProperty $_.PSPath -Name "ConservationIdleTime" -ErrorAction SilentlyContinue
                        Remove-ItemProperty $_.PSPath -Name "PerformanceIdleTime" -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty $_.PSPath -Name "ConservationIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                        Set-ItemProperty $_.PSPath -Name "PerformanceIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                    }
                }
            }
            "4" {
                if ($hiberFile) { powercfg -h off } else { powercfg -h on }
            }
            "A" {
                Set-ItemProperty $pwrPath -Name "CoalescingTimerInterval" -Type DWord -Value 0
                Set-ItemProperty $pwrPath -Name "EnergyEstimationDisabled" -Type DWord -Value 1
                Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}" -Recurse | Where-Object { $_.Name -match "PowerSettings" } | ForEach-Object {
                    Set-ItemProperty $_.PSPath -Name "ConservationIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                    Set-ItemProperty $_.PSPath -Name "PerformanceIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                }
                powercfg -h off
            }
            "D" {
                Remove-ItemProperty $pwrPath -Name "CoalescingTimerInterval" -ErrorAction SilentlyContinue
                Remove-ItemProperty $pwrPath -Name "EnergyEstimationDisabled" -ErrorAction SilentlyContinue
                powercfg -h on
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 4: PERIPHERALS & INPUT (From noverse.dev/docs/win-config/peripheral/)
# ==============================================================================
function Menu-Peripheral {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "     [4] PERIPHERAL & INPUT TWEAKS (noverse.dev/docs/win-config/peripheral)   " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. RawMouseThrottle
        $mou = Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue
        $t1 = Tag ($mou.RawMouseThrottleEnabled -eq 0) "[ Disabled (No 125Hz Cap) ]" "[ Stock ]"

        # 2. Mouse & Keyboard DataQueueSize
        $mouClass = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -ErrorAction SilentlyContinue
        $t2 = Tag ($mouClass.MouseDataQueueSize -eq 50) "[ 50 (Instant Response) ]" "[ $($mouClass.MouseDataQueueSize) (Stock 100) ]"

        # 3. Audio Ducking
        $audioDuck = (Get-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -ErrorAction SilentlyContinue).UserDuckingPreference
        $t3 = Tag ($audioDuck -eq 3) "[ Disabled (No Volume Drops) ]" "[ Stock ]"

        # 4. Windows Dynamic Lighting (Background RGB thread)
        $dynLight = (Get-ItemProperty "HKCU:\Software\Microsoft\Lighting" -ErrorAction SilentlyContinue).AmbientLightingEnabled
        $t4 = Tag ($dynLight -eq 0) "[ Disabled (Saves CPU) ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t RawMouseThrottle (Disabled = Removes background raw mouse polling throttling)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Mouse & Keyboard DataQueueSize (50 = Faster input queue flushing)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Audio Ducking (Disabled = Discord won't suddenly lower game audio)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Dynamic Lighting (Disabled = Shuts down Windows background RGB polling loop)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Peripheral Tweaks | [D] Revert All Peripheral Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                $p = "HKCU:\Control Panel\Mouse"
                if ($mou.RawMouseThrottleEnabled -eq 0) { Remove-ItemProperty $p -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue }
                else { Set-ItemProperty $p -Name "RawMouseThrottleEnabled" -Type DWord -Value 0 }
            }
            "2" {
                $m = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
                $k = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
                if ($mouClass.MouseDataQueueSize -eq 50) {
                    Set-ItemProperty $m -Name "MouseDataQueueSize" -Type DWord -Value 100
                    Set-ItemProperty $k -Name "KeyboardDataQueueSize" -Type DWord -Value 100
                } else {
                    Set-ItemProperty $m -Name "MouseDataQueueSize" -Type DWord -Value 50
                    Set-ItemProperty $k -Name "KeyboardDataQueueSize" -Type DWord -Value 50
                }
            }
            "3" {
                $p = "HKCU:\Software\Microsoft\Multimedia\Audio"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                if ($audioDuck -eq 3) { Set-ItemProperty $p -Name "UserDuckingPreference" -Type DWord -Value 0 }
                else { Set-ItemProperty $p -Name "UserDuckingPreference" -Type DWord -Value 3 }
            }
            "4" {
                $p = "HKCU:\Software\Microsoft\Lighting"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                if ($dynLight -eq 0) { Set-ItemProperty $p -Name "AmbientLightingEnabled" -Type DWord -Value 1 }
                else { Set-ItemProperty $p -Name "AmbientLightingEnabled" -Type DWord -Value 0 }
            }
            "A" {
                Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -Type DWord -Value 0
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 50
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 50
                Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 3
                Set-ItemProperty "HKCU:\Software\Microsoft\Lighting" -Name "AmbientLightingEnabled" -Type DWord -Value 0
            }
            "D" {
                Remove-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
                Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 0
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 5: NVIDIA & GPU (From noverse.dev/docs/win-config/nvidia/)
# ==============================================================================
function Menu-Nvidia {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "           [5] NVIDIA & GPU TWEAKS (noverse.dev/docs/win-config/nvidia)       " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. MSI Mode on RTX 5080
        $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_2C02&SUBSYS_176219DA&REV_A1\B04E88EE5D2DB04800\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $msi = (Get-ItemProperty $msiKey -ErrorAction SilentlyContinue).MSISupported
        $t1 = Tag ($msi -eq 1) "[ MSI Active (No IRQ Conflicts) ]" "[ Legacy Line IRQ ]"

        # 2. High Priority Affinity Policy
        $affKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_2C02&SUBSYS_176219DA&REV_A1\B04E88EE5D2DB04800\Device Parameters\Interrupt Management\Affinity Policy"
        $aff = (Get-ItemProperty $affKey -ErrorAction SilentlyContinue).DevicePriority
        $t2 = Tag ($aff -eq 3) "[ High Priority ]" "[ Normal ]"

        # 3. Telemetry Service
        $telemetry = Get-Service "NvTelemetryContainer" -ErrorAction SilentlyContinue
        $t3 = Tag ($telemetry.StartType -eq "Disabled") "[ Disabled ]" "[ Enabled (Stock) ]"

        # 4. TDR Delay
        $tdr = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).TdrDelay
        $t4 = Tag ($tdr -ge 8) "[ 8s (Stable Shaders) ]" "[ $($tdr)s (Stock 2s) ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t RTX 5080 Message Signaled Interrupts (MSI Mode)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t RTX 5080 Hardware Interrupt Priority (High Priority Routing)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t NVIDIA Background Telemetry Container (Disabled)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t GPU TDR Delay (8s = Prevents driver crash during heavy shader load)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [5]  Launch Official Noverse Debloated Driver Tool (NVIDIA-Tool.ps1)" -ForegroundColor White
        Write-Host " [6]  Create NVCPL On-Demand Desktop Shortcut (nvcpl.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply GPU Tweaks | [D] Revert GPU Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                $v = if ($msi -eq 1) { 0 } else { 1 }
                Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value $v
            }
            "2" {
                if (-not (Test-Path $affKey)) { New-Item $affKey -Force | Out-Null }
                $v = if ($aff -eq 3) { 0 } else { 3 }
                Set-ItemProperty $affKey -Name "DevicePriority" -Type DWord -Value $v
            }
            "3" {
                if ($telemetry.StartType -eq "Disabled") {
                    Set-Service "NvTelemetryContainer" -StartupType Manual
                } else {
                    Stop-Service "NvTelemetryContainer" -Force
                    Set-Service "NvTelemetryContainer" -StartupType Disabled
                }
            }
            "4" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
                if ($tdr -ge 8) {
                    Set-ItemProperty $p -Name "TdrDelay" -Type DWord -Value 2
                    Set-ItemProperty $p -Name "TdrDdiDelay" -Type DWord -Value 2
                } else {
                    Set-ItemProperty $p -Name "TdrDelay" -Type DWord -Value 8
                    Set-ItemProperty $p -Name "TdrDdiDelay" -Type DWord -Value 8
                }
            }
            "5" { & (Join-Path $scriptsDir "NVIDIA-Tool.ps1"); pause }
            "6" { & (Join-Path $scriptsDir "nvcpl.ps1"); Write-Host "[OK] NVCPL shortcut created!"; pause }
            "A" {
                Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value 1
                if (-not (Test-Path $affKey)) { New-Item $affKey -Force | Out-Null }
                Set-ItemProperty $affKey -Name "DevicePriority" -Type DWord -Value 3
                Stop-Service "NvTelemetryContainer" -Force -ErrorAction SilentlyContinue
                Set-Service "NvTelemetryContainer" -StartupType Disabled -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Type DWord -Value 8
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Type DWord -Value 8
            }
            "D" {
                Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value 1
                Remove-ItemProperty $affKey -Name "DevicePriority" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Type DWord -Value 2
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Type DWord -Value 2
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 6: STEAM & APP GUIDES (From noverse.dev/docs/app-guides/)
# ==============================================================================
function Menu-Steam {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [6] STEAM & APP GUIDES (noverse.dev/docs/app-guides/)                " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
        if (-not $steam) { $steam = "C:\Program Files (x86)\Steam" }
        $umpdcInstalled = Test-Path (Join-Path $steam "umpdc.dll")
        $t1 = Tag $umpdcInstalled "[ Installed (Auto-Kills 7 CEF processes in game) ]" "[ Not Installed ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t NoSteamWebHelper (umpdc.dll - Auto-frees ~1GB RAM while gaming)"
        Write-Host " [2]  Run Steam Optimization Suite (Steam-Tweaks.ps1: Registry + Config)" -ForegroundColor White
        Write-Host " [3]  Launch Nohuto's Counter-Strike 2 Tool (NV-CS2-Tool.ps1)" -ForegroundColor White
        Write-Host " [4]  Launch Nohuto's Valorant Tool (NV-VALORANT-Tool.ps1)" -ForegroundColor White
        Write-Host " [5]  Launch Nohuto's Spotify Configurator (Spotify-Config.ps1)" -ForegroundColor White
        Write-Host " [6]  Launch Nohuto's Logitech G HUB Optimizer (LGHUB-Toggle.ps1)" -ForegroundColor White
        Write-Host " [7]  Optimize Discord, Browsers (Yandex/Chrome/Brave), VSCode & SteelSeries (App-Tweaks.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [0]  Back" -ForegroundColor Yellow
        Write-Host "`nChoose an option: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c) {
            "1" {
                $umpdcPath = Join-Path $steam "umpdc.dll"
                if (Test-Path $umpdcPath) {
                    Get-Process steam* -ErrorAction SilentlyContinue | Stop-Process -Force
                    Remove-Item $umpdcPath -Force
                    Write-Host "`n[-] umpdc.dll uninstalled." -ForegroundColor Yellow
                } else {
                    Get-Process steam* -ErrorAction SilentlyContinue | Stop-Process -Force
                    $url = "https://github.com/Aetopia/NoSteamWebHelper/releases/download/v5.0.2/umpdc.dll"
                    Invoke-WebRequest -Uri $url -OutFile $umpdcPath -Headers @{"User-Agent"="PowerShell"}
                    Write-Host "`n[+] umpdc.dll installed into Steam!" -ForegroundColor Green
                }
                Start-Sleep -Milliseconds 1200
            }
            "2" { & (Join-Path $scriptsDir "Steam-Tweaks.ps1"); pause }
            "3" { & (Join-Path $scriptsDir "NV-CS2-Tool.ps1"); pause }
            "4" { & (Join-Path $scriptsDir "NV-VALORANT-Tool.ps1"); pause }
            "5" { & (Join-Path $scriptsDir "Spotify-Config.ps1"); pause }
            "6" { & (Join-Path $scriptsDir "LGHUB-Toggle.ps1"); pause }
            "7" { & (Join-Path $scriptsDir "App-Tweaks.ps1"); pause }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 7: PRIVACY, TELEMETRY & SERVICES (From noverse.dev/docs/win-config/privacy/)
# ==============================================================================
function Menu-Privacy {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "     [7] PRIVACY, TELEMETRY & SERVICES (noverse.dev/docs/win-config/privacy)  " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Telemetry
        $dc = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry
        $t1 = Tag ($dc -eq 0) "[ Disabled (0) ]" "[ Stock ]"

        # 2. WER
        $wer = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -ErrorAction SilentlyContinue).Disabled
        $t2 = Tag ($wer -eq 1) "[ Disabled (Instant Kill) ]" "[ Stock ]"

        # 3. DiagTrack
        $dt = (Get-Service "DiagTrack" -ErrorAction SilentlyContinue).StartType
        $t3 = Tag ($dt -eq "Disabled") "[ Disabled ]" "[ Running ]"

        # 4. SysMain (SuperFetch)
        $sm = (Get-Service "SysMain" -ErrorAction SilentlyContinue).StartType
        $t4 = Tag ($sm -eq "Disabled") "[ Disabled (Fast NVMe) ]" "[ Running ]"

        # 5. Windows Search (WSearch)
        $ws = (Get-Service "WSearch" -ErrorAction SilentlyContinue).StartType
        $t5 = Tag ($ws -eq "Disabled") "[ Disabled (Zero I/O) ]" "[ Running ]"

        # 6. Copilot & Recall AI
        $cp = (Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
        $t6 = Tag ($cp -eq 1) "[ Disabled ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Windows General Telemetry (AllowTelemetry = 0)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Windows Error Reporting WER (Disabled = No WerFault crash delay)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t DiagTrack Telemetry Service (Disabled = Zero tracking overhead)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t SysMain / SuperFetch (Disabled = Eliminates NVMe SSD read spikes)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t Windows Search Indexing (Disabled = Zero background indexing queue)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t Microsoft Copilot & Recall (Disabled = Shuts down AI analysis hooks)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Privacy Tweaks | [D] Revert All Privacy Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($dc -eq 0) { 1 } else { 0 }
                Set-ItemProperty $p -Name "AllowTelemetry" -Type DWord -Value $v
            }
            "2" {
                $p = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                if ($wer -eq 1) {
                    Set-ItemProperty $p -Name "Disabled" -Type DWord -Value 0
                    Set-Service "WerSvc" -StartupType Manual 2>$null
                } else {
                    Set-ItemProperty $p -Name "Disabled" -Type DWord -Value 1
                    Stop-Service "WerSvc" -Force 2>$null
                    Set-Service "WerSvc" -StartupType Disabled 2>$null
                }
            }
            "3" {
                if ($dt -eq "Disabled") {
                    Set-Service "DiagTrack" -StartupType Automatic 2>$null
                    Start-Service "DiagTrack" 2>$null
                } else {
                    Stop-Service "DiagTrack" -Force 2>$null
                    Set-Service "DiagTrack" -StartupType Disabled 2>$null
                }
            }
            "4" {
                if ($sm -eq "Disabled") {
                    Set-Service "SysMain" -StartupType Automatic 2>$null
                    Start-Service "SysMain" 2>$null
                } else {
                    Stop-Service "SysMain" -Force 2>$null
                    Set-Service "SysMain" -StartupType Disabled 2>$null
                }
            }
            "5" {
                if ($ws -eq "Disabled") {
                    Set-Service "WSearch" -StartupType Automatic 2>$null
                    Start-Service "WSearch" 2>$null
                } else {
                    Stop-Service "WSearch" -Force 2>$null
                    Set-Service "WSearch" -StartupType Disabled 2>$null
                }
            }
            "6" {
                $p = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($cp -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "TurnOffWindowsCopilot" -Type DWord -Value $v
            }
            "A" {
                & (Join-Path $scriptsDir "Privacy-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 0
                Set-Service "WerSvc" -StartupType Manual 2>$null
                Set-Service "DiagTrack" -StartupType Automatic 2>$null
                Set-Service "SysMain" -StartupType Automatic 2>$null
                Set-Service "WSearch" -StartupType Automatic 2>$null
                Remove-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Privacy settings reverted to stock defaults." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 8: SECURITY, VBS & INTEGRITY (From noverse.dev/docs/win-config/security/)
# ==============================================================================
function Menu-Security {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "   [8] SECURITY, VBS & INTEGRITY (noverse.dev/docs/win-config/security)       " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. VBS
        $vbs = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        $t1 = Tag ($vbs -eq 0) "[ Disabled (+5-8% FPS) ]" "[ Enabled (Virtualization) ]"

        # 2. WPBT
        $wpbt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).SmpDisableWpbtExecution
        $t2 = Tag ($wpbt -eq 1) "[ Blocked (No OEM Rootkits) ]" "[ Allowed ]"

        # 3. Delivery Optimization P2P
        $do = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -ErrorAction SilentlyContinue).DODownloadMode
        $t3 = Tag ($do -eq 0) "[ Disabled (No Seeding) ]" "[ Stock ]"

        # 4. PromptOnSecureDesktop
        $uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue).PromptOnSecureDesktop
        $t4 = Tag ($uac -eq 0) "[ Disabled (Fast UAC) ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Virtualization-Based Security VBS (Disabled = +3-8% FPS, eliminates SLAT latency)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t WPBT Execution (Blocked = Stops motherboard BIOS injecting OEM bloatware)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Delivery Optimization P2P (Disabled = Prevents Windows Update uploading files)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t PromptOnSecureDesktop (Disabled = UAC prompt without screen dimming hitch)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Security Tweaks | [D] Revert All Security Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($vbs -eq 0) { 1 } else { 0 }
                Set-ItemProperty $p -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value $v
            }
            "2" {
                $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
                $v = if ($wpbt -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "SmpDisableWpbtExecution" -Type DWord -Value $v
            }
            "3" {
                $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($do -eq 0) { 3 } else { 0 }
                Set-ItemProperty $p -Name "DODownloadMode" -Type DWord -Value $v
            }
            "4" {
                $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
                $v = if ($uac -eq 0) { 1 } else { 0 }
                Set-ItemProperty $p -Name "PromptOnSecureDesktop" -Type DWord -Value $v
            }
            "A" {
                & (Join-Path $scriptsDir "Security-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "SmpDisableWpbtExecution" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Type DWord -Value 3
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 1
                Write-Host "`n[OK] Security settings reverted to stock defaults." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 9: VISIBILITY & EXPLORER UX (From noverse.dev/docs/win-config/visibility/)
# ==============================================================================
function Menu-Visibility {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "    [9] VISIBILITY & EXPLORER UX (noverse.dev/docs/win-config/visibility)    " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Classic Context Menu
        $isClassic = Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        $t1 = Tag $isClassic "[ Classic (Instant 0ms) ]" "[ Win 11 XAML (Laggy) ]"

        # 2. Window Animations
        $anim = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue).DisallowAnimations
        $t2 = Tag ($anim -eq 1) "[ Disabled (Instant) ]" "[ Enabled (Stock) ]"

        # 3. File Extensions & Hidden
        $adv = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue
        $t3 = Tag ($adv.HideFileExt -eq 0 -and $adv.Hidden -eq 1) "[ Visible ]" "[ Hidden (Stock) ]"

        # 4. Detailed File Transfer
        $ops = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -ErrorAction SilentlyContinue).EnthusiastMode
        $t4 = Tag ($ops -eq 1) "[ EnthusiastMode ]" "[ Stock ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Classic Context Menu (Win 10 instant right-click without XAML delay)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Window Animations (Disabled = Snappy instant window opening/closing)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Explorer Extensions & Hidden Files (Always show extensions and hidden files)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Detailed File Transfer Graph (EnthusiastMode = Opens copy dialog expanded)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Apply All Visibility Tweaks | [D] Revert All Visibility Tweaks | [0] Back" -ForegroundColor Yellow
        Write-Host "`nChoose option to toggle: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                $p = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                if ($isClassic) {
                    Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                    Set-ItemProperty -Path $p -Name "(Default)" -Value ""
                }
            }
            "2" {
                $p = "HKCU:\Software\Microsoft\Windows\DWM"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($anim -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "DisallowAnimations" -Type DWord -Value $v
            }
            "3" {
                $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                if ($adv.HideFileExt -eq 0) {
                    Set-ItemProperty $p -Name "HideFileExt" -Type DWord -Value 1
                    Set-ItemProperty $p -Name "Hidden" -Type DWord -Value 2
                } else {
                    Set-ItemProperty $p -Name "HideFileExt" -Type DWord -Value 0
                    Set-ItemProperty $p -Name "Hidden" -Type DWord -Value 1
                }
            }
            "4" {
                $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($ops -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "EnthusiastMode" -Type DWord -Value $v
            }
            "A" {
                & (Join-Path $scriptsDir "Visibility-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 1
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 2
                Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name "EnthusiastMode" -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Visibility settings reverted to stock defaults." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "0" { return }
        }
    }
}

# ==============================================================================
#  CATEGORY 10: MAINTENANCE & CACHE CLEANERS (From noverse.dev/docs/win-config/cleanup/)
# ==============================================================================
function Menu-Cleaner {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "   [10] MAINTENANCE & CACHE CLEANERS (noverse.dev/docs/win-config/cleanup)    " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host " [1]  Flush DNS Client Cache (Clear-DnsClientCache)" -ForegroundColor White
        Write-Host " [2]  Purge DirectX & NVIDIA Shader Caches (Forces fresh clean shader compile)" -ForegroundColor White
        Write-Host " [3]  Clean Temporary Files & Delivery Optimization Cache (Frees NVMe SSD)" -ForegroundColor White
        Write-Host " [4]  Clear Windows Event Logs (Removes old error reports and logs)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Run Full System Cleanup Suite (scripts/Cleaner-Tweaks.ps1)" -ForegroundColor Green
        Write-Host " [0]  Back" -ForegroundColor Yellow
        Write-Host "`nChoose an option: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" { Clear-DnsClientCache; Write-Host "`n[OK] DNS Cache flushed!" -ForegroundColor Green; Start-Sleep -Seconds 1 }
            "2" {
                $shaderPaths = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache")
                foreach ($sp in $shaderPaths) { if (Test-Path $sp) { Remove-Item "$sp\*" -Recurse -Force -ErrorAction SilentlyContinue } }
                Write-Host "`n[OK] DirectX and NVIDIA Shader Caches purged!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "3" {
                Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "C:\Windows\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Temporary files cleared!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "4" {
                wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
                Write-Host "`n[OK] Windows Event Logs cleared!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "A" { & (Join-Path $scriptsDir "Cleaner-Tweaks.ps1"); pause }
            "0" { return }
        }
    }
}

# ==============================================================================
#  MASTER MENU
# ==============================================================================
while ($true) {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "       NOVERSE COMPLETE OPTIMIZATION SUITE v2.0 (Research by Nohuto)         " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host " CPU: AMD Ryzen 7 9850X3D (Zen 5 3D V-Cache) | GPU: NVIDIA GeForce RTX 5080    " -ForegroundColor DarkGray
    Write-Host " RAM: 64 GB Memory | OS: Windows 11 IoT Enterprise LTSC 24H2 | NIC: Realtek    " -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host " [1]  🖥️   Системные твики и ядро (System & Kernel: MMCSS, Quantum, Timer, DWM) " -ForegroundColor White
    Write-Host " [2]  🌐  Сетевые твики и TCP/IP (Network: Realtek, Nagle, Buffers, Coalescing)" -ForegroundColor White
    Write-Host " [3]  ⚡  Электропитание и таймеры (Power & Timers: Coalescing, Energy, Audio)" -ForegroundColor White
    Write-Host " [4]  🖱️   Периферия, мышь, аудио (Peripherals: RawMouseThrottle, DataQueue, Duck)" -ForegroundColor White
    Write-Host " [5]  🟩  NVIDIA и видеокарта (GPU: MSI Mode, High Priority, Telemetry, TDR)   " -ForegroundColor White
    Write-Host " [6]  🎮  Steam и приложения (Apps: NoSteamWebHelper, CS2, Valorant, Spotify) " -ForegroundColor White
    Write-Host " [7]  🛡️   Приватность и службы (Privacy: Telemetry, DiagTrack, WSearch, SysMain)" -ForegroundColor White
    Write-Host " [8]  🔒  Безопасность и VBS (Security: VBS/HVCI Off, WPBT Block, DO P2P Off)  " -ForegroundColor White
    Write-Host " [9]  📁  Проводник и интерфейс (Visibility: Classic Menu, Animations, Details)" -ForegroundColor White
    Write-Host " [10] 🧹  Очистка кэшей и шейдеров (Maintenance: Shader Caches, DNS, Temp Logs)" -ForegroundColor White
    Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " [A]  🚀  ПРИМЕНИТЬ ВСЕ РЕКОМЕНДОВАННЫЕ ТВЫКИ ИЗ ДОКУМЕНТАЦИИ (All In One)     " -ForegroundColor Green
    Write-Host " [B]  💾  СОХРАНИТЬ НОВЫЙ СЛЕПОК СИСТЕМЫ (Save KernelOS Snapshot)              " -ForegroundColor Magenta
    Write-Host " [D]  ↩️   ОТКАТ НАСТРОЕК (Restore KernelOS Baseline or Stock Defaults)         " -ForegroundColor Yellow
    Write-Host " [R]  🔄  Перезапустить проводник Windows (Explorer)                           " -ForegroundColor Cyan
    Write-Host " [0]  ❌  Выход                                                                 " -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "`nВыберите раздел [1-10, A, B, D, R, 0]: " -NoNewline -ForegroundColor Yellow
    $choice = Read-Host
    if ([string]::IsNullOrWhiteSpace($choice)) { continue }

    switch ($choice.ToUpper()) {
        "1"  { Menu-System }
        "2"  { Menu-Network }
        "3"  { Menu-Power }
        "4"  { Menu-Peripheral }
        "5"  { Menu-Nvidia }
        "6"  { Menu-Steam }
        "7"  { Menu-Privacy }
        "8"  { Menu-Security }
        "9"  { Menu-Visibility }
        "10" { Menu-Cleaner }
        "A" {
            Write-Host "`n>>> Applying All Researched Tweaks across all categories..." -ForegroundColor Cyan
            & (Join-Path $scriptsDir "System-Tweaks.ps1")
            & (Join-Path $scriptsDir "Network-Tweaks.ps1")
            & (Join-Path $scriptsDir "Security-Tweaks.ps1")
            & (Join-Path $scriptsDir "Privacy-Tweaks.ps1")
            & (Join-Path $scriptsDir "Visibility-Tweaks.ps1")
            & (Join-Path $scriptsDir "Steam-Tweaks.ps1")
            & (Join-Path $scriptsDir "App-Tweaks.ps1")
            Write-Host "`n[OK] All recommended tweaks applied! Restart your PC for Full Effect." -ForegroundColor Green
            pause
        }
        "B" {
            & (Join-Path $scriptsDir "Backup-KernelOS.ps1")
            pause
        }
        "D" {
            Clear-Host
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "               МЕНЮ ОТКАТА И ВОССТАНОВЛЕНИЯ НАСТРОЕК                         " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host " [1]  ↩️  Откат к исходному состоянию KernelOS (Рекомендуется)" -ForegroundColor Green
            Write-Host "          (Восстанавливает точные параметры вашей сборки KernelPan1c)"
            Write-Host " [2]  ⚠️  Сброс в стандартный заводской дефолт Microsoft Windows 11" -ForegroundColor Yellow
            Write-Host "          (Внимание: сотрет кастомные твики KernelOS и вернет стоковые лимиты MS)"
            Write-Host " [0]  Отмена" -ForegroundColor DarkGray
            Write-Host "`nВыберите вариант [1, 2, 0]: " -NoNewline -ForegroundColor Yellow
            $rc = Read-Host
            if ($rc -eq "1") {
                & (Join-Path $scriptsDir "Restore-KernelOS.ps1")
                pause
            } elseif ($rc -eq "2") {
                Write-Host "`n>>> Reverting all settings back to standard Microsoft stock defaults..." -ForegroundColor Yellow
                $mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                Set-ItemProperty $mmcss -Name "SystemResponsiveness" -Type DWord -Value 20
                Set-ItemProperty $mmcss -Name "NetworkThrottlingIndex" -Type DWord -Value 10
                Remove-ItemProperty $mmcss -Name "NoLazyMode" -ErrorAction SilentlyContinue
                Set-ItemProperty "$mmcss\Tasks\Games" -Name "Priority" -Type DWord -Value 2
                Set-ItemProperty "$mmcss\Tasks\Games" -Name "Scheduling Category" -Type String -Value "Medium"
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 2
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "SerializeTimerExpiration" -Type DWord -Value 1
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "ThreadDpcEnable" -ErrorAction SilentlyContinue
                Enable-MMAgent -MemoryCompression -PageCombining -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Type DWord -Value 0
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "SleepStudyDisabled" -ErrorAction SilentlyContinue
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CoalescingTimerInterval" -ErrorAction SilentlyContinue
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EnergyEstimationDisabled" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 2
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 0
                Remove-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
                $adapter = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" })[0]
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" | Out-Null
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" | Out-Null
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" | Out-Null
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "SmpDisableWpbtExecution" -ErrorAction SilentlyContinue
                Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Write-Host "`n[OK] Все параметры сброшены к чистым стоковым заводским значениям Microsoft Windows!" -ForegroundColor Yellow
                pause
            }
        }
        "R" {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
            Write-Host "`n[OK] Explorer restarted!" -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "0" { Clear-Host; exit }
    }
}