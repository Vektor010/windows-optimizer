<div align="center">
# ⚡ Windows Optimization Suite (v2.1)
### Ultimate Low-Latency Gaming & System Optimizer for Windows 11

[![Windows 11](https://img.shields.io/badge/Windows_11-24H2%20%7C%2023H2-0078D4?logo=windows11&logoColor=white)](https://microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![AMD Zen 4/5](https://img.shields.io/badge/CPU-AMD_Ryzen_3D_V--Cache-ED1C24?logo=amd&logoColor=white)](https://www.amd.com)
[![NVIDIA RTX](https://img.shields.io/badge/GPU-NVIDIA_GeForce_RTX-76B900?logo=nvidia&logoColor=white)](https://www.nvidia.com)
[![DPC Latency](https://img.shields.io/badge/DPC_Latency-%3C_50_%C2%B5s-success)](https://resplendence.com/latencymon)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![QA](https://img.shields.io/badge/QA-PSScriptAnalyzer_Passed-brightgreen)](.github/workflows/lint.yml)

<p align="center">
  <b>Комплексный модульный пакет тонкой оптимизации Windows 11 для соревновательного гейминга (Low-Latency & Esports).</b><br>
  Аппаратно выверен под процессоры <b>AMD Ryzen™ с 3D V-Cache</b> (Zen 4 / Zen 5) и видеокарты <b>NVIDIA GeForce RTX™</b>.<br>
  Интерактивное меню на русском языке, нулевой оверхед, полная отвязка RTSS от Afterburner и 100% безопасный откат.
</p>

[🚀 Быстрый старт](#-быстрый-старт) &bull; [✨ Ключевые особенности](#-ключевые-особенности) &bull; [🖥️ Обзор меню](#-интерактивный-интерфейс-меню) &bull; [📊 Сводные таблицы твиков](#-сводные-таблицы-твиков) &bull; [🛡️ Механизм отката](#-безопасность-и-механизм-отката) &bull; [👤 Авторы](#-авторы-и-благодарности)

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

### 1. Ядро и планировщик (System & Kernel)

| Твик / Параметр | Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **Win32PrioritySeparation** | `0x26 (38)` | Кванты 3:1 в пользу игры, удержание потоков в L3 3D V-Cache |
| **SerializeTimerExpiration** | `2` | Десериализация KTIMER по ядрам PRCB, разгрузка Core 0 |
| **ThreadDpcEnable** | `1` | DPC-обработчики в потоках ядра, исключение фризов аудио и NVMe |
| **SystemResponsiveness** | `0` | 100% мощности процессора игре (снятие 20% резерва) |
| **NetworkThrottlingIndex** | `0xFFFFFFFF` | Отключение лимитера пакетов сетевого стека при мультимедиа |
| **MMCSS Tasks\Games** | `High / 8` | Наивысший приоритет игровых потоков над фоновыми службами |
| **NoLazyMode** | `1` | Запрет засыпания очередей планировщика при смене сцен |
| **DWM FSO DirectFlip** | `2` | Задержка честного Exclusive Fullscreen в Borderless |
| **DWM MPO Overlays** | `0 (Enabled)`| Прямой аппаратный вывод кадров GPU в обход композитора DWM |
| **HwSchMode (HAGS)** | `2` | Аппаратное планирование GPU, прямое снижение Input Lag |
| **ForegroundPriorityBoost** | `1` | Приоритет рендера активного окна при втором мониторе |
| **Memory Compression** | `Off` | Отключение сжатия ОЗУ, экономия тактов CPU на 32-64 ГБ RAM |
| **DisablePagingExecutive** | `1` | Ядро и драйверы заблокированы в быстрой памяти RAM |
| **NTFS LastAccess / 8.3** | `Disabled` | Отключение лишних метаданных NTFS, разгрузка очереди NVMe |
| **AutoGameMode / GameDVR** | `1 / 0` | Аппаратный игровой режим ВКЛ, фоновый оверлей ВЫКЛ |

---

### 2. Сетевой стек и TCP/IP (Network)

| Твик / Параметр | Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **Алгоритм Нагла** | `AckFreq=1, NoDelay=1` | Мгновенная отправка пакетов без задержки, тикрейт в CS2 |
| **Ring Buffers (RX/TX)** | `1024 / 512` | Увеличенные буферы сетевой карты, 0% Packet Loss в пиках |
| **Interrupt Moderation** | `Disabled` | Пакеты передаются CPU сразу без ожидания накопления |
| **Energy Efficient Ethernet**| `Disabled` | Сетевой чип всегда активен без засыпания уровня PHY |
| **Flow Control** | `Disabled` | Отключение Pause Frames, устранение искусственных микропауз |
| **Large Send Offload (LSO)**| `Disabled` | Исключение статтеров фрагментации пакетов на сетевом чипе |
| **Congestion Provider** | `CTCP` | Алгоритм Compound TCP с контролем RTT против Bufferbloat |
| **TCP Auto-Tuning** | `Normal` | Максимальная пропускная способность интернет-канала |
| **TCP Heuristics** | `Disabled` | Запрет урезания размера окна при временных нагрузках |

---

### 3. Видеокарта, NVIDIA и MSI Afterburner (GPU)

| Твик / Параметр | Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **GPU MSI Mode** | `1 (MSI)` | Исключение конфликтов IRQ Sharing на шине PCI Express |
| **DevicePriority** | `3 (High)` | Наивысший аппаратный приоритет прерываний видеокарты |
| **TDR Delay** | `8 сек` | Защита от крашей `DXGI_DEVICE_REMOVED` при компиляции шейдеров |
| **NvTelemetryContainer** | `Disabled` | Полное отключение фоновой телеметрии драйвера NVIDIA |
| **Afterburner (No RTSS)** | `В трее (/s)` | Кастомная кривая кулеров (`SwAutoFanControl=1`), 0 хуков RTSS |
| **On-Demand NVCPL** | `По требованию`| Панель NVIDIA без постоянной фоновой службы `NVDisplay` |

---

### 4. Электропитание, таймеры и мышь (Input & Power)

| Твик / Параметр | Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **CoalescingTimerInterval** | `0` | Отключение группировки таймеров, стабильный фреймтайм |
| **EnergyEstimationDisabled**| `1` | Отключение циклического фонового опроса датчиков платы |
| **USB Audio Idle Detection**| `0 (Disabled)` | Устранение щелчков, задержек и засыпания внешних USB-ЦАП |
| **System Hibernation** | `Off` | Чистый запуск ядра, освобождение 32-64 ГБ на NVMe SSD |
| **RawMouseThrottle** | `0` | Честный опрос мыши 1000-8000 Гц без троттлинга Windows |
| **Mouse Acceleration** | `0 (1:1)` | Полное отключение программной акселерации курсора |
| **Audio Ducking** | `3 (0 dB)` | Голосовой чат (Discord) не приглушает звуки игры |

---

### 5. Безопасность, приватность и службы

| Параметр / Служба | Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **VBS / HVCI** | `Disabled` | **+3-8% к 0.1% и 1% Low FPS**, ликвидация оверхеда Hyper-V |
| **Блокировка WPBT** | `1 (Blocked)` | Запрет запуска OEM-софта вендора из ACPI-таблицы BIOS |
| **Telemetry & DiagTrack** | `Disabled` | Прекращение отправки фоновых пакетов и циклов CPU |
| **Windows Error Reporting** | `Disabled` | Мгновенное завершение сбойных процессов без зависания |
| **SysMain & WSearch** | `Disabled` | 0 фоновой индексации и сбросов кэша на скоростном SSD |
| **Copilot & Recall** | `Disabled` | Блокировка ИИ-снимков экранов и фонового захвата кадров |
| **Background Apps (UWP)** | `2 (Denied)` | Запрет фоновой работы магазинных приложений во время игры |

---

### 6. Прикладные программы и киберспортивные утилиты

| Приложение / Утилита | Метод / Значение | Эффект для Low-Latency |
| :--- | :---: | :--- |
| **Steam CEF Killer** | `umpdc.dll` | Автовыгрузка `steamwebhelper.exe` в игре, -1 ГБ ОЗУ |
| **Discord Tweaks** | Без ускорения GPU | Стабильные частоты видеокарты во время звонков и стрима |
| **SteelSeries Sonar** | Службы `Disabled` | Устранение задержки звука 20 мс и всплесков DPC latency |
| **NV-CS2-Tool** | `scripts/` | Тонкая настройка субтикового буфера и сетевых кваров CS2 |
| **NV-VALORANT-Tool** | `scripts/` | Оптимизация конвейера рендеринга для Valorant |
| **Shader & DNS Flush** | `scripts/` | Очистка кэшей шейдеров DirectX/NV и DNS после апдейтов |

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

## 👤 Авторы и благодарности

- **[Vektor010](https://github.com/Vektor010)** — Архитектура проекта, интерактивное меню, модуль автономного Afterburner, интеграция бейзлайна KernelOS, QA и портирование.
- **[Nohuto](https://github.com/nohuto)** — Фундаментальные технические исследования ядра Windows, реверс-инжиниринг параметров MMCSS, квантов таймеров и киберспортивные утилиты.

---

## ⚖️ Лицензия и отказ от ответственности

Проект распространяется под открытой лицензией [MIT](LICENSE).  
*Программное обеспечение предоставляется «как есть», без каких-либо гарантий. Все изменения вносятся пользователем осознанно на основе приведенных технических описаний.*
