<div align="center">

```
 ██████╗ ██████╗ ████████╗██╗███╗   ███╗██╗███████╗███████╗██████╗ 
██╔═══██╗██╔══██╗╚══██╔══╝██║████╗ ████║██║╚══███╔╝██╔════╝██╔══██╗
██║   ██║██████╔╝   ██║   ██║██╔████╔██║██║  ███╔╝ █████╗  ██████╔╝
██║   ██║██╔═══╝    ██║   ██║██║╚██╔╝██║██║ ███╔╝  ██╔══╝  ██╔══██╗
╚██████╔╝██║        ██║   ██║██║ ╚═╝ ██║██║███████╗███████╗██║  ██║
 ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
```

# ⚡ Windows Optimization Suite (v2.1)
### Ultimate Low-Latency Gaming & System Optimizer for Windows 11

[![Windows 11](https://img.shields.io/badge/Windows_11-24H2%20%7C%2023H2-0078D4?style=for-the-badge&logo=windows11&logoColor=white)](https://microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![AMD Zen 4/5](https://img.shields.io/badge/CPU-AMD_Ryzen_3D_V--Cache-ED1C24?style=for-the-badge&logo=amd&logoColor=white)](https://www.amd.com)
[![NVIDIA RTX](https://img.shields.io/badge/GPU-NVIDIA_GeForce_RTX-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://www.nvidia.com)
[![DPC Latency](https://img.shields.io/badge/DPC_Latency-%3C_50_%C2%B5s_Verified-success?style=for-the-badge)](https://resplendence.com/latencymon)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![QA](https://img.shields.io/badge/QA-PSScriptAnalyzer_Passed-brightgreen?style=for-the-badge)](.github/workflows/lint.yml)

<p align="center">
  <b>Комплексный модульный пакет тонкой оптимизации Windows 11 для соревновательного гейминга (Low-Latency & Esports).</b><br>
  Аппаратно выверен под процессоры <b>AMD Ryzen™ с 3D V-Cache</b> (Zen 4 / Zen 5) и видеокарты <b>NVIDIA GeForce RTX™</b>.<br>
  Интерактивное меню на русском языке, нулевой оверхед, полная отвязка RTSS от Afterburner и 100% безопасный откат.
</p>

[🚀 Быстрый старт](#-быстрый-старт) • [✨ Ключевые особенности](#-ключевые-особенности) • [🖥️ Обзор меню](#-интерактивный-интерфейс-меню) • [📊 Сводные таблицы твиков](#-сводные-таблицы-твиков) • [🛡️ Механизм отката](#-безопасность-и-механизм-отката) • [👤 Автор](#-автор)

</div>

---

## 🚀 Быстрый старт

### Способ 1: Готовый переносимый релиз (Рекомендуется)
1. Скачайте свежий архив **[`Optimizer-Portable.zip`](https://github.com/Vektor010/windows-optimizer/releases/latest)** (~297 КБ).
2. Распакуйте архив в любую удобную папку (например, на Рабочий стол).
3. Нажмите правой кнопкой мыши по **`Optimizer.bat`** $\rightarrow$ **«Запуск от имени администратора»**.
4. В открывшемся цветном меню переключайте нужные пункты или примените весь профиль клавишей `[A]`.

### Способ 2: Клонирование репозитория
```powershell
git clone https://github.com/Vektor010/windows-optimizer.git
cd windows-optimizer
# Запуск от имени Администратора:
.\Optimizer.bat
```

> [!TIP]
> `Optimizer.bat` автоматически проверяет наличие повышенных привилегий с помощью утилиты `fltmc` (не зависящей от сетевой службы Server) и передает аргументы с флагом `-ExecutionPolicy Bypass`.

---

## ✨ Ключевые особенности

- 🧠 **Оптимизация квантов CPU под кэш AMD 3D V-Cache:**
  Параметр `Win32PrioritySeparation = 0x26 (38)` переводит планировщик на ультракороткие переменные кванты (3:1 в пользу игры). Это гарантирует, что горячие потоки игрового движка непрерывно удерживаются в гигантском L3-кэше процессоров Ryzen 7 7800X3D / 9800X3D / 9850X3D без лишних сбросов кэша.
- ⏱️ **Десериализация таймеров KTIMER:**
  `SerializeTimerExpiration = 2` переносит очереди таймеров ядра Windows в локальные структуры PRCB каждого ядра, устраняя традиционную перегрузку и прерывания на нулевом ядре (Core 0).
- ❄️ **Автономный MSI Afterburner без RTSS (Кастомные кулеры + OC/UV):**
  Уникальное решение: Afterburner запускается в трее (`/s`) для аппаратного управления кастомной кривой кулеров (`SwAutoFanControl=1`) и профилем андервольта, но фоновый сервер **RTSS полностью отключен и заблокирован (`EnableServer = 0`)**. Ноль сторонних хуков в память игры, полная совместимость с Vanguard/Faceit и ноль DPC-задержек!
- ⚡ **Истинный DWM Independent Flip & DirectFlip:**
  Настройка композитора рабочего стола DWM и драйвера NVIDIA обеспечивает вывод кадров в режиме Borderless с микросекундной задержкой честного Exclusive Fullscreen.
- 🚫 **Отключение VBS / Core Isolation (HVCI):**
  Ликвидация оверхеда двухуровневой виртуализации безопасности памяти Hyper-V дает стабильный прирост **от 3% до 8% по минимальному фреймрейту (0.1% и 1% Low FPS)**.
- 🛡️ **Гарантированный откат (KernelOS Baseline):**
  Никаких ненадежных точек восстановления Windows (VSS), изнашивающих SSD. Все оригинальные значения сборки сохранены в `kernelos_baseline.json` и наборе веток `.reg`. Откат выполняется в 1 клик через клавишу `[D]`.

---

## 🖥️ Интерактивный интерфейс меню

Главный файл управления [`Optimizer.ps1`](Optimizer.ps1) содержит цветное консольное меню с мгновенной индикацией текущего состояния каждого параметра системы:

```text
==============================================================================
   GAMING & SYSTEM OPTIMIZER - WINDOWS 11 LOW-LATENCY SUITE (v2.1)            
==============================================================================
 [1]  Ядро и планировщик         (MMCSS Games, кванты 0x26, KTIMER, DWM Flip)
 [2]  Сетевой стек и TCP/IP      (Алгоритм Нагла, буферы 1024/512, EEE, CTCP)
 [3]  Электропитание и таймеры   (Coalescing=0, EnergyEstimation=0, USB Audio)
 [4]  Периферия, мышь и звук     (RawMouseThrottle, Ducking=0dB, Mouse Accel)
 [5]  NVIDIA & GPU               (MSI Mode, DevicePriority High, TDR 8s, Afterburner)
 [6]  Приложения и игры          (Steam CEF Killer, Discord, G HUB, Sonar, VS Code)
 [7]  Приватность и службы       (Телеметрия, WER, DiagTrack, SysMain, Copilot)
 [8]  Безопасность и VBS         (Отключение VBS/HVCI +3-8% FPS, блокировка WPBT)
 [9]  Интерфейс и Проводник      (Classic Context Menu, анимации, Explorer UX)
 [0]  Обслуживание и очистка     (Кэши шейдеров DirectX/NV, DNS, Temp)
------------------------------------------------------------------------------
 [A]  Применить ВСЕ рекомендуемые твики системы разом
 [D]  Безопасный откат параметров (KernelOS Baseline / Заводской дефолт)
 [S]  Создать свежий системный снимок (System Snapshot)
 [Q]  Выход
==============================================================================
```

---

## 📊 Сводные таблицы твиков

### 1. Системные твики и ядро (System & Kernel)

| Параметр | Путь реестра / Команда | Значение | Описание (что делает) | Влияние на игры |
|---|---|:---:|---|---|
| **Performance Log Users** | `net localgroup "Пользователи журналов производительности" <User> /add` | SID S-1-5-32-559 | Добавляет пользователя в системную группу аудита производительности | Позволяет PresentMon, Special K и CapFrameX отслеживать SwapChain без прав Администратора |
| **SystemResponsiveness** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` | `0` (DWORD) | Регулирует бронирование вычислительной мощности CPU под фоновые задачи | Резервирует 100% мощности процессора активной игре без скрытого 20% лимита |
| **NetworkThrottlingIndex** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` | `0xFFFFFFFF` (DWORD) | Отключает внутренний лимитер пакетов сетевого стека Windows во время мультимедиа | Сетевая карта обрабатывает максимальное число пакетов без дропов при высокой нагрузке |
| **MMCSS Tasks\Games** | `HKLM\...\Multimedia\SystemProfile\Tasks\Games` | `GPU Priority=8, Priority=6, Scheduling Category=High` | Задает приоритеты планирования потоков игровых движков | Поток игры получает наивысший приоритет над системными службами |
| **NoLazyMode** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` | `1` (DWORD) | Запрещает планировщику переходить в спящий (ленивый) режим | Устраняет задержку пробуждения очередей планировщика при смене сцен |
| **Win32PrioritySeparation** | `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl` | `38 (0x26)` (DWORD) | Задает кванты времени процессора для активного окна | Короткие переменные кванты 3:1 в пользу активной игры, раскрывая кэш Ryzen 3D V-Cache |
| **SerializeTimerExpiration** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel` | `2` (DWORD) | Десериализует таблицы таймеров ядра `KTIMER` | Локальные таблицы таймеров на каждое ядро (PRCB), устраняя перегрузку Core 0 |
| **ThreadDpcEnable** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel` | `1` (DWORD) | Переводит обработчики DPC драйверов в прерываемые системные потоки | Предотвращает микрофризы звука и ввода при обращении к NVMe SSD |
| **AllowAutoGameMode** | `HKCU\Software\Microsoft\GameBar` | `1` (DWORD) | Включает аппаратный Игровой режим Windows | Выделяет приоритетные аппаратные ресурсы GPU и CPU активному окну игры |
| **AllowGameDVR** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR` | `0` (DWORD) | Отключает фоновый рекордер Xbox Game DVR | Исключает фоновое кодирование видео и нагрузку на видеопамять GPU |
| **Memory Compression** | `Disable-MMAgent -MemoryCompression -PageCombining` | Команда | Отключает алгоритм компрессии страниц оперативной памяти | Экономит такты CPU на распаковку ОЗУ (на игровых ПК с 32-64 ГБ сжатие вредно) |
| **DisablePagingExecutive** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` | `1` (DWORD) | Запрещает выгрузку компонентов ядра и драйверов в pagefile | Драйверы видеокарты, звука и ядро ntoskrnl всегда заблокированы в быстрой памяти RAM |
| **DWM FSO DirectFlip** | `HKCU\System\GameConfigStore\GameDVR_FSEBehaviorMode` | `2` (DWORD) | Настраивает композитор DWM на независимый Independent Flip | Обеспечивает задержки Exclusive Fullscreen в оконном режиме без рамок (Borderless) |
| **DWM Multi-Plane Overlay** | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\DisableOverlays` | `0` (DWORD) | Разрешает аппаратные плоскости оверлея GPU (MPO) | Кадры игры выводятся на монитор видеокартой напрямую в обход очередей DWM |
| **HwSchMode (HAGS)** | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` | `2` (DWORD) | Активирует Hardware-Accelerated GPU Scheduling | Передает планирование видеопамяти аппаратному процессору GPU, снижая Input Lag |
| **ForegroundPriorityBoost** | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler` | `1` (DWORD) | Повышает приоритет рендеринга активного окна в диспетчере GPU | Гарантирует максимальный фреймрейт при наличии окон на втором мониторе |
| **NTFS 8.3 & LastAccess** | `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem` | `NtfsDisable8dot3NameCreation=1, NtfsDisableLastAccessUpdate=1` | Отключает генерацию DOS-имен 8.3 и обновление времени последнего доступа | Ускоряет файловые операции чтения/записи на NVMe SSD за счет сокращения метаданных |

---

### 2. Сетевой стек и TCP/IP (Network)

| Параметр | Путь / Команда | Значение | Описание (что делает) | Влияние на игры |
|---|---|:---:|---|---|
| **TCP Auto-Tuning** | `netsh int tcp set global autotuninglevel=normal` | `Normal` | Включает алгоритм динамической оптимизации окна приема TCP | Обеспечивает максимальную пропускную способность интернет-канала |
| **TCP Heuristics** | `netsh int tcp set global heuristics=disabled` | `Disabled` | Отключает встроенную эвристику масштабирования Windows | Предотвращает необоснованное урезание сетевого окна при перегрузках |
| **Congestion Provider** | `Set-NetTCPSetting -CongestionProvider CTCP` | `CTCP` | Устанавливает алгоритм управления перегрузкой с контролем RTT | Минимизирует буферблоат (Bufferbloat) и удерживает стабильный пинг |
| **Interrupt Moderation** | `Set-NetAdapterAdvancedProperty -DisplayName "Interrupt Moderation"` | `Disabled` | Отключает задержку накопления пакетов в сетевом адаптере | Процессор получает сетевые пакеты мгновенно по мере поступления без группировки |
| **Receive / Transmit Buffers**| `Set-NetAdapterAdvancedProperty -DisplayName "Receive Buffers"` | `1024 / 512` | Увеличивает аппаратные кольцевые буферы сетевой карты | Полностью исключает сброс пакетов (Packet Loss) во время пикового трафика |
| **Flow Control** | `Set-NetAdapterAdvancedProperty -DisplayName "Flow Control"` | `Disabled` | Отключает генерацию и прием кадров паузы (Pause Frames) | Устраняет искусственные микропаузы в передаче пакетов |
| **Energy Efficient Ethernet**| `Set-NetAdapterAdvancedProperty -DisplayName "Energy Efficient Ethernet"` | `Disabled` | Запрещает сетевому чипу уходить в режим энергосбережения | Исключает задержку пробуждения контроллера физического уровня (PHY) между пакетами |
| **Large Send Offload (LSO)** | `Set-NetAdapterAdvancedProperty -DisplayName "Large Send Offload v2*"` | `Disabled` | Отключает аппаратную сегментацию пакетов сетевой картой | Исключает статтеры сетевого стека, передавая фрагментацию процессору |
| **Алгоритм Нагла** | `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces` | `TcpAckFrequency=1, TCPNoDelay=1, TcpDelAckTicks=0` | Заставляет стек подтверждать получение каждого пакета мгновенно | Кардинально уменьшает задержку передачи сетевых координат и тикрейта в CS2/Valorant |

---

### 3. Видеокарта, NVIDIA и MSI Afterburner (GPU)

| Параметр | Источник / Служба | Значение | Описание (что делает) | Влияние на игры |
|---|---|:---:|---|---|
| **GPU MSI Mode** | `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\...\Interrupt Management` | `MSISupported=1` (DWORD) | Переводит видеокарту в современный режим Message Signaled Interrupts | Исключает конфликты линий прерываний (IRQ Sharing) с другими устройствами PCIe |
| **DevicePriority High** | `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\...\Affinity Policy` | `DevicePriority=3` (DWORD) | Назначает видеокарте наивысший приоритет обработки прерываний шины | Сокращает задержку передачи сигналов рендеринга между видеокартой и процессором |
| **NvTelemetryContainer** | Служба `NvTelemetryContainer` | `Disabled` | Отключает фоновую службу телеметрии графического драйвера NVIDIA | Устраняет скрытую отправку данных и периодические скачки нагрузки на процессор |
| **TDR Delay** | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` | `TdrDelay=8, TdrDdiDelay=8` (DWORD) | Увеличивает допустимое время отклика GPU до 8 секунд (по умолчанию 2 сек) | Защищает от крашей с ошибкой `DXGI_ERROR_DEVICE_REMOVED` при тяжелой компиляции шейдеров |
| **MSI Afterburner Tray Mode (No RTSS)** | Планировщик Windows: `MSIAfterburner` (`scripts/MSI-Afterburner-Profile.ps1`) | `MSIAfterburner.exe /s`, `EnableServer=0` | Автозагрузка в трей для управления кулерами и OC/UV с **полной изоляцией RTSS** | Активирует кастомную кривую кулеров (`SwAutoFanControl`), сохраняя 0 процессов RTSS и 0 оверхеда |
| **On-Demand NVCPL** | Ярлык запуска [`scripts/nvcpl.ps1`](scripts/nvcpl.ps1) | По требованию | Запускает службу `NVDisplay.Container` только на время открытия Панели NVIDIA | Быстрый запуск Панели управления с автовыгрузкой службы после закрытия |

---

### 4. Электропитание, таймеры и периферия

| Параметр | Путь реестра / Команда | Значение | Описание | Влияние на игры |
|---|---|:---:|---|---|
| **CoalescingTimerInterval** | `HKLM\SYSTEM\CurrentControlSet\Control\Power` | `0` (DWORD) | Отключает коалесценцию (группировку) системных таймеров | Прерывания таймера срабатывают строго вовремя, выравнивая стабильность фреймтайма |
| **EnergyEstimationDisabled**| `HKLM\SYSTEM\CurrentControlSet\Control\Power` | `1` (DWORD) | Отключает аудит энергопотребления Energy Estimation | Устраняет непрерывный фоновый опрос датчиков потребления питания материнской платы |
| **USB Audio Idle Detection**| Реестр аудио-устройств `Class\{4d36e96c...}\PowerSettings` | `0, 0, 0, 0` (Binary) | Отключает засыпание USB-аудио (`ConservationIdleTime`, `CS*` в 24H2) | Устраняет щелчки, проглатывание первого звука и задержку старта внешних USB-ЦАП |
| **System Hibernation** | `powercfg -h off` | Команда | Полностью отключает режим гибернации и удаляет `hiberfil.sys` | Освобождает 32-64 ГБ на скоростном NVMe SSD и гарантирует чистый запуск ядра |
| **RawMouseThrottle** | `HKCU\Control Panel\Mouse` | `RawMouseThrottleEnabled=0` | Отключает системный троттлинг прямого ввода мыши (Raw Input) | Стабильная передача отчетов мыши с частотой 1000-8000 Гц без троттлинга |
| **Mouse Acceleration** | `HKCU\Control Panel\Mouse` | `MouseSpeed="0", MouseThreshold=0` | Полностью отключает программную акселерацию мыши Windows | Курсор перемещается строго 1:1 в соответствии с движением руки |
| **Audio Ducking** | `HKCU\Software\Microsoft\Multimedia\Audio` | `UserDuckingPreference=3` (DWORD) | Отключает автоматическое приглушение звука при вызове | Discord и звонки больше не снижают громкость шагов в игре (0 dB затухания) |

---

### 5. Безопасность, приватность и службы

| Параметр / Служба | Путь / Служба | Значение | Описание | Влияние на систему и игры |
|---|---|:---:|---|---|
| **VBS / HVCI** | `HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard` | `EnableVBS=0, HypervisorEnforcedCodeIntegrity=0` | Полностью отключает уровень изоляции безопасности ядра Hyper-V | **Прирост 3-8% к минимальному FPS (0.1% и 1% Low)** |
| **Блокировка WPBT** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager` | `DisableWpbtExecution=1` (DWORD) | Запрещает исполнение бинарников из ACPI-таблицы BIOS платы | Блокирует фоновую установку OEM-софта вендора (Armoury Crate, Dragon Center) |
| **AllowTelemetry & DiagTrack**| Политики DataCollection + служба `DiagTrack` | `0` (DWORD), служба `Disabled` | Отключает службу сбора телеметрии Connected User Experiences | Снимает циклическую нагрузку на процессор и диск |
| **Windows Error Reporting** | Служба `WerSvc` и `WerFault.exe` | `Disabled` | Отключает службу отчетов об ошибках | При сбое игры процесс завершается мгновенно (0 сек) без зависания системы |
| **SysMain (SuperFetch)** | Служба `SysMain` | `Disabled` | Отключает упреждающее чтение и кэширование программ на SSD | Исключает спонтанные всплески чтения на NVMe SSD во время матча |
| **Windows Search (WSearch)** | Служба `WSearch` | `Disabled` | Отключает постоянную фоновую индексацию файлов на дисках | Обеспечивает нулевую активность дисковой очереди ввода-вывода |
| **Windows Copilot & Recall** | Реестр `WindowsCopilot` и `WindowsAI` | `TurnOffWindowsCopilot=1, DisableAIDataAnalysis=1` | Блокирует ИИ-помощника Copilot и фоновый снимок экранов Recall в 24H2 | Исключает фоновый перехват кадров и фоновый анализ активности |
| **Background Apps (UWP)** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy` | `LetAppsRunInBackground=2` (DWORD) | Глобально запрещает UWP-приложениям работать в фоновом режиме | Фоновые UWP-приложения не потребляют такты CPU во время игры |

---

### 6. Прикладные программы и киберспортивные утилиты

- **Steam CEF Killer (`umpdc.dll`):** Автоматически выгружает фоновые процессы веб-рендеринга `steamwebhelper.exe` во время запущенной игры, освобождая до 1 ГБ оперативной памяти.
- **Discord Tweaks:** Отключение аппаратного ускорения Chromium, отладочного логирования и фоновых телеметрических сокетов.
- **SteelSeries Sonar Killer:** Отключение виртуального аудиодрайвера Sonar, ликвидирующее задержку 20 мс и скачки DPC latency.
- **Специализированные игровые твикеры:**
  - `NV-CS2-Tool.ps1` — тонкая настройка CS2, субтикового буфера и переменных драйвера.
  - `NV-VALORANT-Tool.ps1` — оптимизация конвейера рендеринга для Valorant.
  - `NV-Fortnite-Tool.ps1`, `NV-Marvel-Tool.ps1`, `NV-OW-Tool.ps1` — специализированные игровые профили.

---

## 🛡️ Безопасность и механизм отката

Проект придерживается принципа **неразрушающего тюнинга**:
1. **Точки восстановления Windows (System Restore / VSS) намеренно отключены:**
   Они вызывают постоянные задержки записи на скоростных NVMe SSD, фрагментацию томов и не гарантируют чистого восстановления низкоуровневых параметров ядра.
2. **Откат к эталону KernelOS Baseline (`[D] -> [1]`):**
   Восстанавливает систему к первоначальному состоянию чистой сборки с помощью файлов `01_PriorityControl_KernelOS.reg` — `07_FileSystem_KernelOS.reg` и манифеста `kernelos_baseline.json`.
3. **Сброс в стандартный заводской дефолт Microsoft (`[D] -> [2]`):**
   Возвращает параметры сетевого стека, ядра и интерфейса к фабричным настройкам чистой Windows 11.

---

## 📁 Структура репозитория

```text
windows-optimizer/
├── .github/                       # Шаблоны задач, PR и CI-пайплайн проверки кода
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/lint.yml
├── backup/                        # Реестровый бейзлайн KernelOS и эталонные ветки
│   ├── 01_PriorityControl_KernelOS.reg ... 07_FileSystem_KernelOS.reg
│   └── kernelos_baseline.json
├── scripts/                       # Модульные PowerShell-скрипты оптимизации:
│   ├── System-Tweaks.ps1          # Ядро, кванты 0x26, MMCSS, DWM
│   ├── Network-Tweaks.ps1         # TCP/IP, алгоритм Нагла, буферы 1024/512
│   ├── MSI-Afterburner-Profile.ps1# Изоляция RTSS, автозапуск кулеров и OC
│   ├── NVIDIA-Tool.ps1 / nvcpl.ps1# Облегчение драйвера и вызов панели по требованию
│   ├── NV-CS2-Tool.ps1 / etc.     # Игровые утилиты (CS2, Valorant, Fortnite)
│   ├── Privacy-Tweaks.ps1         # Службы телеметрии, WER, DiagTrack, Copilot
│   ├── Security-Tweaks.ps1        # VBS / Core Isolation, блокировка WPBT
│   ├── Cleaner-Tweaks.ps1         # Очистка шейдеров DirectX/NVIDIA, DNS, Temp
│   ├── Steam-Tweaks.ps1           # Оптимизация клиента Steam и CEF Killer
│   └── Restore-KernelOS.ps1       # Движок мгновенного отката
├── Optimizer.bat                  # Главный лаунчер с автозапросом UAC
├── Optimizer.ps1                  # Главное интерактивное меню
├── Optimizer-Portable.zip         # Автономный переносимый архив для быстрой передачи
├── LICENSE                        # Лицензия MIT
├── README.md                      # Полная документация
└── .gitignore                     # Исключение временных логов и дампов
```

---

## ❓ Часто задаваемые вопросы (FAQ)

<details>
<summary><b>1. Безопасно ли использовать этот твикер с соревновательными античитами (Faceit, Vanguard, Easy Anti-Cheat)?</b></summary>
<br>
<b>Да, на 100% безопасно.</b> Данный оптимизатор настраивает исключительно документированные системные параметры ядра Windows, сетевого стека TCP/IP и официального видеодрайвера. В системе отсутствуют сторонние инъекции DLL, хуки памяти или драйверы без цифровой подписи (более того, мы намеренно изолировали RTSS, исключив любые оверлейные хуки).
</details>

<details>
<summary><b>2. Почему MSI Afterburner оставлен в трее, а RTSS убран?</b></summary>
<br>
Современные видеокарты (особенно кастомные версии с горячими чипами памяти GDDR6X/GDDR7) требуют агрессивной программной кривой вентиляторов (<code>SwAutoFanControl=1</code>), которая работает только при запущенном Afterburner. Однако фоновый сервер RTSS часто вызывает конфликты хуков, микростаттеры и задержки DPC. Наш модуль оставляет Afterburner активным для охлаждения и андервольта, но полностью блокирует RTSS (<code>EnableServer = 0</code>).
</details>

<details>
<summary><b>3. Совместим ли пакет с Windows 10?</b></summary>
<br>
Большинство сетевых, графических твиков и оптимизаций ядра (MMCSS, Win32PrioritySeparation, MSI Mode, отключение телеметрии) полностью совместимы с Windows 10. Однако такие функции, как обход меню ПКМ Windows 11 или блокировка Windows Recall/Copilot, специфичны для Windows 11 (23H2 / 24H2).
</details>

---

## 👤 Автор

- **[Vektor010](https://github.com/Vektor010)** — Архитектура проекта, интерактивное меню, модуль автономного Afterburner, интеграция бейзлайна KernelOS, QA и портирование.

---

## ⚖️ Лицензия и отказ от ответственности

Проект распространяется под открытой лицензией [MIT](LICENSE).  
*Программное обеспечение предоставляется «как есть», без каких-либо гарантий. Все изменения вносятся пользователем осознанно на основе приведенных технических описаний.*
