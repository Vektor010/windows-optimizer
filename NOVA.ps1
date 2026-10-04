#Requires -Version 5.1
<#
==============================================================================
ЧТО ДЕЛАЕТ:
  Главный интерактивный оптимизатор и оркестратор системы Gaming & System Optimizer (v2.1).
==============================================================================
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Menu', 'All', 'Backup', 'RestoreKernelOS', 'RestoreSnapshot', 'ResetDefault', 'Status')]
    [string]$Action = 'Menu',

    [Parameter()]
    [switch]$NonInteractive
)

# --- Self-Elevation ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
# --- Set Encoding ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "SilentlyContinue"

fltmc >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Ошибка: Требуются права Администратора!" -ForegroundColor Red
    if (-not $NonInteractive) { pause }
    exit 1
}

try { $Host.UI.RawUI.WindowTitle = "Gaming & System Optimizer v2.1" } catch { $null = $_ }
$scriptsDir = Join-Path $PSScriptRoot "scripts"

function Tag($cond, $onText="[ ВКЛ ]", $offText="[ ВЫКЛ ]") {
    if ($cond) { return @{ Text = $onText; Color = "Green" } }
    else { return @{ Text = $offText; Color = "DarkGray" } }
}

# ==============================================================================
#  РАЗДЕЛ 1: СИСТЕМА И ЯДРО
# ==============================================================================

function Menu-Nova {
  
# --- Cache Hardware Info ---
if (-not $global:HardwareCached) {
    $global:SysCpu = try { ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' ').Trim() } catch { "CPU" }
    $global:SysGpu = try { (Get-PnpDevice -Class Display -PresentOnly | Where-Object { $_.InstanceId -like "PCI\*" } | Select-Object -First 1).FriendlyName } catch { "GPU" }
    $global:SysRam = try { "$([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)) GB" } catch { "RAM" }
    $global:SysNic = try { (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).Name } catch { "Ethernet" }
    $global:HardwareCached = $true
}
  while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "                 УДАЛЕНИЕ ИИ И UWP МУСОРА (AI & UWP DEBLOAT)                  " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        
        $recall = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ErrorAction SilentlyContinue
        $t1 = Tag ($recall.DisableAIDataAnalysis -eq 1) "[ ОТКЛЮЧЕН ]" "[ ВКЛЮЧЕН  ]"
        
        $copilot = Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ErrorAction SilentlyContinue
        $t2 = Tag ($copilot.TurnOffWindowsCopilot -eq 1) "[ ОТКЛЮЧЕН ]" "[ ВКЛЮЧЕН  ]"
        
        $notepadUWP = Get-AppxPackage *Microsoft.WindowsNotepad*
        $t3 = Tag ($null -eq $notepadUWP) "[ КЛАССИКА ]" "[ UWP (НОВЫЙ) ]"
        
        $calcUWP = Get-AppxPackage *Microsoft.WindowsCalculator*
        $t4 = Tag ($null -eq $calcUWP) "[ КЛАССИКА ]" "[ UWP (НОВЫЙ) ]"
        
        $photoReg = Test-Path "HKCR:\Applications\photoviewer.dll\shell\open"
        $t5 = Tag $photoReg "[ ПРИМЕНЕН ]" "[ СТАНДАРТ ]"

        $wmpUWP = Get-AppxPackage *Microsoft.ZuneVideo*
        $t6 = Tag ($null -eq $wmpUWP) "[ КЛАССИКА ]" "[ UWP (НОВЫЙ) ]"

        Write-Host " [1]   🧠    " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "   Отключить AI Data Analysis и Recall (Windows 11)"
        Write-Host " [2]   🤖    " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "   Отключить Windows Copilot и удалить провайдер"
        Write-Host " [3]   📝    " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "   Удалить новый Блокнот (Возврат к классическому)"
        Write-Host " [4]   🧮    " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "   Удалить новый Калькулятор (Возврат к классическому)"
        Write-Host " [5]   🖼️    " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "   Включить классический Просмотр Фотографий Windows"
        Write-Host " [6]   🎵    " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "   Удалить новый плеер (Возврат к классическому WMP)"
        
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]   🚀    Применить все Ultra-твики разом" -ForegroundColor Green
        Write-Host " [Q]   ❌    Назад в меню" -ForegroundColor DarkGray
        Write-Host "`nВыберите пункт: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        
        if ($c -eq 'Q' -or $c -eq 'q') { break }
        
        switch ($c.ToUpper()) {
            "1" {
                $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
                if ($recall.DisableAIDataAnalysis -eq 1) {
                    Remove-ItemProperty $p -Name "DisableAIDataAnalysis" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $p -Name "AllowRecallEnablement" -ErrorAction SilentlyContinue
                } else {
                    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                    Set-ItemProperty $p -Name "DisableAIDataAnalysis" -Type DWord -Value 1
                    Set-ItemProperty $p -Name "AllowRecallEnablement" -Type DWord -Value 0
                }
                Write-Host "`n[OK] Настройки Recall изменены!" -ForegroundColor Green; Start-Sleep 1
            }
            "2" {
                $p = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
                $pAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                if ($copilot.TurnOffWindowsCopilot -eq 1) {
                    Remove-ItemProperty $p -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $pAdv -Name "ShowCopilotButton" -ErrorAction SilentlyContinue
                } else {
                    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                    Set-ItemProperty $p -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
                    if (-not (Test-Path $pAdv)) { New-Item -Path $pAdv -Force | Out-Null }
                    Set-ItemProperty $pAdv -Name "ShowCopilotButton" -Type DWord -Value 0
                    Get-AppxPackage *Microsoft.Windows.Ai.Copilot.Provider* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Write-Host "`nПерезапуск Проводника для скрытия иконки Copilot..." -ForegroundColor Yellow
                    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                }
                Write-Host "`n[OK] Copilot полностью уничтожен!" -ForegroundColor Green; Start-Sleep 2
            }
            "3" {
                if ($null -ne $notepadUWP) {
                    Write-Host "`nУдаление нового Блокнота (Windows Notepad)..." -ForegroundColor Cyan
                    Get-AppxPackage *Microsoft.WindowsNotepad* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Write-Host "[OK] Успешно удалено!" -ForegroundColor Green; Start-Sleep 1
                }
            }
            "4" {
                if ($null -ne $calcUWP) {
                    Write-Host "`nУдаление нового Калькулятора (Windows Calculator)..." -ForegroundColor Cyan
                    Get-AppxPackage *Microsoft.WindowsCalculator* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Write-Host "[OK] Успешно удалено!" -ForegroundColor Green; Start-Sleep 1
                }
            }
            "5" {
                $p = "HKCR:\Applications\photoviewer.dll\shell\open"
                if (-not $photoReg) {
                    Write-Host "`nАктивация классического Просмотра Фото..." -ForegroundColor Cyan
                    New-Item -Path $p -Force | Out-Null
                    Set-ItemProperty $p -Name "MuiVerb" -Value "@photoviewer.dll,-3043"
                    New-Item -Path "$p\command" -Force | Out-Null
                    Set-ItemProperty "$p\command" -Name "(Default)" -Value "%SystemRoot%\System32\rundll32.exe \"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll\", ImageView_Fullscreen %1"
                    Write-Host "[OK] Успешно активировано!" -ForegroundColor Green; Start-Sleep 1
                }
            }
            "6" {
                if ($null -ne $wmpUWP) {
                    Write-Host "`nУдаление нового медиаплеера (ZuneVideo / ZuneMusic)..." -ForegroundColor Cyan
                    Get-AppxPackage *Microsoft.ZuneVideo* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Get-AppxPackage *Microsoft.ZuneMusic* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Write-Host "[OK] Успешно удалено!" -ForegroundColor Green; Start-Sleep 1
                }
            }

            "A" {
                $scriptPath = Join-Path $PSScriptRoot "scripts\Ultra-Tweaks.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    Write-Host "`n[OK] Ультра-твики применены!" -ForegroundColor Green
                } else {
                    Write-Host "`n[!] Файл Ultra-Tweaks.ps1 не найден!" -ForegroundColor Red
                }
                Start-Sleep 2
            }
        }
    }
}

function Menu-System {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [1] СИСТЕМНЫЕ ТВИКИ И ЯДРО (System & Kernel Tuning)                  " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. MaintenanceDisabled
        $maint = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -ErrorAction SilentlyContinue).MaintenanceDisabled
        $t1 = Tag ($maint -eq 1) "[ 1 (Отключено) ]" "[ Дефолт ]"

        # 2. MMCSS SystemResponsiveness (Оптимум: 10)
        $mmcss = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
        $t2 = Tag ($mmcss.SystemResponsiveness -eq 10) "[ 10 (Оптимум) ]" "[ $($mmcss.SystemResponsiveness) (Дефолт) ]"

        # 3. MMCSS NetworkThrottlingIndex
        $isThrottlingOff = ($mmcss.NetworkThrottlingIndex -eq -1 -or $mmcss.NetworkThrottlingIndex -eq 4294967295)
        $t3 = Tag $isThrottlingOff "[ Отключен ]" "[ $($mmcss.NetworkThrottlingIndex) (Дефолт) ]"

        # 4. MMCSS Games Task Priority
        $gTask = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -ErrorAction SilentlyContinue
        $t4 = Tag ($gTask."GPU Priority" -eq 8 -and $gTask.Priority -eq 6) "[ Высокий (8/6) ]" "[ Дефолт ]"

        # 5. MMCSS NoLazyMode
        $t5 = Tag ($mmcss.NoLazyMode -eq 1) "[ 1 (Без сна) ]" "[ Дефолт ]"

        # 6. Win32PrioritySeparation
        $prio = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
        $t6 = Tag ($prio -eq 38 -or $prio -eq 0x26) "[ 0x26 (38d) ]" "[ $prio (Дефолт) ]"

        # 7. SerializeTimerExpiration (Kernel Timer Table Per-Core)
        $kernel = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -ErrorAction SilentlyContinue
        $t7 = Tag ($kernel.SerializeTimerExpiration -eq 2) "[ 2 (На ядро) ]" "[ $($kernel.SerializeTimerExpiration) (Дефолт) ]"

        # 8. ThreadDpcEnable
        $t8 = Tag ($kernel.ThreadDpcEnable -eq 1) "[ 1 (Поточный) ]" "[ Дефолт ]"

        # 9. Game Mode & GameDVR
        $gb = Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -ErrorAction SilentlyContinue
        $gdvr = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -ErrorAction SilentlyContinue
        $t9 = Tag ($gb.AllowAutoGameMode -eq 1 -and $gdvr.AllowGameDVR -eq 0) "[ GameMode ВКЛ / DVR ВЫКЛ ]" "[ Дефолт ]"

        # 10. Memory Compression & Page Combining (64GB RAM)
        $mma = Get-MMAgent -ErrorAction SilentlyContinue
        $t10 = Tag (-not $mma.MemoryCompression -and -not $mma.PageCombining) "[ Отключено (Быстро) ]" "[ Дефолт ]"

        # 11. DisablePagingExecutive
        $mm = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -ErrorAction SilentlyContinue
        $t11 = Tag ($mm.DisablePagingExecutive -eq 1) "[ 1 (В ОЗУ) ]" "[ Дефолт ]"

        # 12. SleepStudyDisabled
        $pwrSm = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ErrorAction SilentlyContinue
        $t12 = Tag ($pwrSm.SleepStudyDisabled -eq 1) "[ Отключен ]" "[ Дефолт ]"

        # 13. DWM Fullscreen Optimizations & DirectFlip
        $dvr = Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue
        $t13 = Tag ($dvr.GameDVR_FSEBehaviorMode -eq 2) "[ FSO DirectFlip ]" "[ Дефолт ]"

        # 14. DWM Multi-Plane Overlay (MPO) & DirectFlip
        $gfx = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue
        $t14 = Tag ($gfx.DisableOverlays -eq 0 -and $gfx.ForceDirectFlip -eq 1) "[ MPO и DirectFlip ВКЛ ]" "[ Дефолт ]"

        # 15. HAGS & Foreground Priority Boost
        $gfxSched = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" -ErrorAction SilentlyContinue
        $t15 = Tag ($gfx.HwSchMode -eq 2 -and $gfxSched.ForegroundPriorityBoost -eq 1) "[ HAGS и GPU Boost ]" "[ Дефолт ]"

        # 16. NTFS Filesystem Tweaks (8dot3 name creation & last access update)
        $fs = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue
        $t16 = Tag ($fs.NtfsDisable8dot3NameCreation -eq 1 -and $fs.NtfsDisableLastAccessUpdate -eq 1) "[ Оптимизировано ]" "[ Дефолт ]"

        # 17. Hung Screen & App Timeouts
        $desk = Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue
        $t17 = Tag ($desk.HungAppTimeout -eq 1000 -and $desk.AutoEndTasks -eq "1") "[ 1 сек (Мгновенно) ]" "[ Дефолт ]"

        # 18. StickyKeys Popups & VerboseStatus
        $sk = (Get-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -ErrorAction SilentlyContinue).Flags
        $polSys = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
        $t18 = Tag ($sk -eq "506" -and $polSys.VerboseStatus -eq 1) "[ Оптимизировано ]" "[ Дефолт ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Автоматическое обслуживание Windows MaintenanceDisabled (Отключено)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t MMCSS SystemResponsiveness (10 = 90% мощности процессора игре)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t MMCSS NetworkThrottling (0xFFFFFFFF = отключение сетевого лимитера)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Планировщик MMCSS Games (GPU Priority 8 / Scheduling Category High)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t MMCSS NoLazyMode (1 = запрет перехода диспетчера в режим ожидания)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t Win32PrioritySeparation (0x26 = квантование 3:1 для Ryzen 9850X3D)"
        Write-Host " [7]  " -NoNewline; Write-Host $t7.Text -ForegroundColor $t7.Color -NoNewline; Write-Host "`t SerializeTimerExpiration (2 = таблицы таймеров на ядро, разгрузка CPU 0)"
        Write-Host " [8]  " -NoNewline; Write-Host $t8.Text -ForegroundColor $t8.Color -NoNewline; Write-Host "`t ThreadDpcEnable (1 = прерываемые поточные DPC без скачков задержки)"
        Write-Host " [9]  " -NoNewline; Write-Host $t9.Text -ForegroundColor $t9.Color -NoNewline; Write-Host "`t Game Mode и GameDVR (Игровой режим ВКЛ, фоновый рекордер ВЫКЛ)"
        Write-Host " [10] " -NoNewline; Write-Host $t10.Text -ForegroundColor $t10.Color -NoNewline; Write-Host "`t Сжатие памяти ОЗУ (Отключено = экономия циклов CPU на 64 ГБ RAM)"
        Write-Host " [11] " -NoNewline; Write-Host $t11.Text -ForegroundColor $t11.Color -NoNewline; Write-Host "`t DisablePagingExecutive (1 = блокировка ядра и драйверов в физической ОЗУ)"
        Write-Host " [12] " -NoNewline; Write-Host $t12.Text -ForegroundColor $t12.Color -NoNewline; Write-Host "`t Kernel SleepStudy Tracing (Отключено = ликвидация аудита энергосбережения)"
        Write-Host " [13] " -NoNewline; Write-Host $t13.Text -ForegroundColor $t13.Color -NoNewline; Write-Host "`t DWM FSO и DirectFlip (Аппаратный независимый режим без задержки DWM)"
        Write-Host " [14] " -NoNewline; Write-Host $t14.Text -ForegroundColor $t14.Color -NoNewline; Write-Host "`t DWM MPO Overlays и ForceDirectFlip (Прямой вывод кадров видеокартой)"
        Write-Host " [15] " -NoNewline; Write-Host $t15.Text -ForegroundColor $t15.Color -NoNewline; Write-Host "`t HAGS и GPU Boost (Аппаратное планирование GPU и приоритет рендеринга)"
        Write-Host " [16] " -NoNewline; Write-Host $t16.Text -ForegroundColor $t16.Color -NoNewline; Write-Host "`t Оптимизация NTFS (Отключение коротких имен 8.3 и даты последнего доступа)"
        Write-Host " [17] " -NoNewline; Write-Host $t17.Text -ForegroundColor $t17.Color -NoNewline; Write-Host "`t Таймауты зависших задач (Мгновенное завершение зависших окон за 1 сек)"
        Write-Host " [18] " -NoNewline; Write-Host $t18.Text -ForegroundColor $t18.Color -NoNewline; Write-Host "`t Залипание клавиш и VerboseStatus (Блокировка всплывающих окон Shift)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики ядра | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $kPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        $gPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

        switch ($c.ToUpper()) {
            "1" {
                $pMaint = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
                if (-not (Test-Path $pMaint)) { New-Item -Path $pMaint -Force | Out-Null }
                $v = if ($maint -eq 1) { 0 } else { 1 }
                Set-ItemProperty $pMaint -Name "MaintenanceDisabled" -Type DWord -Value $v
            }
            "2" {
                $v = if ($mmcss.SystemResponsiveness -eq 10) { 20 } else { 10 }
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
                if ($desk.HungAppTimeout -eq "1000" -and $desk.AutoEndTasks -eq "1") {
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
                Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -ErrorAction SilentlyContinue
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
                Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "WaitToKillTimeout" -Type String -Value "5000"
                Remove-ItemProperty "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Type String -Value "0"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "126"
                Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Type String -Value "62"
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 0
                Write-Host "`n[OK] Все твики ядра сброшены к стандартным значениям Windows." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 2: СЕТЕВОЙ СТЕК И TCP/IP
# ==============================================================================
function Menu-Network {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "        [2] СЕТЕВЫЕ ТВИКИ И TCP/IP (Network & TCP/IP Tuning)                  " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Interrupt Moderation
        $nic = Get-NetAdapterAdvancedProperty -DisplayName "Interrupt Moderation" -ErrorAction SilentlyContinue
        $t1 = Tag ($nic.DisplayValue -eq "Disabled") "[ Отключено (Мгновенно) ]" "[ Включено (Дефолт) ]"

        # 2. Buffers
        $rx = (Get-NetAdapterAdvancedProperty -DisplayName "Receive Buffers" -ErrorAction SilentlyContinue).DisplayValue
        $t2 = Tag ($rx -ge 512) "[ 512/128 (Максимум Realtek) ]" "[ Дефолт ]"

        # 3. Nagle (TcpAckFrequency / TCPNoDelay)
        $interfaces = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $hasNagle = $false
        if (Test-Path $interfaces) {
            foreach ($k in (Get-ChildItem $interfaces)) {
                $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
                if ($p.TcpAckFrequency -eq 1 -and $p.TCPNoDelay -eq 1) { $hasNagle = $true; break }
            }
        }
        $t3 = Tag $hasNagle "[ Отключен (Мин. пинг) ]" "[ Дефолт ]"

        # 4. TCP Congestion Provider
        $tcpSetting = (Get-NetTCPSetting -SettingName "Internet" -ErrorAction SilentlyContinue).CongestionProvider
        $t4 = Tag ($tcpSetting -eq "CTCP" -or $tcpSetting -eq "CUBIC") "[ $tcpSetting ]" "[ Дефолт ]"

        # 5. TCP Auto-Tuning Heuristics
        $t5 = Tag $true "[ Normal / Без эвристик ]" "[ Дефолт ]"

        # 6. NetBIOS over TCP/IP
        $nb = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | Select-Object -First 1).TcpipNetbiosOptions
        $t6 = Tag ($nb -eq 2) "[ Отключен (Без шума) ]" "[ Дефолт ]"

        # 7. NIC Power Savings
        $pwr = Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Select-Object -First 1
        $t7 = Tag ($pwr.AllowComputerToTurnOffDevice -eq "Disabled") "[ Отключено (Макс. мощность) ]" "[ Дефолт ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Модерация прерываний Realtek (Отключено = доставка пакетов без задержки)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Кольцевые буферы сетевой карты (512 Receive / 128 Transmit буферов)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Алгоритм Нагла (TcpAckFrequency=1 & TCPNoDelay=1 - устранение джиттера пинга)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Провайдер перегрузки TCP (CTCP с контролем задержки vs CUBIC)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t Глобальные параметры TCP (AutoTuning=Normal, Heuristics=Off, Timestamps=Off)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t NetBIOS over TCP/IP (Отключен = блокировка широковещательного сетевого шума)"
        Write-Host " [7]  " -NoNewline; Write-Host $t7.Text -ForegroundColor $t7.Color -NoNewline; Write-Host "`t Энергосбережение сетевой карты (Отключено = запрет засыпания PHY чипа)"
        Write-Host " [8]  🎮  Политика качества обслуживания (QoS / DSCP 46 Expedited Forwarding) (QoS-Policy.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все сетевые твики | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        switch ($c.ToUpper()) {
            "1" {
                if ($adapter) {
                    $v = if ($nic.DisplayValue -eq "Disabled") { "Enabled" } else { "Disabled" }
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue $v -ErrorAction SilentlyContinue | Out-Null
                }
            }
            "2" {
                if ($adapter) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" -ErrorAction SilentlyContinue | Out-Null
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
                Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
                    $null = Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$target } -ErrorAction SilentlyContinue
                }
            }
            "7" {
                Get-NetAdapterPowerManagement | ForEach-Object {
                    $_.AllowComputerToTurnOffDevice = if ($pwr.AllowComputerToTurnOffDevice -eq 'Disabled') { 'Enabled' } else { 'Disabled' }
                    $_ | Set-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Out-Null
                }
            }
            "8" {
                & (Join-Path $scriptsDir "QoS-Policy.ps1")
            }
            "A" {
                & (Join-Path $scriptsDir "Network-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                if ($adapter) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" -ErrorAction SilentlyContinue | Out-Null
                }
                foreach ($k in (Get-ChildItem $interfaces)) {
                    Remove-ItemProperty $k.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $k.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $k.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                }
                Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -ErrorAction SilentlyContinue | Out-Null
                Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
                    $null = Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]0 } -ErrorAction SilentlyContinue
                }
                Get-NetAdapterPowerManagement | ForEach-Object { $_.AllowComputerToTurnOffDevice = 'Enabled'; $_ | Set-NetAdapterPowerManagement | Out-Null }
                Write-Host "`n[OK] Все сетевые настройки сброшены к стандартным значениям Windows." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 3: ЭЛЕКТРОПИТАНИЕ И ТАЙМЕРЫ
# ==============================================================================
function Menu-Power {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [3] ЭЛЕКТРОПИТАНИЕ И ТАЙМЕРЫ (Power & Timers Tuning)                 " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Timer Coalescing
        $pwr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ErrorAction SilentlyContinue
        $t1 = Tag ($pwr.CoalescingTimerInterval -eq 0) "[ 0 (Строгий тайминг) ]" "[ Дефолт ]"

        # 2. Energy Estimation
        $t2 = Tag ($pwr.EnergyEstimationDisabled -eq 1) "[ Отключено (Без оверхеда) ]" "[ Дефолт ]"

        # 3. Audio Endpoint Idle Sleep (24H2 compatible)
        $audioPower = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}\0000\PowerSettings" -ErrorAction SilentlyContinue
        $t3 = Tag ($audioPower.ConservationIdleTime -eq 0 -and $audioPower.CSConservationIdleTime -eq 0) "[ Отключено (Без щелчков) ]" "[ Дефолт ]"

        # 4. Hibernation (powercfg -h)
        $hiberFile = Test-Path "C:\hiberfil.sys"
        $t4 = Tag (-not $hiberFile) "[ Выключена (Освобождено 64 ГБ) ]" "[ Включена ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Коалесценция таймеров (0 = запрет группировки прерываний для точности кадров)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Energy Estimation (Отключено = ликвидация аудита энергопотребления датчиков)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Засыпание USB-аудио (Отключено = устранение щелчков и задержки старта ЦАП)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Гибернация системы (Выключена = удаление 64 ГБ hiberfil.sys с NVMe SSD)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики питания | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
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
                        Remove-ItemProperty $_.PSPath -Name "CSConservationIdleTime" -ErrorAction SilentlyContinue
                        Remove-ItemProperty $_.PSPath -Name "CSPerformanceIdleTime" -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty $_.PSPath -Name "ConservationIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                        Set-ItemProperty $_.PSPath -Name "PerformanceIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                        Set-ItemProperty $_.PSPath -Name "CSConservationIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                        Set-ItemProperty $_.PSPath -Name "CSPerformanceIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
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
                    Set-ItemProperty $_.PSPath -Name "CSConservationIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                    Set-ItemProperty $_.PSPath -Name "CSPerformanceIdleTime" -Type Binary -Value ([byte[]](0,0,0,0))
                }
                powercfg -h off
            }
            "D" {
                Remove-ItemProperty $pwrPath -Name "CoalescingTimerInterval" -ErrorAction SilentlyContinue
                Remove-ItemProperty $pwrPath -Name "EnergyEstimationDisabled" -ErrorAction SilentlyContinue
                powercfg -h on
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 4: ПЕРИФЕРИЯ, МЫШЬ И ВВОД
# ==============================================================================
function Menu-Peripheral {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "     [4] ПЕРИФЕРИЯ, МЫШЬ И ВВОД (Peripherals & Input Latency)                 " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. RawMouseThrottle
        $mou = Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue
        $t1 = Tag ($mou.RawMouseThrottleEnabled -eq 0) "[ Отключено (Без лимита 125 Гц) ]" "[ Дефолт ]"

        # 2. Mouse Acceleration Disabled (MouseSpeed = 0)
        $t2 = Tag ($mou.MouseSpeed -eq "0" -and $mou.MouseThreshold1 -eq "0") "[ 0 (Акселерация ВЫКЛ) ]" "[ Акселерация ВКЛ ]"

        # 3. Audio Ducking
        $audioDuck = (Get-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -ErrorAction SilentlyContinue).UserDuckingPreference
        $t3 = Tag ($audioDuck -eq 3) "[ Отключено (0 dB) ]" "[ $($audioDuck) (Стандарт) ]"

        # 4. Windows Dynamic Lighting (Background RGB thread)
        $dynLight = (Get-ItemProperty "HKCU:\Software\Microsoft\Lighting" -ErrorAction SilentlyContinue).AmbientLightingEnabled
        $t4 = Tag ($dynLight -eq 0) "[ Отключено (Экономия CPU) ]" "[ Дефолт ]"

        # 5. Mouse & Keyboard DataQueueSize (Custom queue size)
        $mouClass = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -ErrorAction SilentlyContinue
        $t5 = Tag ($mouClass.MouseDataQueueSize -eq 50) "[ 50 (Быстрый сброс) ]" "[ $($mouClass.MouseDataQueueSize) (Дефолт 100) ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t RawMouseThrottle (Отключено = ликвидация фонового троттлинга частоты опроса)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Отключение акселерации мыши (MouseSpeed=0, Threshold1=0, Threshold2=0)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Audio Ducking (Отключено = Discord не будет приглушать громкость игры)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Dynamic Lighting (Отключено = остановка системной службы RGB-подсветки)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t Буфер очереди ввода DataQueueSize (50 = сокращенный размер буфера драйвера)"
        Write-Host " [6]   👉    [ УСТАНОВИТЬ ]   Установить курсоры Modern Fluent (Cursor-Tweaks)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики периферии | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        $pMou = "HKCU:\Control Panel\Mouse"
        switch ($c.ToUpper()) {
            "1" {
                if ($mou.RawMouseThrottleEnabled -eq 0) {
                    Remove-ItemProperty $pMou -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue
                    Remove-ItemProperty $pMou -Name "RawMouseThrottleForced" -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty $pMou -Name "RawMouseThrottleEnabled" -Type DWord -Value 0
                    Set-ItemProperty $pMou -Name "RawMouseThrottleForced" -Type DWord -Value 0
                }
            }
            "2" {
                if ($mou.MouseSpeed -eq "0") {
                    Set-ItemProperty $pMou -Name "MouseSpeed" -Type String -Value "1"
                    Set-ItemProperty $pMou -Name "MouseThreshold1" -Type String -Value "6"
                    Set-ItemProperty $pMou -Name "MouseThreshold2" -Type String -Value "10"
                } else {
                    Set-ItemProperty $pMou -Name "MouseSpeed" -Type String -Value "0"
                    Set-ItemProperty $pMou -Name "MouseThreshold1" -Type String -Value "0"
                    Set-ItemProperty $pMou -Name "MouseThreshold2" -Type String -Value "0"
                }
            }
            "3" {
                $p = "HKCU:\Software\Microsoft\Multimedia\Audio"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                # 3 = Do nothing (0 dB), 1 = Reduce by 80% (Windows default)
                if ($audioDuck -eq 3) { Set-ItemProperty $p -Name "UserDuckingPreference" -Type DWord -Value 1 }
                else { Set-ItemProperty $p -Name "UserDuckingPreference" -Type DWord -Value 3 }
            }
            "4" {
                $p = "HKCU:\Software\Microsoft\Lighting"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                if ($dynLight -eq 0) { Set-ItemProperty $p -Name "AmbientLightingEnabled" -Type DWord -Value 1 }
                else { Set-ItemProperty $p -Name "AmbientLightingEnabled" -Type DWord -Value 0 }
            }
            "6" {
                $scriptPath = Join-Path $PSScriptRoot "scripts\Cursor-Tweaks.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                }
                Start-Sleep 2
            }
            "5" {
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
            "A" {
                Set-ItemProperty $pMou -Name "RawMouseThrottleEnabled" -Type DWord -Value 0
                Set-ItemProperty $pMou -Name "RawMouseThrottleForced" -Type DWord -Value 0
                Set-ItemProperty $pMou -Name "MouseSpeed" -Type String -Value "0"
                Set-ItemProperty $pMou -Name "MouseThreshold1" -Type String -Value "0"
                Set-ItemProperty $pMou -Name "MouseThreshold2" -Type String -Value "0"
                Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 3
                Set-ItemProperty "HKCU:\Software\Microsoft\Lighting" -Name "AmbientLightingEnabled" -Type DWord -Value 0
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 50
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 50
            }
            "D" {
                Remove-ItemProperty $pMou -Name "RawMouseThrottleEnabled" -ErrorAction SilentlyContinue
                Remove-ItemProperty $pMou -Name "RawMouseThrottleForced" -ErrorAction SilentlyContinue
                Set-ItemProperty $pMou -Name "MouseSpeed" -Type String -Value "1"
                Set-ItemProperty $pMou -Name "MouseThreshold1" -Type String -Value "6"
                Set-ItemProperty $pMou -Name "MouseThreshold2" -Type String -Value "10"
                Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 1
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 5: NVIDIA И ВИДЕОКАРТА
# ==============================================================================
function Menu-Nvidia {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "         [5] NVIDIA И ГРАФИЧЕСКИЙ ДРАЙВЕР (GPU & Driver Tuning)               " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. MSI Mode on GPU
        $activeGpu = Get-PnpDevice -Class Display -PresentOnly | Where-Object { $_.InstanceId -like "PCI\VEN_10DE*" } | Select-Object -First 1
        if (-not $activeGpu) {
            $activeGpu = Get-PnpDevice -Class Display -PresentOnly | Where-Object { $_.InstanceId -like "PCI\*" } | Select-Object -First 1
        }
        $gpuName = if ($activeGpu) { $activeGpu.FriendlyName } else { "Видеокарта" }
        $gpuInst = if ($activeGpu) { $activeGpu.InstanceId } else { "" }
        $msiKey = if ($gpuInst) { "HKLM:\SYSTEM\CurrentControlSet\Enum\$gpuInst\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" } else { "" }
        $affKey = if ($gpuInst) { "HKLM:\SYSTEM\CurrentControlSet\Enum\$gpuInst\Device Parameters\Interrupt Management\Affinity Policy" } else { "" }
        $msi = if ($msiKey) { (Get-ItemProperty $msiKey -ErrorAction SilentlyContinue).MSISupported } else { $null }
        $t1 = Tag ($msi -eq 1) "[ MSI Активен (Без конфликтов IRQ) ]" "[ Устаревший Line IRQ ]"

        # 2. High Priority Affinity Policy
        $aff = if ($affKey) { (Get-ItemProperty $affKey -ErrorAction SilentlyContinue).DevicePriority } else { $null }
        $t2 = Tag ($aff -eq 3) "[ Высокий приоритет ]" "[ Обычный ]"

        # 3. Telemetry Service
        $telemetry = Get-Service "NvTelemetryContainer" -ErrorAction SilentlyContinue
        $t3 = Tag ($telemetry.StartType -eq "Disabled") "[ Отключено ]" "[ Включено (Дефолт) ]"

        # 4. TDR Delay
        $tdr = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).TdrDelay
        $t4 = Tag ($tdr -ge 8) "[ 8 сек (Стабильно) ]" "[ $($tdr) сек (Дефолт 2 сек) ]"

        # 5. MSI Afterburner Scheduled Task (Cooling & OC/UV, No RTSS)
        $stdAb = Get-ScheduledTask -TaskName "MSIAfterburner" -ErrorAction SilentlyContinue
        if (Get-ScheduledTask -TaskName "MSIAfterburnerProfile" -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName "MSIAfterburnerProfile" -Confirm:$false -ErrorAction SilentlyContinue
        }
        $t5 = Tag ($stdAb -and $stdAb.State -ne "Disabled") "[ ВКЛ (Кулеры + OC, без RTSS) ]" "[ ВЫКЛ ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Режим прерываний MSI Mode для видеокарты ($gpuName)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Аппаратный приоритет прерываний GPU (DevicePriority = 3 / High)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Фоновая служба телеметрии NvTelemetryContainer (Отключена)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Таймаут GPU TDR Delay (8 сек = защита от крашей шейдеров)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t Автозагрузка Afterburner (Трей: кулеры + OC/UV без RTSS)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [6]  Запустить официальную утилиту облегчения драйвера (NVIDIA-Tool.ps1)" -ForegroundColor White
        Write-Host " [7]  Создать ярлык запуска панели управления NVCPL по требованию (nvcpl.ps1)" -ForegroundColor White
        Write-Host " [8]  Управление Afterburner и кулерами (MSI-Afterburner-Profile.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить твики GPU | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" {
                if ($msiKey) {
                    if (-not (Test-Path $msiKey)) { New-Item $msiKey -Force | Out-Null }
                    $v = if ($msi -eq 1) { 0 } else { 1 }
                    Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value $v
                }
            }
            "2" {
                if ($affKey) {
                    if (-not (Test-Path $affKey)) { New-Item $affKey -Force | Out-Null }
                    $v = if ($aff -eq 3) { 0 } else { 3 }
                    Set-ItemProperty $affKey -Name "DevicePriority" -Type DWord -Value $v
                }
            }
            "3" {
                if ($telemetry.StartType -eq "Disabled") {
                    Set-Service "NvTelemetryContainer" -StartupType Manual -ErrorAction SilentlyContinue
                } else {
                    Stop-Service "NvTelemetryContainer" -Force -ErrorAction SilentlyContinue
                    Set-Service "NvTelemetryContainer" -StartupType Disabled -ErrorAction SilentlyContinue
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
            "5" {
                if ($stdAb -and $stdAb.State -ne "Disabled") {
                    & (Join-Path $scriptsDir "MSI-Afterburner-Profile.ps1") -Action Disable
                } else {
                    & (Join-Path $scriptsDir "MSI-Afterburner-Profile.ps1") -Action Enable
                }
                Start-Sleep -Seconds 1
            }
            "6" { & (Join-Path $scriptsDir "NVIDIA-Tool.ps1"); pause }
            "7" { & (Join-Path $scriptsDir "nvcpl.ps1"); Write-Host "[OK] Ярлык NVCPL создан на Рабочем столе!"; pause }
            "8" { & (Join-Path $scriptsDir "MSI-Afterburner-Profile.ps1"); pause }
            "A" {
                if ($msiKey) {
                    if (-not (Test-Path $msiKey)) { New-Item $msiKey -Force | Out-Null }
                    Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value 1
                }
                if ($affKey) {
                    if (-not (Test-Path $affKey)) { New-Item $affKey -Force | Out-Null }
                    Set-ItemProperty $affKey -Name "DevicePriority" -Type DWord -Value 3
                }
                Stop-Service "NvTelemetryContainer" -Force -ErrorAction SilentlyContinue
                Set-Service "NvTelemetryContainer" -StartupType Disabled -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Type DWord -Value 8
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Type DWord -Value 8
            }
            "D" {
                if ($msiKey) {
                    Set-ItemProperty $msiKey -Name "MSISupported" -Type DWord -Value 1
                }
                if ($affKey) {
                    Remove-ItemProperty $affKey -Name "DevicePriority" -ErrorAction SilentlyContinue
                }
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Type DWord -Value 2
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Type DWord -Value 2
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 6: КЛИЕНТЫ, ЛАУНЧЕРЫ И ПРИЛОЖЕНИЯ
# ==============================================================================
function Menu-Steam {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "     [6] КЛИЕНТЫ, ЛАУНЧЕРЫ И ПРИКЛАДНЫЕ ПРОГРАММЫ (Apps & Launchers)          " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
        if (-not $steam) { $steam = "C:\Program Files (x86)\Steam" }
        $umpdcInstalled = Test-Path (Join-Path $steam "umpdc.dll")
        $t1 = Tag $umpdcInstalled "[ Установлен (Авто-выгрузка 7 процессов CEF) ]" "[ Не установлен ]"

        Write-Host " [1]  Steam: Твики клиента, реестра и кэша (Steam-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [2]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t NoSteamWebHelper (umpdc.dll - освобождает до 1 ГБ ОЗУ в игре)"
        Write-Host " [3]  Epic Games Launcher: Службы, автозапуск и кэш (EpicGames-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [4]  Discord: Аппаратное ускорение и логирование (Discord-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [5]  Spotify: Аппаратное ускорение и оверлей SMTC (Spotify-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [6]  Logitech G HUB: Службы и автозапуск (LGHUB-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [7]  SteelSeries GG: Отключение аудиодрайвера Sonar VAD (SteelSeries-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [8]  Браузеры Chromium: Политики Chrome, Edge, Brave, Yandex (Browsers-Tweaks.ps1)" -ForegroundColor White
        Write-Host " [9]  VS Code / VSCodium: Телеметрия и обновления (VSCode-Tweaks.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [10] CS2: Конфигурация и запуск (NV-CS2-Tool.ps1)" -ForegroundColor DarkGray
        Write-Host " [11] Valorant: Оптимизация таймеров и приоритета (NV-VALORANT-Tool.ps1)" -ForegroundColor DarkGray
        Write-Host " [12] Fortnite: Конфигурация движка UE (NV-Fortnite-Tool.ps1)" -ForegroundColor DarkGray
        Write-Host " [13] Marvel Rivals: Оптимизация настроек (NV-Marvel-Tool.ps1)" -ForegroundColor DarkGray
        Write-Host " [14] Overwatch: Оптимизация клиента (NV-OW-Tool.ps1)" -ForegroundColor DarkGray
        Write-Host " [15] Системная информация о комплектующих (NVFetch.ps1)" -ForegroundColor DarkGray
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Пакетная оптимизация всех приложений (App-Tweaks.ps1)" -ForegroundColor Green
        Write-Host " [Q]  Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" { & (Join-Path $scriptsDir "Steam-Tweaks.ps1"); pause }
            "2" {
                $umpdcPath = Join-Path $steam "umpdc.dll"
                if (Test-Path $umpdcPath) {
                    Get-Process steam* -ErrorAction SilentlyContinue | Stop-Process -Force
                    Remove-Item $umpdcPath -Force
                    Write-Host "`n[-] Модуль umpdc.dll успешно удален." -ForegroundColor Yellow
                } else {
                    Get-Process steam* -ErrorAction SilentlyContinue | Stop-Process -Force
                    $url = "https://github.com/Aetopia/NoSteamWebHelper/releases/download/v5.0.2/umpdc.dll"
                    Invoke-WebRequest -Uri $url -OutFile $umpdcPath -Headers @{"User-Agent"="PowerShell"}
                    Write-Host "`n[+] Модуль umpdc.dll успешно установлен в Steam!" -ForegroundColor Green
                }
                Start-Sleep -Milliseconds 1200
            }
            "3" { & (Join-Path $scriptsDir "EpicGames-Tweaks.ps1"); pause }
            "4" { & (Join-Path $scriptsDir "Discord-Tweaks.ps1"); pause }
            "5" { & (Join-Path $scriptsDir "Spotify-Tweaks.ps1"); pause }
            "6" { & (Join-Path $scriptsDir "LGHUB-Tweaks.ps1"); pause }
            "7" { & (Join-Path $scriptsDir "SteelSeries-Tweaks.ps1"); pause }
            "8" { & (Join-Path $scriptsDir "Browsers-Tweaks.ps1"); pause }
            "9" { & (Join-Path $scriptsDir "VSCode-Tweaks.ps1"); pause }
            "10" { & (Join-Path $scriptsDir "NV-CS2-Tool.ps1"); pause }
            "11" { & (Join-Path $scriptsDir "NV-VALORANT-Tool.ps1"); pause }
            "12" { & (Join-Path $scriptsDir "NV-Fortnite-Tool.ps1"); pause }
            "13" { & (Join-Path $scriptsDir "NV-Marvel-Tool.ps1"); pause }
            "14" { & (Join-Path $scriptsDir "NV-OW-Tool.ps1"); pause }
            "15" { & (Join-Path $scriptsDir "NVFetch.ps1"); pause }
            "A" { & (Join-Path $scriptsDir "App-Tweaks.ps1"); pause }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 7: ПРИВАТНОСТЬ, ТЕЛЕМЕТРИЯ И СЛУЖБЫ
# ==============================================================================
function Menu-Privacy {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "     [7] ПРИВАТНОСТЬ, ТЕЛЕМЕТРИЯ И СЛУЖБЫ (Privacy & Services)                " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Telemetry
        $dc = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry
        $t1 = Tag ($dc -eq 0) "[ Отключено (0) ]" "[ Дефолт ]"

        # 2. WER
        $wer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -ErrorAction SilentlyContinue).Disabled
        if ($null -eq $wer) {
            $wer = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -ErrorAction SilentlyContinue).Disabled
        }
        $t2 = Tag ($wer -eq 1) "[ Отключено (Без дампов) ]" "[ Дефолт ]"

        # 3. DiagTrack
        $dt = (Get-Service "DiagTrack" -ErrorAction SilentlyContinue).StartType
        $t3 = Tag ($dt -eq "Disabled") "[ Отключено ]" "[ Работает ]"

        # 4. SysMain (SuperFetch)
        $sm = (Get-Service "SysMain" -ErrorAction SilentlyContinue).StartType
        $t4 = Tag ($sm -eq "Disabled") "[ Отключено (Быстрый NVMe) ]" "[ Работает ]"

        # 5. Windows Search (WSearch)
        $ws = (Get-Service "WSearch" -ErrorAction SilentlyContinue).StartType
        $t5 = Tag ($ws -eq "Disabled") "[ Отключено (Нулевой I/O) ]" "[ Работает ]"

        # 6. Copilot & Recall AI
        $cp = (Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
        $t6 = Tag ($cp -eq 1) "[ Заблокировано ]" "[ Дефолт ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Телеметрия Windows (AllowTelemetry = 0)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Отчеты об ошибках WER (Disabled = устранение задержек при сбоях программ)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Служба сбора телеметрии DiagTrack (Отключена = нулевая нагрузка на процессор)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Служба SysMain / SuperFetch (Отключена = исключение фонового чтения SSD)"
        Write-Host " [5]  " -NoNewline; Write-Host $t5.Text -ForegroundColor $t5.Color -NoNewline; Write-Host "`t Индексация Windows Search (Отключена = нулевая очередь дискового ввода-вывода)"
        Write-Host " [6]  " -NoNewline; Write-Host $t6.Text -ForegroundColor $t6.Color -NoNewline; Write-Host "`t ИИ-помощник Copilot и снимки Recall (Заблокированы на уровне политик)"
        Write-Host " [7]  🛡️   Менеджер фильтрации DNS/Hosts (HaGeZi, StevenBlack, OISD) (Blocklist-Manger.ps1)" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики приватности | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
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
                $pPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
                $pMach = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
                if (-not (Test-Path $pPolicy)) { New-Item $pPolicy -Force | Out-Null }
                if (-not (Test-Path $pMach)) { New-Item $pMach -Force | Out-Null }
                if ($wer -eq 1) {
                    Set-ItemProperty $pPolicy -Name "Disabled" -Type DWord -Value 0
                    Set-ItemProperty $pMach -Name "Disabled" -Type DWord -Value 0
                    Set-Service "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty $pPolicy -Name "Disabled" -Type DWord -Value 1
                    Set-ItemProperty $pMach -Name "Disabled" -Type DWord -Value 1
                    Stop-Service "WerSvc" -Force -ErrorAction SilentlyContinue
                    Set-Service "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            "3" {
                if ($dt -eq "Disabled") {
                    Set-Service "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
                    Start-Service "DiagTrack" -ErrorAction SilentlyContinue
                } else {
                    Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
                    Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            "4" {
                if ($sm -eq "Disabled") {
                    Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
                    Start-Service "SysMain" -ErrorAction SilentlyContinue
                } else {
                    Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
                    Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            "5" {
                if ($ws -eq "Disabled") {
                    Set-Service "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
                    Start-Service "WSearch" -ErrorAction SilentlyContinue
                } else {
                    Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
                    Set-Service "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
            "6" {
                $p = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                $v = if ($cp -eq 1) { 0 } else { 1 }
                Set-ItemProperty $p -Name "TurnOffWindowsCopilot" -Type DWord -Value $v
            }
            "7" {
                & (Join-Path $scriptsDir "Blocklist-Manger.ps1") -ShowGUI
            }
            "A" {
                & (Join-Path $scriptsDir "Privacy-Tweaks.ps1")
                Start-Sleep -Seconds 1
            }
            "D" {
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 0
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 0
                Set-Service "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue
                Set-Service "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
                Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
                Set-Service "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
                Remove-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Настройки приватности сброшены к стандартным значениям Windows." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 8: БЕЗОПАСНОСТЬ, VBS И ЦЕЛОСТНОСТЬ
# ==============================================================================
function Menu-Security {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "   [8] БЕЗОПАСНОСТЬ, VBS И ЦЕЛОСТНОСТЬ (Security & Virtualization)       " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. VBS
        $vbs = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        $t1 = Tag ($vbs -eq 0) "[ Отключено (+3-8% FPS) ]" "[ Включено (Hyper-V) ]"

        # 2. WPBT (DisableWpbtExecution)
        $wpbt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).DisableWpbtExecution
        $t2 = Tag ($wpbt -eq 1) "[ Заблокировано (Без OEM-инжекций) ]" "[ Разрешено ]"

        # 3. Delivery Optimization P2P
        $do = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -ErrorAction SilentlyContinue).DODownloadMode
        $t3 = Tag ($do -eq 0) "[ Отключено (Без отдачи) ]" "[ Дефолт ]"

        # 4. PromptOnSecureDesktop
        $uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue).PromptOnSecureDesktop
        $t4 = Tag ($uac -eq 0) "[ Отключено (0 мс UAC) ]" "[ Дефолт ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t VBS / Core Isolation (Отключено = +3-8% FPS, ликвидация оверхеда Hyper-V)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Блокировка WPBT (Заблокировано = запрет инжекции OEM-мусора из BIOS)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t P2P Delivery Optimization (Отключено = запрет раздачи трафика обновлений)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Затемнение экрана UAC PromptOnSecureDesktop (Отключено = мгновенный UAC)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики безопасности | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
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
                Set-ItemProperty $p -Name "DisableWpbtExecution" -Type DWord -Value $v
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
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Type DWord -Value 3
                Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 1
                Write-Host "`n[OK] Настройки безопасности сброшены к стандартным значениям Windows." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 9: ВИДИМОСТЬ И ИНТЕРФЕЙС ПРОВОДНИКА
# ==============================================================================
function Menu-Visibility {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "    [9] ИНТЕРФЕЙС И ПРОВОДНИК EXPLORER (UI & Windows Explorer)           " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan

        # 1. Classic Context Menu
        $isClassic = Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        $t1 = Tag $isClassic "[ Классическое Win10 (0 мс) ]" "[ Меню Win 11 (XAML лаг) ]"

        # 2. Window Animations
        $anim = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue).DisallowAnimations
        if ($null -eq $anim) {
            $anim = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue).DisallowAnimations
        }
        $t2 = Tag ($anim -eq 1) "[ Отключены (Мгновенно) ]" "[ Включены (Дефолт) ]"

        # 3. File Extensions & Hidden
        $adv = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue
        $t3 = Tag ($adv.HideFileExt -eq 0 -and $adv.Hidden -eq 1) "[ Отображаются ]" "[ Скрыты (Дефолт) ]"

        # 4. Detailed File Transfer
        $ops = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -ErrorAction SilentlyContinue).EnthusiastMode
        $t4 = Tag ($ops -eq 1) "[ EnthusiastMode ]" "[ Дефолт ]"

        Write-Host " [1]  " -NoNewline; Write-Host $t1.Text -ForegroundColor $t1.Color -NoNewline; Write-Host "`t Классическое меню ПКМ (Мгновенное открытие без задержки XAML)"
        Write-Host " [2]  " -NoNewline; Write-Host $t2.Text -ForegroundColor $t2.Color -NoNewline; Write-Host "`t Анимации сворачивания окон (Отключены = мгновенный отклик интерфейса)"
        Write-Host " [3]  " -NoNewline; Write-Host $t3.Text -ForegroundColor $t3.Color -NoNewline; Write-Host "`t Расширения файлов и скрытые папки (Всегда отображаются в Проводнике)"
        Write-Host " [4]  " -NoNewline; Write-Host $t4.Text -ForegroundColor $t4.Color -NoNewline; Write-Host "`t Подробный график копирования файлов (EnthusiastMode = сразу развернутый вид)"
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Применить все твики интерфейса | [D] Сбросить в дефолт | [Q] Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню для переключения: " -NoNewline -ForegroundColor Yellow
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
                $pCu = "HKCU:\Software\Microsoft\Windows\DWM"
                $pLm = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM"
                if (-not (Test-Path $pCu)) { New-Item -Path $pCu -Force | Out-Null }
                if (-not (Test-Path $pLm)) { New-Item -Path $pLm -Force | Out-Null }
                $v = if ($anim -eq 1) { 0 } else { 1 }
                Set-ItemProperty $pCu -Name "DisallowAnimations" -Type DWord -Value $v
                Set-ItemProperty $pLm -Name "DisallowAnimations" -Type DWord -Value $v
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
            & (Join-Path $scriptsDir "Services-Tweaks.ps1")
            & (Join-Path $scriptsDir "Debloat-UWP.ps1")
            & (Join-Path $scriptsDir "Mouse-Tweaks.ps1")
            & (Join-Path $scriptsDir "Cursor-Tweaks.ps1") -Quiet
                Start-Sleep -Seconds 1
            }
            "D" {
                Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 1
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 2
                Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name "EnthusiastMode" -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Настройки интерфейса сброшены к стандартным значениям Windows." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  РАЗДЕЛ 10: ОБСЛУЖИВАНИЕ И ОЧИСТКА КЭШЕЙ
# ==============================================================================
function Menu-Cleaner {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "   [10] ОБСЛУЖИВАНИЕ И ОЧИСТКА КЭШЕЙ (Maintenance & Cleaning)          " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host " [1]  Сброс локального кэша DNS-клиента (Clear-DnsClientCache)" -ForegroundColor White
        Write-Host " [2]  Очистить кэши шейдеров DirectX и NVIDIA (Принудительная чистая компиляция)" -ForegroundColor White
        Write-Host " [3]  Очистить временные файлы Temp и кэш Delivery Optimization (Освобождение SSD)" -ForegroundColor White
        Write-Host " [4]  Очистить системные журналы событий Windows Event Logs" -ForegroundColor White
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host " [A]  Запустить полную очистку системы (scripts/Cleaner-Tweaks.ps1)" -ForegroundColor Green
        Write-Host " [Q]  Назад" -ForegroundColor Yellow
        Write-Host "`nВыберите пункт меню: " -NoNewline -ForegroundColor Yellow
        $c = Read-Host
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        switch ($c.ToUpper()) {
            "1" { Clear-DnsClientCache; Write-Host "`n[OK] Кэш DNS успешно очищен!" -ForegroundColor Green; Start-Sleep -Seconds 1 }
            "2" {
                $shaderPaths = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache")
                foreach ($sp in $shaderPaths) { if (Test-Path $sp) { Remove-Item "$sp\*" -Recurse -Force -ErrorAction SilentlyContinue } }
                Write-Host "`n[OK] Кэши шейдеров DirectX и NVIDIA успешно очищены!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "3" {
                Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "C:\Windows\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Временные файлы Temp и кэш оптимизации доставки очищены!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "4" {
                wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
                Write-Host "`n[OK] Системные журналы событий Windows успешно очищены!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "5" {
                $scriptPath = Join-Path $PSScriptRoot "scripts\Nuclear-Debloat.ps1"
                if (Test-Path $scriptPath) { & $scriptPath }
                Write-Host "`n[OK] Nuclear Debloat завершен!" -ForegroundColor Green
                Start-Sleep 2
            }
            "A" { & (Join-Path $scriptsDir "Cleaner-Tweaks.ps1"); pause }
            "Q" { return }
            "0" { return }
        }
    }
}

# ==============================================================================
#  ОБРАБОТКА НЕИНТЕРАКТИВНЫХ ВЫЗОВОВ (-Action)
# ==============================================================================
switch ($Action) {
    'All' {
        $snapDir = Join-Path (Join-Path $PSScriptRoot "backup") "snapshots"
        if (-not (Test-Path (Join-Path $snapDir "LATEST.txt"))) {
            & (Join-Path $scriptsDir "Backup-SystemState.ps1") -Quiet
        }
        $baselineFile = Join-Path (Join-Path $PSScriptRoot "backup") "kernelos_baseline.json"
        if (-not (Test-Path $baselineFile)) {
            & (Join-Path $scriptsDir "Backup-KernelOS.ps1") -Quiet
        }
        & (Join-Path $scriptsDir "System-Tweaks.ps1")
        & (Join-Path $scriptsDir "Network-Tweaks.ps1")
        & (Join-Path $scriptsDir "Security-Tweaks.ps1")
        & (Join-Path $scriptsDir "Privacy-Tweaks.ps1")
                                & (Join-Path $scriptsDir "Visibility-Tweaks.ps1")
            & (Join-Path $scriptsDir "Services-Tweaks.ps1")
            & (Join-Path $scriptsDir "Debloat-UWP.ps1")
            & (Join-Path $scriptsDir "Mouse-Tweaks.ps1")
            & (Join-Path $scriptsDir "Cursor-Tweaks.ps1") -Quiet
        & (Join-Path $scriptsDir "Steam-Tweaks.ps1") -Quiet
        & (Join-Path $scriptsDir "EpicGames-Tweaks.ps1") -Quiet
        & (Join-Path $scriptsDir "Spotify-Tweaks.ps1") -Quiet
        & (Join-Path $scriptsDir "LGHUB-Tweaks.ps1") -Quiet
        & (Join-Path $scriptsDir "App-Tweaks.ps1")
        return
    }
    'Backup' {
        & (Join-Path $scriptsDir "Backup-KernelOS.ps1")
        return
    }
    'RestoreKernelOS' {
        & (Join-Path $scriptsDir "Restore-KernelOS.ps1")
        return
    }
    'RestoreSnapshot' {
        & (Join-Path $scriptsDir "Restore-SystemState.ps1") -ForceLatest
        return
    }
    'ResetDefault' {
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
        Remove-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleForced" -ErrorAction SilentlyContinue
        Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "1"
        Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "6"
        Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "10"
        Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 1
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue | Out-Null
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue | Out-Null
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
        Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -ErrorAction SilentlyContinue
        Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
        Write-Host "`n[OK] Все параметры успешно сброшены к чистым стоковым заводским значениям Microsoft Windows!" -ForegroundColor Yellow
        return
    }
    'Status' {
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        Write-Host "            ТЕКУЩИЙ СТАТУС СИСТЕМЫ (GAMING & SYSTEM OPTIMIZER)                " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        $mmcss = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
        $prio = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
        $vbs = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        $wpbt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).DisableWpbtExecution
        $anim = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue).DisallowAnimations
        if ($null -eq $anim) {
            $anim = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue).DisallowAnimations
        }
        Write-Host "  MMCSS SystemResponsiveness: $($mmcss.SystemResponsiveness) (Оптимум: 10)"
        Write-Host "  MMCSS NetworkThrottling:    $($mmcss.NetworkThrottlingIndex) (Оптимум: 4294967295)"
        Write-Host "  Win32PrioritySeparation:    $prio (Оптимум Ryzen 9850X3D: 38)"
        Write-Host "  VBS / VirtualizationSecurity: $($vbs) (Отключено: 0)"
        Write-Host "  WPBT Execution:             $($wpbt) (Заблокировано: 1)"
        Write-Host "  DWM DisallowAnimations:     $($anim) (Отключено: 1)"
        Write-Host "==============================================================================" -ForegroundColor DarkCyan
        return
    }
}

if ($false) { # REMOVED TO PREVENT CRASH
    Write-Host "[i] Неинтерактивная сессия: используйте параметр -Action для автоматизации." -ForegroundColor Yellow
    return
}

# ==============================================================================
#  ГЛАВНОЕ МЕНЮ (MASTER MENU)
# ==============================================================================
while ($true) {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "        КОМПЛЕКСНЫЙ ПАКЕТ ОПТИМИЗАЦИИ (Gaming & System Optimizer v2.1)        " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
      Write-Host " CPU: $($global:SysCpu) | GPU: $($global:SysGpu)" -ForegroundColor DarkGray
      Write-Host " RAM: $($global:SysRam) | Сеть: $($global:SysNic)" -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host " [1]   🖥️    Системные твики и ядро (System & Kernel: MMCSS, Quantum, Timer, DWM)" -ForegroundColor White
    Write-Host " [2]   🌐    Сетевые твики и TCP/IP (Network: Realtek, Nagle, Buffers, Coalescing)" -ForegroundColor White
    Write-Host " [3]   ⚡    Электропитание и таймеры (Power & Timers: Coalescing, Energy, Audio)" -ForegroundColor White
    Write-Host " [4]   🖱️    Периферия, мышь, ввод (Peripherals: RawMouseThrottle, Accel Off, Duck)" -ForegroundColor White
    Write-Host " [5]   🟩    NVIDIA и видеокарта (GPU: MSI Mode, High Priority, Telemetry, TDR)" -ForegroundColor White
    Write-Host " [6]   🎮    Клиенты, лаунчеры и приложения (Steam, Epic, Discord, Spotify...)" -ForegroundColor White
    Write-Host " [7]   🛡️    Приватность и службы (Privacy: Telemetry, DiagTrack, WSearch, SysMain)" -ForegroundColor White
    Write-Host " [8]   🔒    Безопасность и VBS (Security: VBS/HVCI Off, WPBT Block, DO P2P Off)" -ForegroundColor White
    Write-Host " [9]   📁    Проводник и интерфейс (Visibility: Classic Menu, Animations, Details)" -ForegroundColor White
    Write-Host " [10]  🧹    Очистка кэшей и шейдеров (Maintenance: Shader Caches, DNS, Temp Logs)" -ForegroundColor White
    Write-Host " [11]  🤖    Удаление ИИ (AI Debloat)" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " [A]   🚀    ПРИМЕНИТЬ ВСЕ РЕКОМЕНДОВАННЫЕ ТВИКИ (All In One)" -ForegroundColor Green
    Write-Host " [B]   💾    СОХРАНИТЬ РЕЗЕРВНЫЙ СНИМОК СИСТЕМЫ (Динамический бэкап ДО твиков)" -ForegroundColor Magenta
    Write-Host " [D]   ↩️    ОТКАТ НАСТРОЕК (По снимку этой системы / KernelOS / Дефолт MS)" -ForegroundColor Yellow
    Write-Host " [R]   🔄    Перезапустить проводник Windows (Explorer)" -ForegroundColor Cyan
    Write-Host " [Q]   ❌    Выход" -ForegroundColor DarkGray
    Write-Host "==============================================================================" -ForegroundColor DarkCyan
    Write-Host "`nВыберите пункт меню [1-11, A, B, D, R, Q]: " -NoNewline -ForegroundColor Yellow
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
        "11" { Menu-Nova }
        "A" {
            $snapDir = Join-Path (Join-Path $PSScriptRoot "backup") "snapshots"
            $latestFile = Join-Path $snapDir "LATEST.txt"
            if (-not (Test-Path $latestFile)) {
                Write-Host "`n[!] Резервный снимок текущей системы ещё не создан." -ForegroundColor Yellow
                $ans = if ($NonInteractive) { "Y" } else {
                    Write-Host "Создать автоматический снимок ДО применения твиков? (Y/N): " -NoNewline -ForegroundColor Cyan
                    Read-Host
                }
                if ($ans -and $ans.ToUpper() -eq "Y") {
                    & (Join-Path $scriptsDir "Backup-SystemState.ps1")
                }
            }
            $baselineFile = Join-Path (Join-Path $PSScriptRoot "backup") "kernelos_baseline.json"
            if (-not (Test-Path $baselineFile)) {
                & (Join-Path $scriptsDir "Backup-KernelOS.ps1") -Quiet
            }

            Write-Host "`n>>> Применение полного комплекса оптимизаций Gaming & System Optimizer..." -ForegroundColor Cyan
            & (Join-Path $scriptsDir "System-Tweaks.ps1")
            & (Join-Path $scriptsDir "Network-Tweaks.ps1")
            & (Join-Path $scriptsDir "Security-Tweaks.ps1")
            & (Join-Path $scriptsDir "Privacy-Tweaks.ps1")
                                    & (Join-Path $scriptsDir "Visibility-Tweaks.ps1")
            & (Join-Path $scriptsDir "Services-Tweaks.ps1")
            & (Join-Path $scriptsDir "Debloat-UWP.ps1")
            & (Join-Path $scriptsDir "Mouse-Tweaks.ps1")
            & (Join-Path $scriptsDir "Cursor-Tweaks.ps1") -Quiet
            & (Join-Path $scriptsDir "Steam-Tweaks.ps1") -Quiet
            & (Join-Path $scriptsDir "EpicGames-Tweaks.ps1") -Quiet
            & (Join-Path $scriptsDir "Spotify-Tweaks.ps1") -Quiet
            & (Join-Path $scriptsDir "LGHUB-Tweaks.ps1") -Quiet
            & (Join-Path $scriptsDir "App-Tweaks.ps1")
            & (Join-Path $scriptsDir "Ultra-Tweaks.ps1")
            Write-Host "`n[OK] Все рекомендованные твики успешно применены! Перезагрузите компьютер." -ForegroundColor Green
            if (-not $NonInteractive) { pause }
        }
        "B" {
            & (Join-Path $scriptsDir "Backup-KernelOS.ps1")
            if (-not $NonInteractive) { pause }
        }
        "D" {
            Clear-Host
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host "               МЕНЮ ОТКАТА И ВОССТАНОВЛЕНИЯ НАСТРОЕК                         " -ForegroundColor Cyan
            Write-Host "==============================================================================" -ForegroundColor DarkCyan
            Write-Host " [1]  ↩️  Точный откат по снимку реестра (backup/kernelos_baseline.json)" -ForegroundColor Green
            Write-Host "          (Восстанавливает EXACT значения, удаляет созданные ключи/параметры)"
            Write-Host " [2]  📁  Откат по сохранённым архивам веток реестра (backup/snapshots/)" -ForegroundColor Cyan
            Write-Host "          (Восстановление из полных .reg дампов)"
            Write-Host " [3]  ⚠️  Сброс в стандартный заводской дефолт Microsoft Windows 11" -ForegroundColor Yellow
            Write-Host "          (Внимание: вернет стоковые лимиты MS и включит системные службы)"
            Write-Host " [Q]  Отмена" -ForegroundColor DarkGray
            Write-Host "`nВыберите вариант [1, 2, 3, Q]: " -NoNewline -ForegroundColor Yellow
            $rc = Read-Host
            if ($rc -eq "1") {
                & (Join-Path $scriptsDir "Restore-KernelOS.ps1")
                if (-not $NonInteractive) { pause }
            } elseif ($rc -eq "2") {
                & (Join-Path $scriptsDir "Restore-SystemState.ps1")
                if (-not $NonInteractive) { pause }
            } elseif ($rc -eq "3") {
                Write-Host "`n>>> Сброс всех параметров к заводским стандартам Microsoft Windows..." -ForegroundColor Yellow
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
                Remove-ItemProperty "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleForced" -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "1"
                Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "6"
                Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "10"
                Set-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name "UserDuckingPreference" -Type DWord -Value 1
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Type DWord -Value 100
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Type DWord -Value 100
                $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
                if ($adapter) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue | Out-Null
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "128" -ErrorAction SilentlyContinue | Out-Null
                }
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
                Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWpbtExecution" -ErrorAction SilentlyContinue
                Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DWM" -Name "DisallowAnimations" -Type DWord -Value 0
                Write-Host "`n[OK] Все параметры успешно сброшены к чистым стоковым заводским значениям Microsoft Windows!" -ForegroundColor Yellow
                if (-not $NonInteractive) { pause }
            }
        }
        "R" {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
            Write-Host "`n[OK] Проводник Windows успешно перезапущен!" -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "Q" { Clear-Host; exit }
        "0" { Clear-Host; exit }
    }
}