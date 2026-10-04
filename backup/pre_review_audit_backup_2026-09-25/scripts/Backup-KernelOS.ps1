# ==============================================================================
#  KERNELOS SNAPSHOT CREATOR
#  Captures current registry hives and JSON status
# ==============================================================================

$backupDir = Join-Path (Split-Path $PSScriptRoot -Parent) "backup"
if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory | Out-Null }

Write-Host "Создание резервного слепка текущего состояния KernelOS..." -ForegroundColor Cyan

reg export "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "$backupDir\01_PriorityControl_KernelOS.reg" /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "$backupDir\02_Kernel_SessionManager_KernelOS.reg" /y | Out-Null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "$backupDir\03_MMCSS_KernelOS.reg" /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "$backupDir\04_GraphicsDrivers_KernelOS.reg" /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" "$backupDir\05_DeviceGuard_VBS_KernelOS.reg" /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Power" "$backupDir\06_Power_KernelOS.reg" /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" "$backupDir\07_FileSystem_KernelOS.reg" /y | Out-Null

Write-Host "[OK] Слепок успешно сохранен в $backupDir" -ForegroundColor Green
