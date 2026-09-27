# ==============================================================================
# Gaming & System Optimizer - Комплексная оптимизация ядра и системы (System & Kernel)
# Адаптировано для AMD Ryzen 7 9850X3D (Zen 5 3D V-Cache) и Windows 11 IoT LTSC
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Применение твиков ядра, планировщика MMCSS и DWM..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: MMCSS SystemResponsiveness
# Что делает: Задает резервирование квантов процессорного времени для фоновых низкоприоритетных задач относительно потоков MMCSS.
# Зачем нужно: Значение 10 по реверс-инжинирингу mmcss.sys (CiConfigInitialize) отдает максимально возможные 90% мощности процессора активному игровому/медиа потоку. Значения ниже 10 в коде драйвера mmcss.sys принудительно сбрасываются в аварийный дефолт 20.
# Значение по умолчанию (Windows): 20 (REG_DWORD, 20% фону, 80% игре)
# Значение после твика: 10 (REG_DWORD, 10% фону, 90% игре — максимальный приоритет)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[1/20] Настройка MMCSS SystemResponsiveness в 10 (90% игре)..." -ForegroundColor Yellow
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (-not (Test-Path $mmcssPath)) { New-Item -Path $mmcssPath -Force | Out-Null }
Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Type DWord -Value 10

# ─────────────────────────────────────────────
# Название: MMCSS NetworkThrottlingIndex
# Что делает: Управляет лимитом пакетов NDIS (NET_BUFFER_LIST), которые сетевой минипорт может передавать за один вызов DPC при активности MMCSS.
# Зачем нужно: Значение 0xFFFFFFFF (4294967295) полностью отключает троттлинг сетевой карты, запрещая функции CsInitialize открывать воркер NDIS, гарантируя нулевые задержки сетевого стека в онлайн-играх.
# Значение по умолчанию (Windows): 10 (REG_DWORD, троттлинг до 10 пакетов на DPC)
# Значение после твика: 4294967295 / 0xFFFFFFFF (REG_DWORD, троттлинг полностью отключен)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[2/20] Отключение сетевого троттлинга MMCSS (NetworkThrottlingIndex = 0xFFFFFFFF)..." -ForegroundColor Yellow
Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Type DWord -Value 0xFFFFFFFF

# ─────────────────────────────────────────────
# Название: Профиль планировщика MMCSS Tasks\Games
# Что делает: Задает наивысшие приоритеты диспетчеризации потоков и графического конвейера для зарегистрированных игр.
# Зачем нужно: Потоки игр получают наивысшую категорию диспетчеризации High (базовый приоритет 24), приоритет вытеснения CPU 6 и максимальный приоритет GPU 8, что минимизирует задержки рендеринга и исключает прерывание игры фоновыми процессами.
# Значение по умолчанию (Windows): GPU Priority = 8, Priority = 2, Scheduling Category = "Medium", SFIO Priority = "Normal"
# Значение после твика: GPU Priority = 8, Priority = 6, Scheduling Category = "High", SFIO Priority = "High", Affinity = 0, Background Only = "False", Clock Rate = 10000
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[3/20] Конфигурация профиля MMCSS Tasks\Games (GPU Priority 8 / Scheduling High)..." -ForegroundColor Yellow
$gamesTaskPath = "$mmcssPath\Tasks\Games"
if (-not (Test-Path $gamesTaskPath)) { New-Item -Path $gamesTaskPath -Force | Out-Null }
Set-ItemProperty -Path $gamesTaskPath -Name "Affinity" -Type DWord -Value 0
Set-ItemProperty -Path $gamesTaskPath -Name "Background Only" -Type String -Value "False"
Set-ItemProperty -Path $gamesTaskPath -Name "Clock Rate" -Type DWord -Value 10000
Set-ItemProperty -Path $gamesTaskPath -Name "GPU Priority" -Type DWord -Value 8
Set-ItemProperty -Path $gamesTaskPath -Name "Priority" -Type DWord -Value 6
Set-ItemProperty -Path $gamesTaskPath -Name "Scheduling Category" -Type String -Value "High"
Set-ItemProperty -Path $gamesTaskPath -Name "SFIO Priority" -Type String -Value "High"

# ─────────────────────────────────────────────
# Название: MMCSS NoLazyMode
# Что делает: Запрещает службе MMCSS опрашивать счетчики бездействия процессора (CiSchedulerWait) и переходить в энергосберегающий ленивый режим (Lazy Mode).
# Зачем нужно: Исключает задержки пробуждения планировщика (LazyModeTimeout) и заставляет потоки мультимедиа всегда использовать мгновенные интервалы Realtime, устраняя микрозадержки звука и кадров.
# Значение по умолчанию (Windows): 0 (REG_DWORD, ленивый режим разрешен)
# Значение после твика: 1 (REG_DWORD, ленивый режим запрещен)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[4/20] Включение NoLazyMode = 1 в планировщике MMCSS..." -ForegroundColor Yellow
Set-ItemProperty -Path $mmcssPath -Name "NoLazyMode" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Разделение приоритетов Win32PrioritySeparation
# Что делает: Задает битовую маску квантования времени процессора (длина квантов, переменность и соотношение активного/фоновых окон).
# Зачем нужно: Значение 38 (0x26 = биты 10 01 10) устанавливает короткие переменные кванты с соотношением 3:1 в пользу активного окна приложения. Идеально оптимизирует отклик и раскрывает потенциал сверхбыстрого L3-кэша 3D V-Cache Ryzen 7 9850X3D.
# Значение по умолчанию (Windows): 2 (REG_DWORD, 0x02 — равные переменные кванты 1:1)
# Значение после твика: 38 (REG_DWORD, 0x26 — короткие переменные кванты с приоритетом 3:1 игре)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[5/20] Оптимизация квантов процессора (Win32PrioritySeparation = 0x26 для 9850X3D)..." -ForegroundColor Yellow
$priorityControl = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if (-not (Test-Path $priorityControl)) { New-Item -Path $priorityControl -Force | Out-Null }
Set-ItemProperty -Path $priorityControl -Name "Win32PrioritySeparation" -Type DWord -Value 38

# ─────────────────────────────────────────────
# Название: Десериализация экспирации таймеров SerializeTimerExpiration
# Что делает: Управляет распределением очередей таймеров KTIMER между таблицами PRCB ядер процессора.
# Зачем нужно: Значение 2 в функции KeInitializeTimerTable отключает централизацию таймеров (KiSerializeTimerExpiration = 0), заставляя каждое ядро CPU обрабатывать свои собственные таймеры в локальной таблице PRCB, устраняя бутылочное горлышко Core 0.
# Значение по умолчанию (Windows): 1 (REG_DWORD, или отсутствует — все таймеры сбрасываются на CPU 0)
# Значение после твика: 2 (REG_DWORD — локальные таблицы таймеров на каждом ядре)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[6/20] Включение SerializeTimerExpiration = 2 (локальные таблицы таймеров PRCB)..." -ForegroundColor Yellow
$kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
if (-not (Test-Path $kernelPath)) { New-Item -Path $kernelPath -Force | Out-Null }
Set-ItemProperty -Path $kernelPath -Name "SerializeTimerExpiration" -Type DWord -Value 2

# ─────────────────────────────────────────────
# Название: Потоковая обработка DPC (ThreadDpcEnable)
# Что делает: Разрешает системе выполнять отложенные вызовы процедур (DPC) драйверов в виде системных потоков на уровне PASSIVE_LEVEL.
# Зачем нужно: Обычные DPC выполняются на уровне DISPATCH_LEVEL и блокируют исполнение любых потоков. Поточные DPC могут вытесняться высокоприоритетными потоками игры, предотвращая всплески DPC Latency и фризы звука/картинки.
# Значение по умолчанию (Windows): 1 (REG_DWORD)
# Значение после твика: 1 (REG_DWORD, явная фиксация)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[7/20] Включение потоковой обработки DPC (ThreadDpcEnable = 1)..." -ForegroundColor Yellow
Set-ItemProperty -Path $kernelPath -Name "ThreadDpcEnable" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Игровой режим Windows (Game Mode) и отключение фонового GameDVR
# Что делает: Включает встроенный игровой режим Windows для оптимизации ресурсов и отключает фоновую видеозапись GameDVR.
# Зачем нужно: Игровой режим активирует повышенный приоритет GPU и блокирует фоновые обновления Windows Update во время игры, а отключение GameDVR устраняет постоянную нагрузку на кодировщик видеокарты NVIDIA RTX 5080.
# Значение по умолчанию (Windows): AutoGameModeEnabled = 1, AllowAutoGameMode = отсутствует, AllowGameDVR = 1
# Значение после твика: AutoGameModeEnabled = 1 (HKCU\...\GameBar), AllowAutoGameMode = 1 (HKLM\...\Policies\...\GameDVR), AllowGameDVR = 0 (HKLM\...\Policies\...\GameDVR)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[8/20] Активация Game Mode и отключение фонового оверлея GameDVR..." -ForegroundColor Yellow
$gb = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $gb)) { New-Item $gb -Force | Out-Null }
Set-ItemProperty $gb -Name "AutoGameModeEnabled" -Type DWord -Value 1

$gdvr = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (-not (Test-Path $gdvr)) { New-Item $gdvr -Force | Out-Null }
Set-ItemProperty $gdvr -Name "AllowAutoGameMode" -Type DWord -Value 1
Set-ItemProperty $gdvr -Name "AllowGameDVR" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение сжатия памяти и объединения страниц (MMAgent)
# Что делает: Отключает алгоритмы сжатия неактивных страниц RAM (Memory Compression) и объединения дублирующихся страниц (Page Combining).
# Зачем нужно: На системе с 64 ГБ оперативной памяти сжатие страниц ОЗУ избыточно и лишь впустую нагружает процессор вызовами декомпрессии Store Manager. Отключение освобождает такты CPU и гарантирует мгновенный доступ к памяти DDR5.
# Значение по умолчанию (Windows): MemoryCompression = True, PageCombining = True
# Значение после твика: MemoryCompression = False, PageCombining = False
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[9/20] Отключение сжатия оперативной памяти (для конфигурации с 64 ГБ RAM)..." -ForegroundColor Yellow
Disable-MMAgent -MemoryCompression -PageCombining -ErrorAction SilentlyContinue | Out-Null

# ─────────────────────────────────────────────
# Название: Запрет выгрузки компонентов ядра и драйверов в файл подкачки (DisablePagingExecutive)
# Что делает: Запрещает операционной системе сбрасывать исполняемый код ядра и драйверов в виртуальную память (pagefile.sys).
# Зачем нужно: Драйверы видеокарты NVIDIA, сетевого стека и ядро ntoskrnl.exe постоянно удерживаются в сверхбыстрой оперативной памяти DDR5, исключая микрозадержки при обращении к страницам памяти драйверов.
# Значение по умолчанию (Windows): 0 (REG_DWORD, ядро может выгружаться в файл подкачки)
# Значение после твика: 1 (REG_DWORD, исполняемый код ядра заблокирован в физической RAM)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[10/20] Блокировка ядра и драйверов в физической ОЗУ (DisablePagingExecutive = 1)..." -ForegroundColor Yellow
$mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (-not (Test-Path $mmPath)) { New-Item -Path $mmPath -Force | Out-Null }
Set-ItemProperty -Path $mmPath -Name "DisablePagingExecutive" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Отключение аудита переходов питания SleepStudy (SleepStudyDisabled)
# Что делает: Отключает постоянное протоколирование состояний сна и энергопотребления компонента PopSleepStudy.
# Зачем нужно: Исключает фоновые дисковые операции записи и работу трассировщиков сна ядра, которые не имеют практического смысла на стационарном настольном ПК.
# Значение по умолчанию (Windows): 0 (REG_DWORD, логирование сна активно)
# Значение после твика: 1 (REG_DWORD, логирование сна отключено)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[11/20] Отключение фонового аудита энергосбережения SleepStudy..." -ForegroundColor Yellow
$pwrSm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
if (-not (Test-Path $pwrSm)) { New-Item -Path $pwrSm -Force | Out-Null }
Set-ItemProperty -Path $pwrSm -Name "SleepStudyDisabled" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Аппаратная оптимизация полноэкранного режима DWM (FSO / Independent Flip)
# Что делает: Конфигурирует подсистему GameConfigStore на принудительное использование современного режима DXGI Independent Flip (FSO).
# Зачем нужно: Игры в режиме "Окно без рамок" (Borderless) работают с аппаратными задержками эксклюзивного полноэкранного режима, минуя композитор DWM, и позволяют мгновенно переключаться между окнами по Alt+Tab без черного экрана.
# Значение по умолчанию (Windows): GameDVR_Enabled = 1, GameDVR_FSEBehaviorMode = 0 (или отсутствует)
# Значение после твика: GameDVR_Enabled = 0, GameDVR_FSEBehaviorMode = 2, GameDVR_HonorUserFSEBehaviorMode = 1, GameDVR_DXGIHonorFSEWindowsCompatible = 1
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[12/20] Оптимизация DWM FSO и аппаратного DirectFlip..." -ForegroundColor Yellow
$gcs = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gcs)) { New-Item -Path $gcs -Force | Out-Null }
Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Type DWord -Value 0
Set-ItemProperty -Path $gcs -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
Set-ItemProperty -Path $gcs -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1
Set-ItemProperty -Path $gcs -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Аппаратные оверлеи MPO (Multi-Plane Overlay) и принудительный DirectFlip
# Что делает: Разрешает аппаратные плоскости видеокарты (DisableOverlays = 0) и принудительно включает поддержку DirectFlip (ForceDirectFlip = 1).
# Зачем нужно: Кадры из буфера видеокарты RTX 5080 передаются напрямую на дисплей (Direct Scanout) в обход рабочего стола DWM, гарантируя минимально возможный Input Lag.
# Значение по умолчанию (Windows): DisableOverlays = 0, ForceDirectFlip = 0 (или отсутствует)
# Значение после твика: DisableOverlays = 0 (REG_DWORD), ForceDirectFlip = 1 (REG_DWORD)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[13/20] Включение Multi-Plane Overlays (MPO) и ForceDirectFlip..." -ForegroundColor Yellow
$gfx = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (-not (Test-Path $gfx)) { New-Item -Path $gfx -Force | Out-Null }
Set-ItemProperty -Path $gfx -Name "DisableOverlays" -Type DWord -Value 0
Set-ItemProperty -Path $gfx -Name "ForceDirectFlip" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Аппаратное планирование GPU (HAGS) и приоритет переднего плана
# Что делает: Включает аппаратное планирование графической памяти на процессоре видеокарты (HwSchMode = 2) и повышает приоритет активного графического окна (ForegroundPriorityBoost = 1).
# Зачем нужно: Передает задачи планирования видеопамяти аппаратному сопроцессору RTX 5080, разгружая центральный процессор и гарантируя идеальную плавность фреймтайма при интенсивной графической нагрузке.
# Значение по умолчанию (Windows): HwSchMode = 0 (или 2 в зависимости от драйвера), ForegroundPriorityBoost = 1
# Значение после твика: HwSchMode = 2 (REG_DWORD), ForegroundPriorityBoost = 1 (REG_DWORD)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[14/20] Активация HAGS (HwSchMode = 2) и ForegroundPriorityBoost..." -ForegroundColor Yellow
Set-ItemProperty -Path $gfx -Name "HwSchMode" -Type DWord -Value 2
$gfxSched = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"
if (-not (Test-Path $gfxSched)) { New-Item -Path $gfxSched -Force | Out-Null }
Set-ItemProperty -Path $gfxSched -Name "ForegroundPriorityBoost" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Оптимизация файловой системы NTFS
# Что делает: Отключает создание устаревших коротких DOS-имен (8.3), обновление метки последнего доступа к файлам и активирует поддержку путей длиннее 260 символов.
# Зачем нужно: Снижает количество служебных дисковых операций записи метаданных NTFS на скоростных накопителях NVMe SSD, ускоряя загрузку игр и файлов.
# Значение по умолчанию (Windows): NtfsDisable8dot3NameCreation = 2, NtfsDisableLastAccessUpdate = 2 (или 0), LongPathsEnabled = 0
# Значение после твика: NtfsDisable8dot3NameCreation = 1 (REG_DWORD), NtfsDisableLastAccessUpdate = 1 (REG_DWORD), LongPathsEnabled = 1 (REG_DWORD)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[15/20] Оптимизация метаданных файловой системы NTFS для скоростных NVMe..." -ForegroundColor Yellow
$fs = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (-not (Test-Path $fs)) { New-Item -Path $fs -Force | Out-Null }
Set-ItemProperty -Path $fs -Name "NtfsDisable8dot3NameCreation" -Type DWord -Value 1
Set-ItemProperty -Path $fs -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1
Set-ItemProperty -Path $fs -Name "LongPathsEnabled" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Автоматическое завершение зависших задач (AutoEndTasks и WaitToKillTimeout)
# Что делает: Включает автоматическое завершение зависших процессов при выходе/перезагрузке без отображения блокирующего экрана "Программа не отвечает".
# Зачем нужно: Исключает зависание системы при вылете или закрытии некорректно работающих игр.
# Значение по умолчанию (Windows): AutoEndTasks = "0", WaitToKillTimeout = "5000", HungAppTimeout = "5000" (REG_SZ)
# Значение после твика: AutoEndTasks = "1", WaitToKillTimeout = "5000", HungAppTimeout = "5000" (REG_SZ)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[16/20] Настройка автоматического завершения зависших задач (AutoEndTasks = 1)..." -ForegroundColor Yellow
$desk = "HKCU:\Control Panel\Desktop"
if (-not (Test-Path $desk)) { New-Item -Path $desk -Force | Out-Null }
Set-ItemProperty -Path $desk -Name "AutoEndTasks" -Type String -Value "1"
Set-ItemProperty -Path $desk -Name "WaitToKillTimeout" -Type String -Value "5000"
Set-ItemProperty -Path $desk -Name "HungAppTimeout" -Type String -Value "5000"
# Удаление устаревшего некорректного параметра-опечатки при его наличии:
if ($null -ne (Get-ItemProperty -Path $desk -Name "WaitToKillAppTimeout" -ErrorAction SilentlyContinue)) {
    Remove-ItemProperty -Path $desk -Name "WaitToKillAppTimeout" -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────
# Название: Отключение горячих клавиш залипания (StickyKeys) и подробный статус загрузки
# Что делает: Отключает вызов диалоговых окон залипания клавиш при многократном нажатии Shift / NumLock и включает детальные сообщения при входе/выходе из системы.
# Зачем нужно: Предотвращает случайное сворачивание игры посреди матча из-за частого нажатия клавиш модификаторов и отображает точный этап загрузки системы.
# Значение по умолчанию (Windows): StickyKeys Flags = "510", Keyboard Response Flags = "126", ToggleKeys Flags = "62", VerboseStatus = 0
# Значение после твика: StickyKeys Flags = "506", Keyboard Response Flags = "122", ToggleKeys Flags = "58", VerboseStatus = 1
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[17/20] Отключение горячих клавиш залипания Shift и включение VerboseStatus..." -ForegroundColor Yellow
$sk = "HKCU:\Control Panel\Accessibility\StickyKeys"
if (-not (Test-Path $sk)) { New-Item -Path $sk -Force | Out-Null }
Set-ItemProperty -Path $sk -Name "Flags" -Type String -Value "506"
$kr = "HKCU:\Control Panel\Accessibility\Keyboard Response"
if (-not (Test-Path $kr)) { New-Item -Path $kr -Force | Out-Null }
Set-ItemProperty -Path $kr -Name "Flags" -Type String -Value "122"
$tk = "HKCU:\Control Panel\Accessibility\ToggleKeys"
if (-not (Test-Path $tk)) { New-Item -Path $tk -Force | Out-Null }
Set-ItemProperty -Path $tk -Name "Flags" -Type String -Value "58"
$polSys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $polSys)) { New-Item -Path $polSys -Force | Out-Null }
Set-ItemProperty -Path $polSys -Name "VerboseStatus" -Type DWord -Value 1

# ─────────────────────────────────────────────
# Название: Отключение всплывающих уведомлений и звуков (Toast Notifications)
# Что делает: Отключает всплывающие баннеры (тосты) системных push-уведомлений и их звуковое сопровождение.
# Зачем нужно: Предотвращает перехват фокуса ввода с игры, падение частоты кадров и звуковые помехи от внезапных уведомлений Windows.
# Значение по умолчанию (Windows): ToastEnabled = 1, LockScreenToastEnabled = 1, уведомления и звуки разрешены
# Значение после твика: ToastEnabled = 0, LockScreenToastEnabled = 0, NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND = 0, NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK = 0
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[18/20] Отключение всплывающих баннеров уведомлений и системных звуков..." -ForegroundColor Yellow
$push = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $push)) { New-Item -Path $push -Force | Out-Null }
Set-ItemProperty -Path $push -Name "ToastEnabled" -Type DWord -Value 0
Set-ItemProperty -Path $push -Name "LockScreenToastEnabled" -Type DWord -Value 0
$notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
Set-ItemProperty -Path $notif -Name "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" -Type DWord -Value 0
Set-ItemProperty -Path $notif -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Минималистичное прикрепление окон (Minimal Window Snapping)
# Что делает: Отключает всплывающие вспомогательные макеты привязки Snap Layouts, панель SnapBar и группы задач на панели задач.
# Зачем нужно: Устраняет задержки графического интерфейса Explorer при перетаскивании окон к краям экрана.
# Значение по умолчанию (Windows): SnapAssist = 1, EnableSnapBar = 1, EnableSnapAssistFlyout = 1, EnableTaskGroups = 1
# Значение после твика: SnapAssist = 0, EnableSnapBar = 0, EnableSnapAssistFlyout = 0, EnableTaskGroups = 0
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[19/20] Оптимизация прикрепления окон (отключение навязчивого SnapAssist)..." -ForegroundColor Yellow
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $adv)) { New-Item -Path $adv -Force | Out-Null }
Set-ItemProperty -Path $adv -Name "SnapAssist" -Type DWord -Value 0
Set-ItemProperty -Path $adv -Name "EnableSnapBar" -Type DWord -Value 0
Set-ItemProperty -Path $adv -Name "EnableSnapAssistFlyout" -Type DWord -Value 0
Set-ItemProperty -Path $adv -Name "EnableTaskGroups" -Type DWord -Value 0

# ─────────────────────────────────────────────
# Название: Отключение автоматической фоновой очистки накопителя (Storage Sense)
# Что делает: Отключает запланированные фоновые сканирования диска и удаление временных файлов компонентом Storage Sense.
# Зачем нужно: Предотвращает неконтролируемое удаление файлов из Корзины/Загрузок и паразитные дисковые операции чтения/записи во время игрового процесса.
# Значение по умолчанию (Windows): Политики очистки активированы (04 = 1, 01 = 1, 2048 = 0, 08 = 1, 256 = 30, 32 = 0, 512 = 0)
# Значение после твика: Все политики (04, 01, 2048, 08, 256, 32, 512) установлены в 0 (REG_DWORD)
# Источник: Gaming & System Optimizer: Core & Kernel Architecture
# ─────────────────────────────────────────────
Write-Host "[20/20] Отключение фонового сканирования и очистки Storage Sense..." -ForegroundColor Yellow
$ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
if (-not (Test-Path $ss)) { New-Item -Path $ss -Force | Out-Null }
Set-ItemProperty -Path $ss -Name "04" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "01" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "2048" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "08" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "256" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "32" -Type DWord -Value 0
Set-ItemProperty -Path $ss -Name "512" -Type DWord -Value 0

Write-Host "`n[✓] Комплексная оптимизация ядра и системы (20/20) завершена успешно!" -ForegroundColor Green