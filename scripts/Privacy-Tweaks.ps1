# ==============================================================================
# Gaming & System Optimizer - Приватность, телеметрия и фоновые службы
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Применение твиков конфиденциальности, телеметрии и фоновых служб..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: Отключение общей телеметрии Windows (AllowTelemetry)
# Что делает: Задает уровень сбора телеметрии и диагностических данных в значение 0 (Security / отключено).
# Зачем нужно: Предотвращает сбор и регулярную отправку фоновых телеметрических пакетов на серверы Microsoft.
# Значение по умолчанию (Windows): 3 (Full / Полная телеметрия) или 1 (Required)
# Значение после твика: 0 (Security / Disabled)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[1/15] Отключение общей телеметрии Windows (AllowTelemetry = 0)..." -ForegroundColor Yellow
$dcMachine = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $dcMachine)) { New-Item $dcMachine -Force | Out-Null }
Set-ItemProperty $dcMachine -Name "AllowTelemetry" -Type DWord -Value 0
Set-ItemProperty $dcMachine -Name "DisableEnterpriseAuthProxy" -Type DWord -Value 1
Set-ItemProperty $dcMachine -Name "CommercialId" -Type String -Value ""

$dcUser = "HKCU:\Software\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $dcUser)) { New-Item $dcUser -Force | Out-Null }
Set-ItemProperty $dcUser -Name "AllowTelemetry" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение телеметрии приложений и сбора инвентаря (AppCompat Telemetry & Inventory)
# Что делает: Отключает сбор данных о совместимости приложений (AITEnable = 0) и сбор инвентаря установленных программ (DisableInventory = 1).
# Зачем нужно: Устраняет фоновую нагрузку при запуске программ и запрещает отправку списка установленного ПО.
# Значение по умолчанию (Windows): AITEnable = 1, DisableInventory = 0
# Значение после твика: AITEnable = 0, DisableInventory = 1
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[2/15] Отключение телеметрии приложений и сбора инвентаря..." -ForegroundColor Yellow
$appCompat = "HKLM:\Software\Policies\Microsoft\Windows\AppCompat"
if (-not (Test-Path $appCompat)) { New-Item $appCompat -Force | Out-Null }
Set-ItemProperty $appCompat -Name "AITEnable" -Type DWord -Value 0
Set-ItemProperty $appCompat -Name "DisableInventory" -Type DWord -Value 1

$sqm = "HKLM:\Software\Policies\Microsoft\SQMClient\Windows"
if (-not (Test-Path $sqm)) { New-Item $sqm -Force | Out-Null }
Set-ItemProperty $sqm -Name "CEIPEnable" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение рекламного идентификатора (Advertising ID)
# Что делает: Запрещает использование рекламного идентификатора пользователя для персонализации рекламы в приложениях.
# Зачем нужно: Блокирует профилирование активности пользователя и отслеживание поведения в приложениях Windows.
# Значение по умолчанию (Windows): 0 (Включен)
# Значение после твика: 1 (Отключен политикой)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[3/15] Отключение рекламного идентификатора (Advertising ID)..." -ForegroundColor Yellow
$adv = "HKLM:\Software\Policies\Microsoft\Windows\AdvertisingInfo"
if (-not (Test-Path $adv)) { New-Item $adv -Force | Out-Null }
Set-ItemProperty $adv -Name "DisabledByGroupPolicy" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Отключение отчетов об ошибках Windows (Windows Error Reporting / WER)
# Что делает: Отключает службу WerSvc, фоновую генерацию отчетов о падениях WerFault.exe и сбор дампов памяти.
# Зачем нужно: При сбое игры или процесса окно закрывается мгновенно, без 10-30 секундного зависания интерфейса на сбор дампа.
# Значение по умолчанию (Windows): Disabled = 0, служба WerSvc работает в режиме Manual
# Значение после твика: Disabled = 1, служба WerSvc остановлена и отключена
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[4/15] Отключение отчетов об ошибках WER (устранение зависаний при сбоях)..." -ForegroundColor Yellow
$werPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
if (-not (Test-Path $werPolicy)) { New-Item $werPolicy -Force | Out-Null }
Set-ItemProperty $werPolicy -Name "Disabled" -Type DWord -Value 1

$werMachine = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
if (-not (Test-Path $werMachine)) { New-Item $werMachine -Force | Out-Null }
Set-ItemProperty $werMachine -Name "Disabled" -Type DWord -Value 1

Stop-Service "WerSvc" -Force 2>$null
Set-Service "WerSvc" -StartupType Disabled 2>$null
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Error Reporting\" -TaskName "QueueReporting" -ErrorAction SilentlyContinue | Out-Null

# ─────────────────────────────────────────────
# Название: Отключение службы сбора телеметрии DiagTrack
# Что делает: Останавливает и переводит в режим 'Disabled' основную системную службу сбора метрик (Connected User Experiences and Telemetry).
# Зачем нужно: Полностью ликвидирует процессорную нагрузку и дисковую активность службы сбора телеметрии.
# Значение по умолчанию (Windows): Работает (Automatic)
# Значение после твика: Отключена (Disabled, Stopped)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[5/15] Отключение системной службы телеметрии DiagTrack..." -ForegroundColor Yellow
Stop-Service "DiagTrack" -Force 2>$null
Set-Service "DiagTrack" -StartupType Disabled 2>$null

# ─────────────────────────────────────────────
# Название: Отключение службы кэширования SysMain (SuperFetch)
# Что делает: Отключает службу упреждающего чтения и фонового построения карты использования приложений (layout.ini).
# Зачем нужно: Исключает спонтанные всплески фонового чтения и записи на скоростном NVMe PCIe SSD во время игрового процесса.
# Значение по умолчанию (Windows): Работает (Automatic)
# Значение после твика: Отключена (Disabled, Stopped)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[6/15] Отключение SysMain (устранение фонового чтения NVMe SSD)..." -ForegroundColor Yellow
Stop-Service "SysMain" -Force 2>$null
Set-Service "SysMain" -StartupType Disabled 2>$null

# ─────────────────────────────────────────────
# Название: Отключение службы индексации Windows Search (WSearch)
# Что делает: Останавливает и отключает процесс SearchIndexer.exe, непрерывно сканирующий файлы на накопителях.
# Зачем нужно: Снижает дисковую активность до нуля в простое и тяжелых играх, исключает задержки I/O и нагрев дисков.
# Значение по умолчанию (Windows): Работает (Automatic / Delayed)
# Значение после твика: Отключена (Disabled, Stopped)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[7/15] Отключение службы индексации Windows Search..." -ForegroundColor Yellow
Stop-Service "WSearch" -Force 2>$null
Set-Service "WSearch" -StartupType Disabled 2>$null

# ─────────────────────────────────────────────
# Название: Отключение службы и политик загрузки карт (MapsBroker)
# Что делает: Отключает службу скачивания карт MapsBroker и запрещает фоновый сетевой опрос серверов картографии.
# Зачем нужно: Устраняет фоновую сетевую активность и высвобождает память от неиспользуемого на стационарном ПК сервиса.
# Значение по умолчанию (Windows): AutoDownloadAndUpdateMapData не задан, служба MapsBroker (Delayed Start)
# Значение после твика: Служба отключена, политики запрещают сетевой трафик
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[8/15] Отключение службы и сетевых запросов карт MapsBroker..." -ForegroundColor Yellow
$maps = "HKLM:\Software\Policies\Microsoft\Windows\Maps"
if (-not (Test-Path $maps)) { New-Item $maps -Force | Out-Null }
Set-ItemProperty $maps -Name "AutoDownloadAndUpdateMapData" -Type DWord -Value 0
Set-ItemProperty $maps -Name "AllowUntriggeredNetworkTrafficOnSettingsPage" -Type DWord -Value 0
Stop-Service "MapsBroker" -Force 2>$null
Set-Service "MapsBroker" -StartupType Disabled 2>$null

# ─────────────────────────────────────────────
# Название: Отключение истории активности (Activity History & Search History)
# Что делает: Запрещает Windows локально сохранять хронологию запуска приложений и синхронизировать её с серверами Microsoft.
# Зачем нужно: Прекращает постоянный сбор и передачу логов пользовательской активности в учетную запись.
# Значение по умолчанию (Windows): EnableActivityFeed = 1, PublishUserActivities = 1, UploadUserActivities = 1
# Значение после твика: 0 (Отключено)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[9/15] Отключение сбора и синхронизации истории активности..." -ForegroundColor Yellow
$sysPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $sysPolicy)) { New-Item $sysPolicy -Force | Out-Null }
Set-ItemProperty $sysPolicy -Name "EnableActivityFeed" -Type DWord -Value 0
Set-ItemProperty $sysPolicy -Name "PublishUserActivities" -Type DWord -Value 0
Set-ItemProperty $sysPolicy -Name "UploadUserActivities" -Type DWord -Value 0

$expPolicy = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (-not (Test-Path $expPolicy)) { New-Item $expPolicy -Force | Out-Null }
Set-ItemProperty $expPolicy -Name "DisableSearchHistory" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Отключение Microsoft Copilot
# Что делает: Блокирует функционал боковой панели Copilot и интеграцию ИИ-помощника в интерфейс проводника и системы.
# Зачем нужно: Исключает фоновую передачу контекста рабочего стола и обращений к облачным API Microsoft.
# Значение по умолчанию (Windows): 0 (Включен)
# Значение после твика: 1 (Отключен)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[10/15] Отключение Microsoft Copilot..." -ForegroundColor Yellow
$copilot = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (-not (Test-Path $copilot)) { New-Item $copilot -Force | Out-Null }
Set-ItemProperty $copilot -Name "TurnOffWindowsCopilot" -Type DWord -Value 1

$copilotShell = "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Copilot"
if (-not (Test-Path $copilotShell)) { New-Item $copilotShell -Force | Out-Null }
Set-ItemProperty $copilotShell -Name "CopilotDisabledReason" -Type String -Value "FeatureIsDisabled"

# ─────────────────────────────────────────────
# Название: Отключение фонового анализа экранов Windows Recall AI и Click to Do
# Что делает: Запрещает Windows периодически делать скрытые снимки экрана, индексировать и распознавать контент пользователя.
# Зачем нужно: Защищает конфиденциальность личных данных, паролей и устраняет дисковую/GPU нагрузку ИИ в Windows 24H2.
# Значение по умолчанию (Windows): 0 (Анализ включен)
# Значение после твика: 1 (Анализ запрещен, Click to Do отключен)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[11/15] Отключение Windows Recall AI и функции Click to Do..." -ForegroundColor Yellow
$aiMachine = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
if (-not (Test-Path $aiMachine)) { New-Item $aiMachine -Force | Out-Null }
Set-ItemProperty $aiMachine -Name "DisableAIDataAnalysis" -Type DWord -Value 1
Set-ItemProperty $aiMachine -Name "DisableClickToDo" -Type DWord -Value 1
Set-ItemProperty $aiMachine -Name "AllowRecallEnablement" -Type DWord -Value 0

$aiUser = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
if (-not (Test-Path $aiUser)) { New-Item $aiUser -Force | Out-Null }
Set-ItemProperty $aiUser -Name "DisableAIDataAnalysis" -Type DWord -Value 1
Set-ItemProperty $aiUser -Name "DisableClickToDo" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Запрет фоновой работы UWP приложений (LetAppsRunInBackground)
# Что делает: Принудительно переводит политику запуска универсальных приложений (Store Apps) в режим Force Deny (2).
# Зачем нужно: Фоновые приложения не потребляют процессорное время, не будят ядра ЦП и не создают задержек в играх.
# Значение по умолчанию (Windows): 0 (User is in control)
# Значение после твика: 2 (Force Deny / Принудительно запрещено)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[12/15] Принудительный запрет фоновой работы UWP приложений (Force Deny = 2)..." -ForegroundColor Yellow
$appPriv = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
if (-not (Test-Path $appPriv)) { New-Item $appPriv -Force | Out-Null }
Set-ItemProperty $appPriv -Name "LetAppsRunInBackground" -Type DWord -Value 2

# ─────────────────────────────────────────────
# Название: Отключение межплатформенного взаимодействия (Cross-Device Experiences & CDP)
# Что делает: Блокирует протоколы Connected Devices Platform (RomeSdk, CdpSession, RemoteLaunch) и перенос задач между устройствами.
# Зачем нужно: Прекращает непрерывный фоновый опрос локальной сети и внешних мобильных устройств через учетную запись Microsoft.
# Значение по умолчанию (Windows): 1 (Разрешено)
# Значение после твика: 0 (Отключено)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[13/15] Отключение межплатформенного взаимодействия (CDP Policies = 0)..." -ForegroundColor Yellow
$cdp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP"
if (-not (Test-Path $cdp)) { New-Item $cdp -Force | Out-Null }
Set-ItemProperty $cdp -Name "RomeSdkChannelUserAuthzPolicy" -Type DWord -Value 0
Set-ItemProperty $cdp -Name "CdpSessionUserAuthzPolicy" -Type DWord -Value 0
Set-ItemProperty $cdp -Name "EnableRemoteLaunchToast" -Type DWord -Value 0

$resume = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration"
if (-not (Test-Path $resume)) { New-Item $resume -Force | Out-Null }
Set-ItemProperty $resume -Name "IsResumeAllowed" -Type DWord -Value 0

Set-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\System" -Name "EnableCdp" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение облачного контента, подсказок и рекомендаций (Cloud Content & Tips)
# Что делает: Запрещает Windows загружать потребительский промо-контент, подсказки в меню 'Параметры' и сторонние рекомендации.
# Зачем нужно: Устраняет всплывающие уведомления, ненужные сетевые запросы и рекомендации приложений в Windows.
# Значение по умолчанию (Windows): 0 (Включено)
# Значение после твика: 1 (Отключено)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[14/15] Отключение подсказок, потребительского контента и рекомендаций..." -ForegroundColor Yellow
$cloudMachine = "HKLM:\Software\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $cloudMachine)) { New-Item $cloudMachine -Force | Out-Null }
Set-ItemProperty $cloudMachine -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1
Set-ItemProperty $cloudMachine -Name "DisableSoftLanding" -Type DWord -Value 1

$cloudUser = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $cloudUser)) { New-Item $cloudUser -Force | Out-Null }
Set-ItemProperty $cloudUser -Name "DisableThirdPartySuggestions" -Type DWord -Value 1
Set-ItemProperty $cloudUser -Name "DisableWindowsSpotlightFeatures" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Отказ от сбора телеметрии PowerShell и .NET CLI (Opt-Out)
# Что делает: Задает переменные окружения POWERSHELL_TELEMETRY_OPTOUT и DOTNET_CLI_TELEMETRY_OPTOUT в значение 1.
# Зачем нужно: Полностью блокирует отправку данных об использовании консоли PowerShell 7+ и .NET SDK на серверы Microsoft.
# Значение по умолчанию (Windows): Не заданы (телеметрия активна)
# Значение после твика: 1 (Сбор заблокирован)
# Источник: Gaming & System Optimizer: Privacy & Background Optimization
# ─────────────────────────────────────────────
Write-Host "[15/15] Отключение телеметрии PowerShell и .NET CLI (Opt-Out = 1)..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", "Machine")
[Environment]::SetEnvironmentVariable("DOTNET_CLI_TELEMETRY_OPTOUT", "1", "Machine")
[Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", "Process")
[Environment]::SetEnvironmentVariable("DOTNET_CLI_TELEMETRY_OPTOUT", "1", "Process")

Write-Host "`n[✓] Все параметры приватности, телеметрии и фоновых служб (15/15) применены успешно!" -ForegroundColor Green
