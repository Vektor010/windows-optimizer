# ==============================================================================
# Gaming & System Optimizer - Обслуживание, очистка кэшей и временных файлов
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Запуск комплексной очистки кэшей шейдеров, логов и временных файлов..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# Название: Сброс локального кэша DNS-клиента (DNS Client Cache)
# Что делает: Очищает внутреннюю таблицу сопоставления доменных имен IP-адресам службы Dnscache.
# Зачем нужно: Устраняет задержки сетевого разрешения имен и ошибки устаревших маршрутов к игровым серверам.
# Значение по умолчанию (Windows): Кэш накапливается и хранится в оперативной памяти.
# Значение после твика: Кэш сброшен (Clear-DnsClientCache).
# Источник: Gaming & System Optimizer: Maintenance & Cleanup
# ─────────────────────────────────────────────
Write-Host "[1/5] Сброс локального кэша DNS (Clear-DnsClientCache)..." -ForegroundColor Yellow
Clear-DnsClientCache
Write-Host " [+] Кэш DNS-клиента успешно очищен." -ForegroundColor Green

# ─────────────────────────────────────────────
# Название: Очистка кэшей скомпилированных шейдеров DirectX и NVIDIA
# Что делает: Удаляет скомпилированные бинарные кэши шейдеров (D3DSCache, DXCache, GLCache, NV_Cache).
# Зачем нужно: Рекомендуется при установке новых видеодрайверов NVIDIA и патчей игр. Исключает статтеры из-за устаревших или поврежденных кэшей.
# Значение по умолчанию (Windows): Файлы кэша шейдеров накапливаются в папках %LOCALAPPDATA%.
# Значение после твика: Устаревшие файлы кэша удалены, драйвер компилирует чистый кэш.
# Источник: Gaming & System Optimizer: Maintenance & Cleanup
# ─────────────────────────────────────────────
Write-Host "[2/5] Очистка кэшей шейдеров DirectX и видеодрайвера NVIDIA..." -ForegroundColor Yellow
$shaderPaths = @(
    "$env:LOCALAPPDATA\D3DSCache",
    "$env:LOCALAPPDATA\NVIDIA\DXCache",
    "$env:LOCALAPPDATA\NVIDIA\GLCache",
    "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache"
)
foreach ($sp in $shaderPaths) {
    if (Test-Path $sp) {
        Remove-Item "$sp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " [+] Очищен каталог: $sp" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────
# Название: Очистка временных файлов пользователя и Windows (Temp)
# Что делает: Удаляет остаточные файлы завершенных процессов и временные инсталляторы из %TEMP% и C:\Windows\Temp.
# Зачем нужно: Освобождает пространство на скоростном NVMe SSD и снижает фрагментацию служебных структур NTFS.
# Значение по умолчанию (Windows): Временные файлы накапливаются бесконечно до ручной очистки.
# Значение после твика: Все незаблокированные временные файлы удалены.
# Источник: Gaming & System Optimizer: Maintenance & Cleanup
# ─────────────────────────────────────────────
Write-Host "[3/5] Очистка временных файлов операционной системы и пользователя..." -ForegroundColor Yellow
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host " [+] Временные файлы Temp успешно удалены." -ForegroundColor Green

# ─────────────────────────────────────────────
# Название: Очистка кэша службы оптимизации доставки (Delivery Optimization Cache)
# Что делает: Удаляет загруженные фрагменты пакетов обновлений в каталогах SoftwareDistribution и DeliveryOptimization.
# Зачем нужно: Освобождает дисковое пространство и удаляет неиспользуемые остатки установочных пакетов.
# Значение по умолчанию (Windows): Фрагменты обновлений сохраняются для P2P-раздачи.
# Значение после твика: Кэш загрузок полностью очищен.
# Источник: Gaming & System Optimizer: Maintenance & Cleanup
# ─────────────────────────────────────────────
Write-Host "[4/5] Очистка кэша файлов оптимизации доставки (Delivery Optimization)..." -ForegroundColor Yellow
$doPaths = @(
    "C:\Windows\SoftwareDistribution\DeliveryOptimization",
    "C:\Windows\SoftwareDistribution\Download"
)
foreach ($dp in $doPaths) {
    if (Test-Path $dp) {
        Remove-Item "$dp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " [+] Очищен каталог: $dp" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────
# Название: Очистка системных журналов событий Windows (Event Logs)
# Что делает: Очищает все зарегистрированные каналы журнала событий с помощью штатной утилиты wevtutil.exe.
# Зачем нужно: Удаляет накопившиеся отчеты об ошибках и снижает размер служебных файлов журналов на диске.
# Значение по умолчанию (Windows): Журналы постоянно записываются и хранятся на системном диске.
# Значение после твика: Все каналы журналов событий сброшены.
# Источник: Gaming & System Optimizer: Maintenance & Cleanup
# ─────────────────────────────────────────────
Write-Host "[5/5] Очистка системных журналов событий Windows (Event Logs)..." -ForegroundColor Yellow
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
Write-Host " [+] Все журналы событий Windows успешно очищены." -ForegroundColor Green

Write-Host "`n[✓] Комплексная очистка системы и кэшей шейдеров завершена успешно!" -ForegroundColor Green