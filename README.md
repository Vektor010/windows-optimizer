<div align="center">

<img src="./assets/banner.gif" width="100%" alt="Cyberpunk 60FPS Header">

<br>

<img src="https://readme-typing-svg.herokuapp.com?font=Fira+Code&weight=800&size=45&duration=3000&pause=1000&color=00FFFF&center=true&vCenter=true&width=800&lines=NOVA+CORE+OPTIMIZER+v3.0;DPC+LATENCY+%3C+1+MS;AMD+RYZEN+9850X3D+READY;ZERO+INPUT+LAG" alt="Typing SVG">

# 🌌 Ультимативный Твикер для Киберспорта

[![Windows 11](https://img.shields.io/badge/Windows_11-26H2%20%7C%2025H2-0078D4?logo=windows11&logoColor=white&style=for-the-badge)](https://microsoft.com/windows)
[![CPU](https://img.shields.io/badge/CPU-AMD_Ryzen_7_9850X3D-ED1C24?logo=amd&logoColor=white&style=for-the-badge)](#)
[![GPU](https://img.shields.io/badge/GPU-RTX_5080_Ready-76B900?logo=nvidia&logoColor=white&style=for-the-badge)](#)
[![Latency](https://img.shields.io/badge/DPC_Latency-%3C_1_ms-00FF00?style=for-the-badge)](#)
[![AI Debloat](https://img.shields.io/badge/AI_Debloat-Copilot_Killed-FF0000?style=for-the-badge)](#)

<p align="center">
  <b>Агрессивная, но на 100% безопасная оптимизация Windows 11 для соревновательного гейминга.</b><br>
  Скрипт перехватывает контроль над ядром, вырезает ИИ (Copilot/Recall), убивает телеметрию и снижает задержку мыши до 1 мс.<br>
  <i>Никакого мусора, только чистая производительность. By <b>Vektor010</b>.</i>
</p>

[🚀 Скачать Релиз](#-установка-и-запуск) &bull; [✨ Технические детали](#-глубокая-техническая-информация) &bull; [🖥️ NOVA Console](#-интерфейс-nova-console) &bull; [🛡️ Откат](#-безопасность)

</div>

---

## 🚀 Установка и Запуск

1. Перейдите на вкладку **[Releases](../../releases/latest)** и скачайте архив `NOVA_Optimizer_v3.0.zip`.
2. Распакуйте архив в удобное место.
3. Нажмите **Правой Кнопкой Мыши** по файлу `NOVA.ps1` ➔ **Выполнить с помощью PowerShell**.
4. Скрипт мгновенно считает ваше железо (CPU, GPU, RAM) и откроет главное меню.

---

## ✨ Глубокая Техническая Информация

NOVA Core — это не просто сборник твиков. Это модульная архитектура, которая точечно воздействует на узкие места Windows 11:

### 🧠 1. Тотальное Удаление ИИ (AI Debloat)
Windows 11 перегружена фоновыми процессами нейросетей. NOVA полностью искореняет их из системы:
* **Windows Copilot:** Блокируется через политики (TurnOffWindowsCopilot = 1), иконка принудительно скрывается с панели задач (ShowCopilotButton = 0), а пакет `Microsoft.Windows.Ai.Copilot.Provider` удаляется.
* **Recall AI:** Полная блокировка снимков экрана и анализа данных (DisableAIDataAnalysis = 1, AllowRecallEnablement = 0).

### 🌐 2. Киберспортивный Сетевой Стек (Network & TCP/IP)
* Отключение алгоритма Нагла (Nagle's Algorithm) для мгновенной отправки пакетов в играх (CS2, Valorant).
* Оптимизация Receive Segment Coalescing (RSC) и Large Send Offload (LSO) для снижения потери пакетов.
* Снятие ограничения сети MMCSS (NetworkThrottlingIndex = 4294967295).

### ⚡ 3. Таймеры и Ядро (Kernel & DWM)
* HPET (High Precision Event Timer) переводится в оптимальный режим синхронизации с TSC процессора (useplatformclock = No).
* Desktop Window Manager (DWM) лишается тяжелых анимаций и визуального мусора.
* Отключение Dynamic Tick для предотвращения микро-фризов при простое ядер процессора.

### 🖱️ 4. Периферия (1:1 Mouse Input & Fluent Cursors)
* Полное отключение программной акселерации мыши Windows (EnhancePointerPrecision = 0).
* Автоматическая загрузка и установка киберпанк-курсора **Modern Fluent Dark** с GitHub. Применяется моментально через Win32 API (`SystemParametersInfo`), без перезагрузки ПК.

### 🧹 5. Nuclear Debloat & UWP Killer
* Уничтожение мусорных UWP-приложений. Возврат к классическому Блокноту (`notepad.exe`), Калькулятору (`calc.exe`) и Просмотру Фотографий (разблокировка `PhotoViewer.dll` в ядре).
* Глубокая очистка кэшей шейдеров DirectX, NVIDIA, AMD и журналов событий (EventLogs).

---

## 🖥️ Интерфейс NOVA CONSOLE

Наш интерфейс оптимизирован для мгновенного отклика. Оборудование кэшируется при старте за доли секунды.

<details>
<summary><b>Нажмите, чтобы развернуть структуру меню</b></summary>

```text
==============================================================================
        КОМПЛЕКСНЫЙ ПАКЕТ ОПТИМИЗАЦИИ (Gaming & System Optimizer)        
==============================================================================
 CPU: AMD Ryzen 7 9850X3D 8-Core Processor | GPU: NVIDIA GeForce RTX 5080
 RAM: 63 GB | Сеть: Ethernet
==============================================================================
 [1]   🖥️    Системные твики и ядро (System & Kernel: MMCSS, Quantum, Timer, DWM)
 [2]   🌐    Сетевые твики и TCP/IP (Network: Realtek, Nagle, Buffers, Coalescing)
 [3]   ⚡    Электропитание и таймеры (Power & Timers: Coalescing, Energy, Audio)
 [4]   🖱️    Периферия, мышь, ввод (Peripherals: RawMouseThrottle, Accel Off, Duck)
 [5]   🟩    NVIDIA и видеокарта (GPU: MSI Mode, High Priority, Telemetry, TDR)
 [6]   🎮    Клиенты, лаунчеры и приложения (Steam, Epic, Discord, Spotify...)
 [7]   🛡️    Приватность и службы (Privacy: Telemetry, DiagTrack, WSearch, SysMain)
 [8]   🔒    Безопасность и VBS (Security: VBS/HVCI Off, WPBT Block, DO P2P Off)
 [9]   📁    Проводник и интерфейс (Visibility: Classic Menu, Animations, Details)
 [10]  🧹    Очистка кэшей и шейдеров (Maintenance: Shader Caches, DNS, Temp Logs)
 [11]  🤖    Удаление ИИ (AI Debloat)
------------------------------------------------------------------------------
 [A]   🚀    ПРИМЕНИТЬ ВСЕ РЕКОМЕНДОВАННЫЕ ТВИКИ (All In One)
 [B]   💾    СОХРАНИТЬ РЕЗЕРВНЫЙ СНИМОК СИСТЕМЫ (Динамический бэкап ДО твиков)
 [D]   ↩️    ОТКАТ НАСТРОЕК (По снимку этой системы / KernelOS / Дефолт MS)
 [R]   🔄    Перезапустить проводник Windows (Explorer)
 [Q]   ❌    Выход
```
</details>

---

## 🛡️ Безопасность

**100% обратимость действий.** Перед применением любых твиков нажмите **`[B]`**, чтобы сохранить динамический снимок вашей системы (Snapshots). Если что-то пойдет не так, кнопка **`[D]`** мгновенно откатит реестр и службы к заводским или сохраненным параметрам.

<div align="center">
  <br>
  <i>Built for Speed. Built for Gamers.</i><br>
  <b>2026 © Vektor010</b>
</div>
