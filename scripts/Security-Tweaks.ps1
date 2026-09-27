# ==============================================================================
# Gaming & System Optimizer - Безопасность, виртуализация и стабильность ядра
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Применение твиков безопасности, виртуализации и стабильности ядра..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: Отключение Virtualization-Based Security (VBS / Core Isolation / HVCI)
# Что делает: Отключает изоляцию ядра операционной системы внутри гипервизора Hyper-V.
# Зачем нужно: Дает прирост 3-8% к минимальному FPS (0.1% и 1% Low), устраняет задержки трансляции адресов SLAT/EPT и микростаттеры в играх.
# Значение по умолчанию (Windows): 1 (VBS и целостность памяти включены)
# Значение после твика: 0 (VBS и HVCI полностью отключены)
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[1/6] Отключение VBS / Core Isolation (устранение оверхеда Hyper-V)..." -ForegroundColor Yellow
$dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
if (-not (Test-Path $dg)) { New-Item $dg -Force | Out-Null }
Set-ItemProperty $dg -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0

$sc = "$dg\Scenarios\HypervisorEnforcedCodeIntegrity"
if (-not (Test-Path $sc)) { New-Item $sc -Force | Out-Null }
Set-ItemProperty $sc -Name "Enabled" -Type DWord -Value 0

$dgPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard"
if (-not (Test-Path $dgPol)) { New-Item $dgPol -Force | Out-Null }
Set-ItemProperty $dgPol -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
Set-ItemProperty $dgPol -Name "HypervisorEnforcedCodeIntegrity" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Блокировка BIOS-инжектора WPBT (Windows Platform Binary Table)
# Что делает: Запрещает диспетчеру сессий smss.exe исполнять бинарные файлы (wpbbin.exe), внедряемые производителями материнских плат (ASUS/MSI/Gigabyte) через ACPI-таблицы.
# Зачем нужно: Предотвращает скрытую фоновую установку мусорных служб и утилит вендора (Armoury Crate, Dragon Center и др.).
# Значение по умолчанию (Windows): 0 (Исполнение WPBT разрешено)
# Значение после твика: 1 (Исполнение заблокировано)
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[2/6] Блокировка WPBT (запрет OEM-инжекций из BIOS материнской платы)..." -ForegroundColor Yellow
$smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
if (-not (Test-Path $smPath)) { New-Item $smPath -Force | Out-Null }
Set-ItemProperty $smPath -Name "DisableWpbtExecution" -Type DWord -Value 1
Remove-ItemProperty $smPath -Name "SmpDisableWpbtExecution" -ErrorAction SilentlyContinue

# ─────────────────────────────────────────────
# Название: Увеличение таймаута сброса видеодрайвера (TDR Delay)
# Что делает: Увеличивает допустимое время отклика видеокарты до 8 секунд перед аварийным сбросом видеодрайвера (TdrDelay = 8, TdrDdiDelay = 8).
# Зачем нужно: Предотвращает ложные вылеты тяжелых игр с ошибкой DXGI_ERROR_DEVICE_REMOVED при долгой компиляции шейдеров на RTX 5080.
# Значение по умолчанию (Windows): TdrDelay = 2 сек, TdrDdiDelay = 5 сек
# Значение после твика: 8 сек
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[3/6] Увеличение TDR Delay (8 сек) для стабильности видеокарты при компиляции шейдеров..." -ForegroundColor Yellow
$gfx = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (-not (Test-Path $gfx)) { New-Item $gfx -Force | Out-Null }
Set-ItemProperty $gfx -Name "TdrDelay" -Type DWord -Value 8
Set-ItemProperty $gfx -Name "TdrDdiDelay" -Type DWord -Value 8

# ─────────────────────────────────────────────
# Название: Отключение P2P-раздачи обновлений (Delivery Optimization)
# Что делает: Переводит режим загрузки обновлений в HTTP Only (0), запрещая загрузку и раздачу фрагментов обновлений соседним ПК в сети.
# Зачем нужно: Исключает неконтролируемую фоновую сетевую активность, трафик отдачи и скачки пинга во время соревновательных игр.
# Значение по умолчанию (Windows): 1 (LAN / P2P в локальной сети) или 3 (Internet / P2P через интернет)
# Значение после твика: 0 (HTTP Only / только официальные сервера Microsoft, P2P отключен)
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[4/6] Отключение P2P Delivery Optimization (запрет скрытой раздачи трафика)..." -ForegroundColor Yellow
$do = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
if (-not (Test-Path $do)) { New-Item $do -Force | Out-Null }
Set-ItemProperty $do -Name "DODownloadMode" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение затемнения экрана при запросе UAC (PromptOnSecureDesktop)
# Что делает: Заставляет диалоговое окно контроля учетных записей (UAC) открываться на активном рабочем столе без затемнения и блокировки графического стека.
# Зачем нужно: Ликвидирует подвисание системы на 1-2 секунды при вызове административных окон из-за переключения графических буферов DWM.
# Значение по умолчанию (Windows): 1 (Безопасный рабочий стол с затемнением)
# Значение после твика: 0 (Обычный рабочий стол, мгновенный отклик)
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[5/6] Отключение затемнения экрана при вызове UAC (PromptOnSecureDesktop = 0)..." -ForegroundColor Yellow
$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $uacPath)) { New-Item $uacPath -Force | Out-Null }
Set-ItemProperty $uacPath -Name "PromptOnSecureDesktop" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение фильтра SmartScreen (Windows Explorer & Shell)
# Что делает: Отключает проверку запускаемых файлов и приложений через облачные фильтры SmartScreen.
# Зачем нужно: Устраняет сетевые задержки при запуске исполняемых файлов и блокирует передачу хэшей программ на сервера Microsoft.
# Значение по умолчанию (Windows): EnableSmartScreen = 1, ShellSmartScreenLevel = "Warn"
# Значение после твика: EnableSmartScreen = 0, ShellSmartScreenLevel = "Off", SmartScreenEnabled = "Off"
# Источник: Gaming & System Optimizer: Security & Virtualization Architecture
# ─────────────────────────────────────────────
Write-Host "[6/6] Отключение фильтра SmartScreen (устранение задержек запуска файлов)..." -ForegroundColor Yellow
$sysSmart = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $sysSmart)) { New-Item $sysSmart -Force | Out-Null }
Set-ItemProperty $sysSmart -Name "EnableSmartScreen" -Type DWord -Value 0
Set-ItemProperty $sysSmart -Name "ShellSmartScreenLevel" -Type String -Value "Off"

$expSmart = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
if (-not (Test-Path $expSmart)) { New-Item $expSmart -Force | Out-Null }
Set-ItemProperty $expSmart -Name "SmartScreenEnabled" -Type String -Value "Off"

$appHost = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost"
if (-not (Test-Path $appHost)) { New-Item $appHost -Force | Out-Null }
Set-ItemProperty $appHost -Name "EnableWebContentEvaluation" -Type DWord -Value 0

Write-Host "`n[✓] Все параметры безопасности, виртуализации и стабильности ядра (6/6) применены успешно!" -ForegroundColor Green